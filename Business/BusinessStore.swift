import Foundation
import Combine

/// Holds all business-side data and the actions staff can take.
/// For the hackathon it runs on local sample data (`BusinessStore.demo()`).
/// Later this can be backed by the same database the student side uses.
final class BusinessStore: ObservableObject {
    @Published var businessName: String
    /// Shows the "Demo business view" label on the dashboard.
    @Published var isDemo: Bool
    @Published private(set) var listings: [Listing]
    @Published private(set) var reservations: [Reservation]
    @Published private(set) var waitlist: [WaitlistEntry]
    @Published private(set) var rescues: [Rescue]
    /// Reservations whose pickup window ended without a verified pickup.
    @Published private(set) var missedPickups: Int
    /// Short message shown after an action, e.g. "Pickup verified".
    @Published var lastEvent: String?

    init(
        businessName: String,
        isDemo: Bool = false,
        listings: [Listing] = [],
        reservations: [Reservation] = [],
        waitlist: [WaitlistEntry] = [],
        rescues: [Rescue] = [],
        missedPickups: Int = 0
    ) {
        self.businessName = businessName
        self.isDemo = isDemo
        self.listings = listings
        self.reservations = reservations
        self.waitlist = waitlist
        self.rescues = rescues
        self.missedPickups = missedPickups
    }

    // MARK: - Lookups

    func listing(id: UUID) -> Listing? {
        listings.first { $0.id == id }
    }

    func reservation(id: UUID) -> Reservation? {
        reservations.first { $0.id == id }
    }

    func waitlistCount(for listingID: UUID) -> Int {
        waitlist.filter { $0.listingID == listingID }.reduce(0) { $0 + $1.quantity }
    }

    /// Open listings first, then by pickup deadline.
    var sortedListings: [Listing] {
        listings.sorted { a, b in
            let aOpen = a.status != .closed
            let bOpen = b.status != .closed
            if aOpen != bOpen { return aOpen }
            return a.pickupDeadline < b.pickupDeadline
        }
    }

    var upcomingReservations: [Reservation] {
        reservations.sorted { $0.pickupDeadline < $1.pickupDeadline }
    }

    var todaysRescues: [Rescue] {
        rescues
            .filter { Calendar.current.isDateInToday($0.pickedUpAt) }
            .sorted { $0.pickedUpAt > $1.pickedUpAt }
    }

    var impact: ImpactSummary {
        let measured = rescues.filter { $0.weightIsMeasured }.reduce(0.0) { $0 + $1.weightKg }
        let estimated = rescues.filter { !$0.weightIsMeasured }.reduce(0.0) { $0 + $1.weightKg }
        let attempts = rescues.count + missedPickups
        let rate: Double? = attempts == 0 ? nil : Double(rescues.count) / Double(attempts)
        return ImpactSummary(
            portionsRescued: rescues.reduce(0) { $0 + $1.quantity },
            measuredWeightKg: measured,
            estimatedWeightKg: estimated,
            revenueRecovered: rescues.reduce(0.0) { $0 + $1.amountCaptured },
            studentSavings: rescues.reduce(0.0) { $0 + $1.studentSavings },
            pickupCompletionRate: rate
        )
    }

    // MARK: - Listings

    /// Publishes a staff-reviewed draft. Does nothing if the draft is not ready.
    func publish(_ draft: ListingDraft) {
        guard draft.isReady else { return }
        let listing = Listing(
            name: draft.trimmedName,
            details: draft.details,
            allergens: draft.allergens,
            quantityRemaining: draft.quantity,
            price: draft.price,
            originalPrice: draft.originalPrice,
            pickupDeadline: draft.pickupDeadline,
            weightPerPortionKg: draft.weightPerPortionKg,
            weightIsMeasured: draft.weightIsMeasured
        )
        listings.insert(listing, at: 0)
        lastEvent = "\(listing.name) is live for students."
    }

    /// Applies a staff-approved edit to a live listing.
    func update(listingID: UUID, with draft: ListingDraft) {
        guard draft.isReady, let index = listings.firstIndex(where: { $0.id == listingID }) else { return }
        listings[index].name = draft.trimmedName
        listings[index].details = draft.details
        listings[index].allergens = draft.allergens
        listings[index].quantityRemaining = draft.quantity
        listings[index].price = draft.price
        listings[index].originalPrice = draft.originalPrice
        listings[index].pickupDeadline = draft.pickupDeadline
        listings[index].weightPerPortionKg = draft.weightPerPortionKg
        listings[index].weightIsMeasured = draft.weightIsMeasured

        // Existing reservations keep their price, but follow the new name and pickup time.
        for i in reservations.indices where reservations[i].listingID == listingID {
            reservations[i].itemName = draft.trimmedName
            reservations[i].pickupDeadline = draft.pickupDeadline
        }

        let offered = fillFromWaitlist(listingID: listingID)
        lastEvent = offered.isEmpty
            ? "\(draft.trimmedName) updated."
            : "\(draft.trimmedName) updated. Offered to \(offered.joined(separator: ", ")) from the waitlist."
    }

    func setPaused(_ paused: Bool, listingID: UUID) {
        guard let index = listings.firstIndex(where: { $0.id == listingID }) else { return }
        listings[index].isPaused = paused
        if paused {
            lastEvent = "\(listings[index].name) is paused. Students can't reserve it."
        } else {
            let offered = fillFromWaitlist(listingID: listingID)
            lastEvent = offered.isEmpty
                ? "\(listings[index].name) is available again."
                : "\(listings[index].name) is available again. Offered to \(offered.joined(separator: ", ")) from the waitlist."
        }
    }

    /// Stops new reservations. Existing reservations stay so staff can still verify them.
    func close(listingID: UUID) {
        guard let index = listings.firstIndex(where: { $0.id == listingID }) else { return }
        listings[index].isClosed = true
        lastEvent = "\(listings[index].name) is closed."
    }

    // MARK: - Reservations

    /// Staff checked the student's QR pickup pass. Captures payment and records the rescue.
    func verifyPickup(reservationID: UUID) {
        guard let index = reservations.firstIndex(where: { $0.id == reservationID }) else { return }
        let reservation = reservations.remove(at: index)
        let matchedListing = self.listing(id: reservation.listingID)
        let savingsPerPortion = max(0, reservation.originalUnitPrice - reservation.unitPrice)

        let rescue = Rescue(
            reservationCode: reservation.code,
            studentName: reservation.studentName,
            itemName: reservation.itemName,
            quantity: reservation.quantity,
            pickedUpAt: Date(),
            amountCaptured: reservation.total,
            studentSavings: savingsPerPortion * Double(reservation.quantity),
            weightKg: (matchedListing?.weightPerPortionKg ?? 0) * Double(reservation.quantity),
            weightIsMeasured: matchedListing?.weightIsMeasured ?? false
        )
        rescues.insert(rescue, at: 0)
        lastEvent = "Pickup verified for \(reservation.studentName). Payment captured."
    }

    /// Student cancelled: release the payment hold and offer the portions to the waitlist.
    /// On the business side this is only triggered from the demo menu.
    func cancelReservation(reservationID: UUID) {
        guard let index = reservations.firstIndex(where: { $0.id == reservationID }) else { return }
        let reservation = reservations.remove(at: index)

        if let listingIndex = listings.firstIndex(where: { $0.id == reservation.listingID }) {
            listings[listingIndex].quantityRemaining += reservation.quantity
        }
        let offered = fillFromWaitlist(listingID: reservation.listingID)

        var message = "\(reservation.studentName) cancelled. Payment released."
        if !offered.isEmpty {
            message += " Offered to \(offered.joined(separator: ", ")) from the waitlist."
        }
        lastEvent = message
    }

    /// Gives free portions to waitlisted students, in order. Returns their names.
    @discardableResult
    private func fillFromWaitlist(listingID: UUID) -> [String] {
        guard let listingIndex = listings.firstIndex(where: { $0.id == listingID }) else { return [] }
        var offered: [String] = []

        while listings[listingIndex].status == .available,
              let entryIndex = waitlist.firstIndex(where: {
                  $0.listingID == listingID && $0.quantity <= listings[listingIndex].quantityRemaining
              }) {
            let entry = waitlist.remove(at: entryIndex)
            let current = listings[listingIndex]
            listings[listingIndex].quantityRemaining -= entry.quantity
            reservations.append(
                Reservation(
                    studentName: entry.studentName,
                    listingID: listingID,
                    itemName: current.name,
                    quantity: entry.quantity,
                    unitPrice: current.price,
                    originalUnitPrice: current.originalPrice,
                    pickupDeadline: current.pickupDeadline,
                    fromWaitlist: true
                )
            )
            offered.append(entry.studentName)
        }
        return offered
    }
}

// MARK: - Sample data

extension BusinessStore {
    /// A believable evening at a campus café, for the hackathon demo.
    static func demo(now: Date = Date(), calendar: Calendar = .current) -> BusinessStore {
        func today(_ hour: Int, _ minute: Int) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
        }

        let sandwiches = Listing(
            name: "Turkey & Swiss sandwiches",
            details: "Made this morning, kept refrigerated.",
            allergens: "Wheat, milk",
            quantityRemaining: 4,
            price: 4.00,
            originalPrice: 9.49,
            pickupDeadline: today(20, 0),
            weightPerPortionKg: 0.25,
            weightIsMeasured: false
        )
        let bagels = Listing(
            name: "Everything bagels",
            details: "Plain cream cheese on the side.",
            allergens: "Wheat, sesame, milk",
            quantityRemaining: 0,
            price: 1.50,
            originalPrice: 3.25,
            pickupDeadline: today(19, 30),
            weightPerPortionKg: 0.11,
            weightIsMeasured: true
        )
        let bowls = Listing(
            name: "Chicken teriyaki bowls",
            details: "Rice, chicken, steamed broccoli.",
            allergens: "Soy, wheat",
            quantityRemaining: 6,
            price: 5.00,
            originalPrice: 11.99,
            pickupDeadline: today(20, 30),
            weightPerPortionKg: 0.45,
            weightIsMeasured: false
        )
        let fruit = Listing(
            name: "Fruit cups",
            details: "Melon, grapes, pineapple.",
            allergens: "None declared by staff",
            quantityRemaining: 3,
            price: 2.00,
            originalPrice: 4.50,
            pickupDeadline: today(20, 0),
            weightPerPortionKg: 0.2,
            weightIsMeasured: true,
            isPaused: true
        )

        let reservations = [
            Reservation(code: "KS-4821", studentName: "Jordan P.", listingID: bagels.id, itemName: bagels.name,
                        quantity: 2, unitPrice: bagels.price, originalUnitPrice: bagels.originalPrice,
                        pickupDeadline: bagels.pickupDeadline),
            Reservation(code: "KS-3307", studentName: "Leo M.", listingID: bagels.id, itemName: bagels.name,
                        quantity: 1, unitPrice: bagels.price, originalUnitPrice: bagels.originalPrice,
                        pickupDeadline: bagels.pickupDeadline),
            Reservation(code: "KS-5190", studentName: "Aisha K.", listingID: sandwiches.id, itemName: sandwiches.name,
                        quantity: 1, unitPrice: sandwiches.price, originalUnitPrice: sandwiches.originalPrice,
                        pickupDeadline: sandwiches.pickupDeadline),
            Reservation(code: "KS-7742", studentName: "Chris T.", listingID: bowls.id, itemName: bowls.name,
                        quantity: 2, unitPrice: bowls.price, originalUnitPrice: bowls.originalPrice,
                        pickupDeadline: bowls.pickupDeadline),
        ]

        let waitlist = [
            WaitlistEntry(studentName: "Maya R.", listingID: bagels.id, quantity: 1),
        ]

        let rescues = [
            Rescue(reservationCode: "KS-2018", studentName: "Sam W.", itemName: sandwiches.name, quantity: 2,
                   pickedUpAt: today(17, 40), amountCaptured: 8.00, studentSavings: 10.98,
                   weightKg: 0.5, weightIsMeasured: false),
            Rescue(reservationCode: "KS-6634", studentName: "Priya N.", itemName: bowls.name, quantity: 1,
                   pickedUpAt: today(18, 5), amountCaptured: 5.00, studentSavings: 6.99,
                   weightKg: 0.45, weightIsMeasured: false),
            Rescue(reservationCode: "KS-9051", studentName: "Diego A.", itemName: bagels.name, quantity: 3,
                   pickedUpAt: today(18, 20), amountCaptured: 4.50, studentSavings: 5.25,
                   weightKg: 0.33, weightIsMeasured: true),
        ]

        return BusinessStore(
            businessName: "Knight Bites Café",
            isDemo: true,
            listings: [sandwiches, bagels, bowls, fruit],
            reservations: reservations,
            waitlist: waitlist,
            rescues: rescues,
            missedPickups: 0
        )
    }
}
