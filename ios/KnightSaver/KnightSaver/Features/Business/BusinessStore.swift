import Foundation
import Combine

/// Result of scanning a student's Knight Pass.
enum PassScanResult: Hashable {
    /// No valid reservation for this business and pickup window.
    case noValidPickup
    /// Exactly one reservation matches. Staff confirm it.
    case single(BusinessReservation)
    /// Several reservations match. Staff pick the exact one.
    case multiple([BusinessReservation])
    /// This pickup was already verified. Nothing is captured twice.
    case alreadyVerified(BusinessReservation)
}

enum VerifyOutcome: Hashable {
    case verified(BusinessReservation)
    case alreadyVerified(BusinessReservation)
    case notAllowed(String)
}

/// All Business tab data and staff actions. Runs on local demo data for the hackathon.
/// A backend can replace the arrays later; the views only use the methods below.
final class BusinessStore: ObservableObject {
    @Published var profile: BusinessProfile
    @Published var isDemo: Bool
    @Published private(set) var listings: [BusinessListing]
    @Published private(set) var reservations: [BusinessReservation]
    @Published private(set) var feedback: [PickupFeedback]
    @Published private(set) var events: [BusinessEvent] = []
    /// Short message shown after an action.
    @Published var toast: String?

    init(
        profile: BusinessProfile,
        isDemo: Bool = false,
        listings: [BusinessListing] = [],
        reservations: [BusinessReservation] = [],
        feedback: [PickupFeedback] = []
    ) {
        self.profile = profile
        self.isDemo = isDemo
        self.listings = listings
        self.reservations = reservations
        self.feedback = feedback
    }

    // MARK: - Reading

    func listing(id: UUID) -> BusinessListing? {
        listings.first { $0.id == id }
    }

    func reservation(id: UUID) -> BusinessReservation? {
        reservations.first { $0.id == id }
    }

    /// Active and recently changed listings, soonest pickup first. Cancelled/closed go last.
    var currentListings: [BusinessListing] {
        listings.sorted { a, b in
            let aOpen = a.state == .live || a.state == .paused
            let bOpen = b.state == .live || b.state == .paused
            if aOpen != bOpen { return aOpen }
            return a.pickupStart < b.pickupStart
        }
    }

    var upcomingPickups: [BusinessReservation] {
        reservations
            .filter { $0.isUpcoming }
            .sorted { a, b in
                if a.pickupStart != b.pickupStart { return a.pickupStart < b.pickupStart }
                return rank(a) < rank(b)
            }
    }

    var todaysVerifiedRescues: [BusinessReservation] {
        reservations
            .filter { $0.isVerified && $0.verifiedAt.map { Calendar.current.isDateInToday($0) } == true }
            .sorted { ($0.verifiedAt ?? .distantPast) > ($1.verifiedAt ?? .distantPast) }
    }

    var todaysVerifiedTotal: Double {
        todaysVerifiedRescues.reduce(0.0) { $0 + $1.total }
    }

    func waitlistCount(for listingID: UUID) -> Int {
        reservations.filter { $0.listingID == listingID && $0.status == .waitlisted }.count
    }

    var impact: BusinessImpact {
        let verified = reservations.filter { $0.isVerified }
        var measured = 0.0
        var estimated = 0.0
        for reservation in verified {
            if let weight = reservation.measuredWeightKg {
                measured += weight
            } else {
                let perBag = listing(id: reservation.listingID)?.estimatedKgPerBag ?? 0
                estimated += perBag * Double(reservation.quantity)
            }
        }
        let missed = reservations.filter { $0.status == .missed }.count
        let due = verified.count + missed
        let ratings = feedback.map { Double($0.overall) }
        return BusinessImpact(
            bagsCollected: verified.reduce(0) { $0 + $1.quantity },
            measuredWeightKg: measured,
            estimatedWeightKg: estimated,
            estimatedCO2eKg: (measured + estimated) * BusinessRules.estimatedCO2eKgPerFoodKg,
            revenueRecovered: verified.reduce(0.0) { $0 + $1.total },
            pickupCompletionRate: due == 0 ? nil : Double(verified.count) / Double(due),
            averageRating: ratings.isEmpty ? nil : ratings.reduce(0, +) / Double(ratings.count),
            ratingCount: ratings.count
        )
    }

    // MARK: - Student side (Explore, bag details, Profile, KnightMap)

    /// Live bags in the student-side format. Paused, closed and cancelled listings are left out.
    /// Each bag's `id` is the listing id, so the same bag keeps its identity across updates.
    var surpriseBagsForExplore: [SurpriseBag] {
        listings
            .filter { $0.status == .available || $0.status == .fullyReserved }
            .sorted { $0.pickupStart < $1.pickupStart }
            .map { studentBag(for: $0) }
    }

    /// The current student-facing version of a live bag, or nil if it's no longer listed.
    func liveBag(id: UUID) -> SurpriseBag? {
        guard let listing = self.listing(id: id),
              listing.status == .available || listing.status == .fullyReserved else { return nil }
        return studentBag(for: listing)
    }

    /// True when the bag came from this store (not one of the sample restaurants).
    func isLiveBag(_ bag: SurpriseBag) -> Bool {
        listing(id: bag.id) != nil
    }

    /// Map pins for KnightMap. KnightMap must read these from the shared store.
    var mapPins: [KnightMapPin] {
        listings
            .filter { $0.status == .available || $0.status == .fullyReserved }
            .map { KnightMapPin(bag: studentBag(for: $0), latitude: $0.latitude, longitude: $0.longitude) }
    }

    func studentBag(for listing: BusinessListing) -> SurpriseBag {
        SurpriseBag(
            id: listing.id,
            business: profile.name,
            location: listing.pickupAddress,
            brand: profile.brand,
            rating: profile.rating,
            feedbackCount: profile.feedbackCount,
            distance: 0.4,
            pickupWindow: listing.pickupWindowText,
            availableCount: listing.isReservable ? listing.remainingQuantity : 0,
            price: listing.price,
            description: listing.publicDescription
        )
    }

    /// A student reserves (or joins the waitlist when the bag is fully reserved).
    /// Lowers the remaining count and shows up in Business › Reserved pickups.
    @discardableResult
    func reserve(bagID: UUID, studentName: String, passToken: String, quantity: Int = 1) -> BusinessReservation? {
        guard let index = listings.firstIndex(where: { $0.id == bagID }),
              listings[index].state == .live, quantity > 0 else { return nil }
        let listing = listings[index]
        let reservation: BusinessReservation
        if listing.remainingQuantity >= quantity {
            listings[index].remainingQuantity -= quantity
            listings[index].updatedAt = Date()
            reservation = BusinessReservation(
                studentDisplayName: studentName, passToken: passToken, listingID: listing.id,
                quantity: quantity, unitPrice: listing.price,
                pickupStart: listing.pickupStart, pickupEnd: listing.pickupEnd,
                status: .authorized, payment: .authorized
            )
            toast = "\(studentName) reserved \(quantity) Surprise Bag\(quantity == 1 ? "" : "s")."
        } else {
            reservation = BusinessReservation(
                studentDisplayName: studentName, passToken: passToken, listingID: listing.id,
                quantity: quantity, unitPrice: listing.price,
                pickupStart: listing.pickupStart, pickupEnd: listing.pickupEnd,
                status: .waitlisted, payment: .notStarted,
                waitlistPosition: waitlistCount(for: listing.id) + 1
            )
            toast = "\(studentName) joined the waitlist."
        }
        reservations.append(reservation)
        log(.reservationCreated, reservation.code)
        return reservation
    }

    /// The signed-in student's reservations, in the student-side format.
    /// Upcoming ones first, then pickups verified today.
    func studentReservations(passToken: String) -> [ActiveReservation] {
        reservations
            .filter { reservation in
                reservation.passToken == passToken
                    && (reservation.isUpcoming
                        || (reservation.isVerified && reservation.verifiedAt.map { Calendar.current.isDateInToday($0) } == true))
            }
            .sorted { a, b in
                if a.isUpcoming != b.isUpcoming { return a.isUpcoming }
                return a.pickupStart < b.pickupStart
            }
            .compactMap { reservation in
                guard let listing = self.listing(id: reservation.listingID) else { return nil }
                return ActiveReservation(
                    id: reservation.id,
                    bag: studentBag(for: listing),
                    status: studentStatus(for: reservation),
                    paymentStatus: reservation.payment.rawValue,
                    attentionMessage: attentionMessage(for: reservation)
                )
            }
    }

    func isStoreReservation(id: UUID) -> Bool {
        reservation(id: id) != nil
    }

    private func studentStatus(for reservation: BusinessReservation) -> ReservationStatus {
        switch reservation.status {
        case .offerSent: return .waitlistOffer
        case .waitlisted: return .waitlisted
        case .pickupVerified, .paymentCaptured: return .verified
        default: return .confirmed
        }
    }

    private func attentionMessage(for reservation: BusinessReservation) -> String? {
        switch reservation.status {
        case .authorized: return "Pickup \(reservation.pickupWindowText)"
        case .offerSent: return "A bag opened up for you"
        case .waitlisted: return "Waitlist position \(reservation.waitlistPosition ?? 1)"
        case .pickupVerified, .paymentCaptured: return "Picked up — thanks for rescuing food"
        default: return nil
        }
    }

    // MARK: - Publishing

    func confirmInventory(_ items: [SurplusItem]) {
        log(.surplusInventoryConfirmed, items.summaryText)
    }

    /// Publishes a staff-approved plan.
    @discardableResult
    func publish(_ plan: BagPlan) -> BusinessListing? {
        guard plan.isReady else { return nil }
        let allocation = plan.allocation
        let allocatedItems = allocation.bags.flatMap { $0 }
        var inventory: [SurplusItem] = []
        for item in allocatedItems {
            if let index = inventory.firstIndex(where: { $0.name == item.name }) {
                inventory[index].quantity += item.quantity
            } else {
                inventory.append(SurplusItem(name: item.name, quantity: item.quantity))
            }
        }
        let listing = BusinessListing(
            price: plan.price,
            totalQuantity: plan.bagCount,
            remainingQuantity: plan.bagCount,
            pickupStart: plan.pickupStart,
            pickupEnd: plan.pickupEnd,
            publicDescription: plan.publicDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            pickupAddress: profile.pickupAddress,
            latitude: profile.latitude,
            longitude: profile.longitude,
            inventory: inventory,
            bagSplit: allocation.bags,
            unallocated: allocation.leftover
        )
        listings.append(listing)
        if plan.createdByAI {
            log(.aiBagPlanApproved, "\(plan.bagCount) bags at \(PickupTime.money(plan.price))")
        }
        log(.listingPublished, "\(plan.bagCount) Surprise Bags, \(listing.pickupWindowText)")
        toast = "\(plan.bagCount) Surprise Bags are live in Explore and KnightMap."
        return listing
    }

    // MARK: - Editing

    func applyEdit(listingID: UUID, remaining: Int?, price: Double?, pickupStart: Date?, pickupEnd: Date?, description: String? = nil) {
        guard let index = listings.firstIndex(where: { $0.id == listingID }) else { return }
        var listing = listings[index]

        if let remaining = remaining {
            let delta = max(0, remaining) - listing.remainingQuantity
            listing.remainingQuantity = max(0, remaining)
            listing.totalQuantity = max(0, listing.totalQuantity + delta)
            if delta != 0 {
                listing.reallocateBags()
            }
        }
        if let price = price { listing.price = max(0, price) }
        if let start = pickupStart, let end = pickupEnd, start < end {
            listing.pickupStart = start
            listing.pickupEnd = end
            for i in reservations.indices where reservations[i].listingID == listingID && reservations[i].isUpcoming {
                reservations[i].pickupStart = start
                reservations[i].pickupEnd = end
            }
        }
        if let description = description {
            let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
            listing.publicDescription = trimmed.isEmpty ? BusinessRules.defaultPublicDescription : trimmed
        }
        listing.updatedAt = Date()
        listings[index] = listing

        let offered = offerToWaitlist(listingID: listingID)
        log(.listingUpdated, "\(listing.label), \(listing.pickupWindowText), \(listing.remainingQuantity) left")
        toast = offered.isEmpty
            ? "Listing updated in Explore and KnightMap."
            : "Listing updated. Offer sent to \(offered.joined(separator: ", "))."
    }

    func apply(_ action: ListingStateAction, listingID: UUID) {
        switch action {
        case .pause: setPaused(true, listingID: listingID)
        case .resume: setPaused(false, listingID: listingID)
        case .close: close(listingID: listingID)
        case .cancel: cancelListing(listingID: listingID)
        }
    }

    func setPaused(_ paused: Bool, listingID: UUID) {
        guard let index = listings.firstIndex(where: { $0.id == listingID }),
              listings[index].state == .live || listings[index].state == .paused else { return }
        listings[index].state = paused ? .paused : .live
        listings[index].updatedAt = Date()
        log(.listingUpdated, paused ? "Paused" : "Resumed")
        if paused {
            toast = "Paused. Students can't reserve it right now."
        } else {
            let offered = offerToWaitlist(listingID: listingID)
            toast = offered.isEmpty ? "Resumed. Students can reserve again." : "Resumed. Offer sent to \(offered.joined(separator: ", "))."
        }
    }

    /// Stops new reservations. Existing pickups can still be verified.
    func close(listingID: UUID) {
        guard let index = listings.firstIndex(where: { $0.id == listingID }) else { return }
        listings[index].state = .closed
        listings[index].updatedAt = Date()
        for i in reservations.indices where reservations[i].listingID == listingID
            && (reservations[i].status == .waitlisted || reservations[i].status == .offerSent) {
            reservations[i].status = .cancelled
            reservations[i].payment = .released
        }
        log(.listingUpdated, "Closed")
        toast = "Closed. Existing pickups can still be verified."
    }

    /// Cancels the listing and releases every payment authorization.
    func cancelListing(listingID: UUID) {
        guard let index = listings.firstIndex(where: { $0.id == listingID }) else { return }
        listings[index].state = .cancelled
        listings[index].updatedAt = Date()
        var released = 0
        for i in reservations.indices where reservations[i].listingID == listingID && reservations[i].isUpcoming {
            if reservations[i].payment == .authorized { released += 1 }
            reservations[i].status = .cancelled
            reservations[i].payment = .released
            log(.reservationCancelled, reservations[i].code)
        }
        log(.listingUpdated, "Cancelled")
        toast = released == 0 ? "Listing cancelled." : "Listing cancelled. \(released) payment holds released."
    }

    // MARK: - Reservations (student actions are simulated in the demo)

    /// Student cancelled: release the hold, then free the bag or offer it to the waitlist.
    /// No impact or leaderboard credit is created.
    func cancelReservation(id: UUID) {
        guard let index = reservations.firstIndex(where: { $0.id == id }), reservations[index].isUpcoming else { return }
        let reservation = reservations[index]
        reservations[index].status = .cancelled
        if reservation.payment == .authorized {
            reservations[index].payment = .released
        }
        if reservation.status != .waitlisted,
           let listingIndex = listings.firstIndex(where: { $0.id == reservation.listingID }) {
            listings[listingIndex].remainingQuantity += reservation.quantity
            listings[listingIndex].updatedAt = Date()
        }
        renumberWaitlist(listingID: reservation.listingID)
        log(.reservationCancelled, reservation.code)

        let offered = reservation.status == .waitlisted ? [] : offerToWaitlist(listingID: reservation.listingID)
        var message = "\(reservation.studentDisplayName) cancelled."
        if reservation.payment == .authorized { message += " Payment hold released." }
        message += offered.isEmpty ? " Bag is available again." : " Offer sent to \(offered.joined(separator: ", "))."
        toast = message
    }

    /// Student accepted a waitlist offer and authorized payment.
    func acceptOffer(id: UUID) {
        guard let index = reservations.firstIndex(where: { $0.id == id }), reservations[index].status == .offerSent else { return }
        reservations[index].status = .authorized
        reservations[index].payment = .authorized
        log(.reservationCreated, reservations[index].code)
        toast = "\(reservations[index].studentDisplayName) accepted and authorized payment."
    }

    /// The pickup window passed without a verified pickup.
    func markMissed(id: UUID) {
        guard let index = reservations.firstIndex(where: { $0.id == id }), reservations[index].status == .authorized else { return }
        reservations[index].status = .missed
        reservations[index].payment = .released
        toast = "Marked as missed. No impact credit."
    }

    /// Holds freed bags for waitlisted students, in order. Returns their names.
    @discardableResult
    private func offerToWaitlist(listingID: UUID) -> [String] {
        guard let listingIndex = listings.firstIndex(where: { $0.id == listingID }) else { return [] }
        var offered: [String] = []
        while listings[listingIndex].isReservable,
              let next = reservations.indices
                .filter({ reservations[$0].listingID == listingID && reservations[$0].status == .waitlisted })
                .min(by: { (reservations[$0].waitlistPosition ?? .max) < (reservations[$1].waitlistPosition ?? .max) }),
              reservations[next].quantity <= listings[listingIndex].remainingQuantity {
            listings[listingIndex].remainingQuantity -= reservations[next].quantity
            reservations[next].status = .offerSent
            reservations[next].waitlistPosition = nil
            offered.append(reservations[next].studentDisplayName)
            log(.waitlistOfferCreated, reservations[next].code)
        }
        renumberWaitlist(listingID: listingID)
        return offered
    }

    private func renumberWaitlist(listingID: UUID) {
        let waiting = reservations.indices
            .filter { reservations[$0].listingID == listingID && reservations[$0].status == .waitlisted }
            .sorted { (reservations[$0].waitlistPosition ?? .max) < (reservations[$1].waitlistPosition ?? .max) }
        for (position, index) in waiting.enumerated() {
            reservations[index].waitlistPosition = position + 1
        }
    }

    // MARK: - Knight Pass verification

    /// Reads the token from a scanned Knight Pass QR ("knightsaver://verify-user/<token>").
    static func passToken(fromScannedValue value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = trimmed.range(of: "verify-user/") {
            return String(trimmed[range.upperBound...])
        }
        return trimmed
    }

    /// Finds reservations this business can verify right now for the scanned pass.
    func scan(_ scannedValue: String, now: Date = Date()) -> PassScanResult {
        let token = Self.passToken(fromScannedValue: scannedValue)
        guard !token.isEmpty else { return .noValidPickup }

        let forPass = reservations.filter { $0.passToken == token }
        let valid = forPass.filter { reservation in
            reservation.status == .authorized
                && reservation.payment == .authorized
                && listing(id: reservation.listingID) != nil
                && now >= reservation.pickupStart.addingTimeInterval(-BusinessRules.pickupGrace)
                && now <= reservation.pickupEnd.addingTimeInterval(BusinessRules.pickupGrace)
        }

        if valid.count == 1, let only = valid.first { return .single(only) }
        if valid.count > 1 { return .multiple(valid.sorted { $0.pickupStart < $1.pickupStart }) }

        // Same pass scanned again after verification: show it, never capture twice.
        if let done = forPass
            .filter({ $0.isVerified && $0.verifiedAt.map { now.timeIntervalSince($0) < 3 * 3600 } == true })
            .max(by: { ($0.verifiedAt ?? .distantPast) < ($1.verifiedAt ?? .distantPast) }) {
            return .alreadyVerified(done)
        }
        return .noValidPickup
    }

    /// Verifies one pickup and captures payment. Safe to call twice: the second call changes nothing.
    @discardableResult
    func verifyPickup(id: UUID, measuredWeightKg: Double? = nil, now: Date = Date()) -> VerifyOutcome {
        guard let index = reservations.firstIndex(where: { $0.id == id }) else {
            return .notAllowed("Reservation not found.")
        }
        let reservation = reservations[index]
        if reservation.isVerified { return .alreadyVerified(reservation) }
        guard reservation.status == .authorized, reservation.payment == .authorized else {
            return .notAllowed("This reservation can't be verified (\(reservation.status.rawValue)).")
        }

        reservations[index].status = .pickupVerified
        reservations[index].verifiedAt = now
        if let weight = measuredWeightKg, weight > 0 {
            reservations[index].measuredWeightKg = weight
        }
        log(.pickupVerified, reservation.code)

        reservations[index].payment = .captured
        reservations[index].status = .paymentCaptured
        log(.paymentCaptured, "\(reservation.code) \(PickupTime.money(reservation.total))")
        log(.impactRecorded, "\(reservation.quantity) bag(s)")
        log(.leaderboardCredited, reservation.studentDisplayName)

        toast = "Pickup verified for \(reservation.studentDisplayName). Payment captured."
        return .verified(reservations[index])
    }

    // MARK: - Private

    private func rank(_ reservation: BusinessReservation) -> Int {
        switch reservation.status {
        case .authorized: return 0
        case .offerSent: return 1
        case .waitlisted: return 2 + (reservation.waitlistPosition ?? 0)
        default: return 100
        }
    }

    private func log(_ kind: BusinessEventKind, _ detail: String) {
        events.append(BusinessEvent(kind: kind, detail: detail, date: Date()))
    }
}

// MARK: - Demo data

extension BusinessStore {
    /// One evening at Knightro's Kitchen. Times are relative to "now" so the demo always works.
    /// Reserved pickups has exactly two students. Alex Knight's reservation uses the token in
    /// KnightPass.sample, so scanning the Knight Pass from Profile verifies it.
    static func demo(now: Date = Date()) -> BusinessStore {
        let profile = BusinessProfile.demo
        let base = PickupTime.roundedDown(now)
        func at(_ minutes: Int) -> Date { base.addingTimeInterval(TimeInterval(minutes * 60)) }

        // Pickup open now. 7 bags = 1 collected + 3 reserved (Alex 1, Jordan 2) + 3 available.
        // 14 bagels, 7 pastries, 7 sandwiches -> each bag: 2 bagels, 1 pastry, 1 sandwich.
        let tonight = BusinessListing(
            price: 5.99, totalQuantity: 7, remainingQuantity: 3,
            pickupStart: at(-10), pickupEnd: at(40),
            publicDescription: BusinessRules.defaultPublicDescription,
            pickupAddress: profile.pickupAddress, latitude: profile.latitude, longitude: profile.longitude,
            inventory: [SurplusItem(name: "Bagels", quantity: 14), SurplusItem(name: "Pastries", quantity: 7),
                        SurplusItem(name: "Sandwiches", quantity: 7)],
            createdAt: at(-120), updatedAt: at(-30)
        )
        // Later pickup, nothing reserved yet. Bags differ, so the staff note lists each bag.
        let later = BusinessListing(
            price: 4.99, totalQuantity: 4, remainingQuantity: 4,
            pickupStart: at(90), pickupEnd: at(120),
            publicDescription: "A mix of tonight's surplus items from the grill.",
            pickupAddress: profile.pickupAddress, latitude: profile.latitude, longitude: profile.longitude,
            inventory: [SurplusItem(name: "Wraps", quantity: 6), SurplusItem(name: "Salads", quantity: 4),
                        SurplusItem(name: "Cookies", quantity: 4)],
            createdAt: at(-60), updatedAt: at(-60)
        )
        // Earlier pickup, finished: 4 bags = 3 collected + 1 missed.
        let earlier = BusinessListing(
            price: 3.99, totalQuantity: 4, remainingQuantity: 0,
            pickupStart: at(-180), pickupEnd: at(-150),
            publicDescription: BusinessRules.defaultPublicDescription,
            pickupAddress: profile.pickupAddress, latitude: profile.latitude, longitude: profile.longitude,
            inventory: [SurplusItem(name: "Muffins", quantity: 8), SurplusItem(name: "Fruit cups", quantity: 4)],
            state: .closed,
            createdAt: at(-300), updatedAt: at(-150)
        )

        func reservation(
            _ code: String, _ name: String, _ token: String, _ listing: BusinessListing, quantity: Int,
            status: PickupStatus, payment: PaymentState,
            verified: Date? = nil, measured: Double? = nil
        ) -> BusinessReservation {
            BusinessReservation(
                code: code, studentDisplayName: name, passToken: token, listingID: listing.id,
                quantity: quantity, unitPrice: listing.price,
                pickupStart: listing.pickupStart, pickupEnd: listing.pickupEnd,
                status: status, payment: payment,
                createdAt: at(-90), verifiedAt: verified, measuredWeightKg: measured
            )
        }

        let reservations = [
            // Reserved pickups: exactly these two.
            reservation("KS-4821", KnightPass.sample.displayName, KnightPass.sample.verificationToken, tonight,
                        quantity: 1, status: .authorized, payment: .authorized),
            reservation("KS-3307", "Jordan P.", "demo-JORDAN-3307", tonight,
                        quantity: 2, status: .authorized, payment: .authorized),
            // Already collected today (Today's total and the impact report).
            reservation("KS-2018", "Sam W.", "demo-SAM-2018", tonight,
                        quantity: 1, status: .paymentCaptured, payment: .captured,
                        verified: at(-5), measured: 0.52),
            reservation("KS-1404", "Diego A.", "demo-DIEGO-1404", earlier,
                        quantity: 1, status: .paymentCaptured, payment: .captured, verified: at(-170)),
            reservation("KS-1477", "Nia B.", "demo-NIA-1477", earlier,
                        quantity: 2, status: .paymentCaptured, payment: .captured, verified: at(-160)),
            reservation("KS-1530", "Omar F.", "demo-OMAR-1530", earlier,
                        quantity: 1, status: .missed, payment: .released),
        ]

        let feedback = [
            PickupFeedback(reservationCode: "KS-1404", overall: 5, portion: 5, surpriseQuality: 4, pickupExperience: 5,
                           comment: "Way more food than I expected. Pickup took 30 seconds.",
                           wouldReserveAgain: true, submittedAt: at(-140)),
            PickupFeedback(reservationCode: "KS-1477", overall: 4, portion: 4, surpriseQuality: 4, pickupExperience: 5,
                           comment: "Good mix, staff were quick with the scan.",
                           wouldReserveAgain: true, submittedAt: at(-120)),
        ]

        return BusinessStore(
            profile: profile,
            isDemo: true,
            listings: [tonight, later, earlier],
            reservations: reservations,
            feedback: feedback
        )
    }
}
