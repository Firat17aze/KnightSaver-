import Foundation

// Business-side data for the Business tab (see business.md).
// Status values follow the "Recommended statuses" in business.md so both sides can share them.

// MARK: - Business profile

/// The logged-in business. Logo, address and map coordinates come from here,
/// so staff don't re-enter them for every listing.
struct BusinessProfile: Identifiable, Hashable {
    let id: UUID
    var name: String
    var brand: BagBrand
    var pickupAddress: String
    var latitude: Double
    var longitude: Double
    var rating: Double
    var feedbackCount: Int
    /// The most Surprise Bags one listing may have. Set by the owner in Profile; neither the
    /// AI proposal nor manual entry can go above it, and the database enforces it too.
    var maxBagsPerListing: Int = BusinessRules.defaultMaxBagsPerListing

    static let demo = BusinessProfile(
        id: UUID(),
        name: "Knightro's Kitchen",
        brand: .knightros,
        pickupAddress: "Student Union · Level 1",
        latitude: 28.6016,
        longitude: -81.2005,
        rating: 4.8,
        feedbackCount: 126
    )
}

// MARK: - Pickup spots

/// Where students collect a bag. Staff pick one when listing or editing.
/// Coordinates are approximate campus points, used for distance in Explore.
struct PickupLocation: Identifiable, Hashable {
    let name: String
    let detail: String
    let latitude: Double
    let longitude: Double

    var id: String { address }
    var address: String { "\(name) · \(detail)" }

    static let campusSpots: [PickupLocation] = [
        PickupLocation(name: "Student Union", detail: "Level 1", latitude: 28.6016, longitude: -81.2005),
        PickupLocation(name: "John C. Hitt Library", detail: "Front entrance", latitude: 28.6003, longitude: -81.2017),
        PickupLocation(name: "Memory Mall", detail: "Reflecting pond", latitude: 28.6019, longitude: -81.1997),
        PickupLocation(name: "Engineering Atrium", detail: "Ground floor", latitude: 28.6015, longitude: -81.1983),
        PickupLocation(name: "Addition Financial Arena", detail: "Gate A", latitude: 28.6074, longitude: -81.1973),
    ]

    /// The spot that matches a saved address, or the first spot.
    static func matching(_ address: String) -> PickupLocation {
        campusSpots.first { $0.address == address } ?? campusSpots[0]
    }
}

// MARK: - Rules the AI and the plan screen follow

enum BusinessRules {
    /// Used to propose how many Surprise Bags to make from the surplus.
    static let targetItemsPerBag = 3
    /// Items above this per bag stay unallocated and are shown to staff.
    static let maxItemsPerBag = 6
    /// Used when staff don't mention a price.
    static let defaultBagPrice = 5.99
    /// Used when staff don't mention a pickup time.
    static let defaultPickupLength: TimeInterval = 30 * 60
    /// Rough weight per surplus item, for estimated impact only.
    static let estimatedKgPerItem = 0.15
    /// Rough CO₂e avoided per kg of food rescued. Always shown as an estimate.
    static let estimatedCO2eKgPerFoodKg = 2.5
    /// CO₂e goal shown on the Impact report bar.
    static let co2eGoalKg = 10.0
    /// Average car emissions per km, for the "km not driven" comparison. Estimate only.
    static let co2eKgPerCarKm = 0.17
    /// Public text students see. It must never promise contents.
    static let defaultPublicDescription = "A mix of today's surplus items."
    /// How early / late a Knight Pass scan still counts for a pickup window.
    static let pickupGrace: TimeInterval = 15 * 60
    /// Bag limit per listing until the owner changes it in Profile.
    static let defaultMaxBagsPerListing = 10
    /// What the owner can pick for that limit. Matches the check in the database.
    static let maxBagsPerListingRange = 1...100
}

// MARK: - Surplus inventory (staff only, never shown to students)

struct SurplusItem: Identifiable, Hashable {
    let id: UUID
    var name: String
    var quantity: Int

    init(id: UUID = UUID(), name: String, quantity: Int) {
        self.id = id
        self.name = name
        self.quantity = quantity
    }
}

extension Array where Element == SurplusItem {
    var totalUnits: Int { reduce(0) { $0 + Swift.max(0, $1.quantity) } }

    /// "12 bagels, 1 pastry, 4 sandwiches" — singular and plural handled.
    var summaryText: String {
        filter { $0.quantity > 0 }
            .map { ItemName.phrase(count: $0.quantity, name: $0.name) }
            .joined(separator: ", ")
    }

    /// Same items and counts, ignoring order and ids.
    func hasSameContents(as other: [SurplusItem]) -> Bool {
        func key(_ items: [SurplusItem]) -> [String] {
            items.filter { $0.quantity > 0 }
                .map { "\($0.name.lowercased())#\($0.quantity)" }
                .sorted()
        }
        return key(self) == key(other)
    }
}

/// Simple English singular/plural for item names staff say or type
/// ("1 pastry", "2 pastries", "1 sandwich", "3 slices of pizza").
enum ItemName {
    static func phrase(count: Int, name: String) -> String {
        let base = name.trimmingCharacters(in: .whitespaces).lowercased()
        return "\(count) \(count == 1 ? singular(base) : plural(base))"
    }

    static func singular(_ name: String) -> String {
        inflectHeadWord(of: name, using: singularWord)
    }

    static func plural(_ name: String) -> String {
        inflectHeadWord(of: name, using: pluralWord)
    }

    /// "slices of pizza" changes "slices"; "fruit cups" changes "cups".
    private static func inflectHeadWord(of name: String, using transform: (String) -> String) -> String {
        var words = name.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard !words.isEmpty else { return name }
        let headIndex = words.firstIndex(of: "of").map { max(0, $0 - 1) } ?? (words.count - 1)
        words[headIndex] = transform(words[headIndex])
        return words.joined(separator: " ")
    }

    private static let irregular: [String: String] = [
        "cookies": "cookie", "brownies": "brownie", "smoothies": "smoothie", "pies": "pie",
        "veggies": "veggie", "hoagies": "hoagie", "quiches": "quiche", "loaves": "loaf",
        "potatoes": "potato", "tomatoes": "tomato", "mangoes": "mango", "knives": "knife",
        "halves": "half", "people": "person", "children": "child",
    ]

    private static let uncountable: Set<String> = [
        "rice", "pasta", "sushi", "fruit", "bread", "cheese", "food",
    ]

    private static func singularWord(_ word: String) -> String {
        if let single = irregular[word] { return single }
        if uncountable.contains(word) { return word }
        if word.hasSuffix("ies"), word.count > 4 { return String(word.dropLast(3)) + "y" }
        for ending in ["ches", "shes", "sses", "xes", "zes", "oes"] where word.hasSuffix(ending) {
            return String(word.dropLast(2))
        }
        if word.hasSuffix("s"), !word.hasSuffix("ss"), word.count > 2 { return String(word.dropLast()) }
        return word
    }

    private static func pluralWord(_ word: String) -> String {
        if irregular[word] != nil { return word }
        if let plural = irregular.first(where: { $0.value == word })?.key { return plural }
        if uncountable.contains(word) { return word }
        // Already plural ("bagels", "pastries").
        if word.hasSuffix("s"), !word.hasSuffix("ss") { return word }
        if word.hasSuffix("y"), let before = word.dropLast().last, !"aeiou".contains(before) {
            return String(word.dropLast()) + "ies"
        }
        for ending in ["ch", "sh", "ss", "x", "z"] where word.hasSuffix(ending) {
            return word + "es"
        }
        return word + "s"
    }
}

// MARK: - Surprise Bag listing

enum SurpriseBagStatus: String, CaseIterable, Hashable {
    case draft = "Draft"
    case available = "Available"
    case fullyReserved = "Fully reserved"
    case paused = "Paused"
    case closed = "Closed"
    case cancelled = "Cancelled"
}

/// What staff control on top of the automatic available / fully reserved status.
enum ListingState: Hashable {
    case live
    case paused
    case closed
    case cancelled
}

struct BusinessListing: Identifiable, Hashable {
    let id: UUID
    /// Surprise Bags keep their contents secret. Turned off, it's a Rescue Bag with known contents.
    var isSurprise: Bool
    var label: String { isSurprise ? "Surprise Bag" : "Rescue Bag" }
    var price: Double
    var totalQuantity: Int
    /// Bags students can still reserve.
    var remainingQuantity: Int
    var pickupStart: Date
    var pickupEnd: Date
    var publicDescription: String
    var pickupAddress: String
    var latitude: Double
    var longitude: Double
    /// Chosen once at publication so Explore does not reshuffle artwork while scrolling.
    var bannerAssetName: String
    /// Staff-only record of what went into the bags.
    var inventory: [SurplusItem]
    /// Staff-only: what to put in each bag (from SurplusAssistant.allocate).
    var bagSplit: [[SurplusItem]]
    /// Staff-only: items that didn't fit in any bag.
    var unallocated: [SurplusItem]
    var state: ListingState
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        price: Double,
        totalQuantity: Int,
        remainingQuantity: Int,
        pickupStart: Date,
        pickupEnd: Date,
        publicDescription: String,
        pickupAddress: String,
        latitude: Double,
        longitude: Double,
        bannerAssetName: String = ListingBannerCatalog.random(),
        inventory: [SurplusItem],
        bagSplit: [[SurplusItem]]? = nil,
        unallocated: [SurplusItem] = [],
        isSurprise: Bool = true,
        state: ListingState = .live,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.price = price
        self.totalQuantity = totalQuantity
        self.remainingQuantity = remainingQuantity
        self.pickupStart = pickupStart
        self.pickupEnd = pickupEnd
        self.publicDescription = publicDescription
        self.pickupAddress = pickupAddress
        self.latitude = latitude
        self.longitude = longitude
        self.bannerAssetName = bannerAssetName
        self.inventory = inventory
        self.isSurprise = isSurprise
        if let bagSplit {
            self.bagSplit = bagSplit
            self.unallocated = unallocated
        } else {
            let allocation = SurplusAssistant.allocate(inventory, into: totalQuantity)
            self.bagSplit = allocation.bags
            self.unallocated = allocation.leftover
        }
        self.state = state
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var status: SurpriseBagStatus {
        switch state {
        case .paused: return .paused
        case .closed: return .closed
        case .cancelled: return .cancelled
        case .live: return remainingQuantity > 0 ? .available : .fullyReserved
        }
    }

    /// Students can reserve right now.
    var isReservable: Bool { status == .available }

    var pickupWindowText: String { PickupTime.window(pickupStart, pickupEnd) }

    /// The most bags this listing can show as available under the business's per-listing
    /// limit. Reserved and collected bags count toward the limit. A listing already above a
    /// newly lowered limit keeps what it has, but can't add more.
    func maxBagsAvailable(limit: Int) -> Int {
        let committed = totalQuantity - remainingQuantity
        return max(remainingQuantity, max(0, limit - committed))
    }

    /// Recomputes the per-bag split after the number of bags changes.
    mutating func reallocateBags() {
        let allocation = SurplusAssistant.allocate(inventory + unallocated, into: totalQuantity)
        bagSplit = allocation.bags
        unallocated = allocation.leftover
    }

    /// Staff note lines: one "Each bag: …" line when all bags match, otherwise "Bag 1: …".
    var staffPackingLines: [String] {
        let bags = bagSplit
        guard let first = bags.first else { return [] }
        var lines: [String]
        if bags.allSatisfy({ $0.hasSameContents(as: first) }) {
            lines = ["Each bag: \(first.isEmpty ? "nothing assigned" : first.summaryText)"]
        } else {
            lines = bags.enumerated().map { index, bag in
                "Bag \(index + 1): \(bag.isEmpty ? "nothing assigned" : bag.summaryText)"
            }
        }
        if !unallocated.isEmpty {
            lines.append("Not in a bag: \(unallocated.summaryText)")
        }
        return lines
    }

    /// Estimated food weight of one bag, from the staff inventory.
    var estimatedKgPerBag: Double {
        guard totalQuantity > 0 else { return 0 }
        return Double(inventory.totalUnits) * BusinessRules.estimatedKgPerItem / Double(totalQuantity)
    }
}

/// Playful, knight-themed names for each bag in a batch, so staff can tell them apart
/// without calling them "Bag 1, Bag 2". Paired with a Roman numeral.
enum BagName {
    private static let surpriseNames = [
        "Mystery Satchel", "Knight's Secret", "Sealed Pouch", "Dragon's Hoard",
        "Royal Riddle", "Hidden Treasure", "Squire's Stash", "Golden Gamble",
        "Castle Surprise", "Midnight Feast", "Lucky Lance", "Quest Bag",
    ]

    /// Rescue Bags show their contents, so their names don't promise a mystery.
    private static let rescueNames = [
        "Royal Basket", "Knight's Feast", "Squire's Supper", "Golden Platter",
        "Castle Pantry", "Banquet Box", "Trail Rations", "Great Hall Spread",
        "Jousting Lunch", "Crown Hamper", "Shield Snack", "Tower Treats",
    ]

    static func name(_ index: Int, isSurprise: Bool = true) -> String {
        let list = isSurprise ? surpriseNames : rescueNames
        return list[index % list.count]
    }

    static func numeral(_ index: Int) -> String {
        let values = [(10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")]
        var number = index + 1
        var result = ""
        for (value, symbol) in values {
            while number >= value {
                result += symbol
                number -= value
            }
        }
        return result
    }
}

// MARK: - Reservations

/// Reservation statuses from business.md.
enum PickupStatus: String, Hashable {
    case authorized = "Authorized"
    case waitlisted = "Waitlisted"
    case offerSent = "Offer sent"
    case cancelled = "Cancelled"
    case pickupVerified = "Pickup verified"
    case paymentCaptured = "Payment captured"
    case refunded = "Refunded"
    case missed = "Missed"
}

enum PaymentState: String, Hashable {
    case notStarted = "No payment yet"
    case authorized = "Payment authorized"
    case released = "Authorization released"
    case captured = "Payment captured"
    case refunded = "Refunded"
}

struct BusinessReservation: Identifiable, Hashable {
    let id: UUID
    /// Short identifier staff can read out, e.g. "KS-4821".
    let code: String
    var studentDisplayName: String
    /// Token inside the student's reusable Knight Pass QR.
    var passToken: String
    var listingID: UUID
    var quantity: Int
    var unitPrice: Double
    var pickupStart: Date
    var pickupEnd: Date
    var status: PickupStatus
    var payment: PaymentState
    /// Position in the waitlist when status is .waitlisted (1 = next).
    var waitlistPosition: Int?
    var createdAt: Date
    var verifiedAt: Date?
    /// Set only when staff actually weighed the bag.
    var measuredWeightKg: Double?

    init(
        id: UUID = UUID(),
        code: String = BusinessReservation.makeCode(),
        studentDisplayName: String,
        passToken: String,
        listingID: UUID,
        quantity: Int,
        unitPrice: Double,
        pickupStart: Date,
        pickupEnd: Date,
        status: PickupStatus,
        payment: PaymentState,
        waitlistPosition: Int? = nil,
        createdAt: Date = Date(),
        verifiedAt: Date? = nil,
        measuredWeightKg: Double? = nil
    ) {
        self.id = id
        self.code = code
        self.studentDisplayName = studentDisplayName
        self.passToken = passToken
        self.listingID = listingID
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.pickupStart = pickupStart
        self.pickupEnd = pickupEnd
        self.status = status
        self.payment = payment
        self.waitlistPosition = waitlistPosition
        self.createdAt = createdAt
        self.verifiedAt = verifiedAt
        self.measuredWeightKg = measuredWeightKg
    }

    var total: Double { unitPrice * Double(quantity) }

    var pickupWindowText: String { PickupTime.window(pickupStart, pickupEnd) }

    /// Shown in Reserved pickups.
    var isUpcoming: Bool {
        status == .authorized || status == .offerSent || status == .waitlisted
    }

    var isVerified: Bool {
        status == .pickupVerified || status == .paymentCaptured
    }

    static func makeCode() -> String {
        "KS-\(Int.random(in: 1000...9999))"
    }
}

// MARK: - Feedback (read-only for business)

struct PickupFeedback: Identifiable, Hashable {
    let id: UUID
    var reservationCode: String
    var overall: Int
    var portion: Int
    var surpriseQuality: Int
    var pickupExperience: Int
    var comment: String
    var wouldReserveAgain: Bool
    var submittedAt: Date

    init(
        id: UUID = UUID(),
        reservationCode: String,
        overall: Int,
        portion: Int,
        surpriseQuality: Int,
        pickupExperience: Int,
        comment: String,
        wouldReserveAgain: Bool,
        submittedAt: Date
    ) {
        self.id = id
        self.reservationCode = reservationCode
        self.overall = overall
        self.portion = portion
        self.surpriseQuality = surpriseQuality
        self.pickupExperience = pickupExperience
        self.comment = comment
        self.wouldReserveAgain = wouldReserveAgain
        self.submittedAt = submittedAt
    }
}

// MARK: - Impact

struct BusinessImpact: Hashable {
    var bagsCollected: Int
    var measuredWeightKg: Double
    var estimatedWeightKg: Double
    var estimatedCO2eKg: Double
    var revenueRecovered: Double
    /// Verified pickups (one per reservation, a reservation can hold several bags).
    var verifiedPickups: Int
    /// Verified plus missed pickups.
    var pickupsDue: Int
    /// nil until at least one pickup was due.
    var pickupCompletionRate: Double?
    /// nil until verified students leave a rating.
    var averageRating: Double?
    var ratingCount: Int
}

// MARK: - Integration events (business.md "Shared integration contract")

enum BusinessEventKind: String, Hashable {
    case surplusInventoryConfirmed = "Surplus inventory confirmed"
    case aiBagPlanApproved = "AI bag plan approved"
    case listingPublished = "Listing published"
    case listingUpdated = "Listing updated"
    case reservationCreated = "Reservation created"
    case reservationCancelled = "Reservation cancelled"
    case waitlistOfferCreated = "Waitlist offer created"
    case pickupVerified = "Pickup verified"
    case paymentCaptured = "Payment captured"
    case impactRecorded = "Impact recorded"
    case leaderboardCredited = "Leaderboard credited"
    case feedbackSubmitted = "Feedback submitted"
}

struct BusinessEvent: Identifiable, Hashable {
    let id = UUID()
    let kind: BusinessEventKind
    let detail: String
    let date: Date
}

// MARK: - Time helpers

enum PickupTime {
    private static let shortFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        return formatter
    }()

    private static let fullFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    private static let meridiemFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "a"
        return formatter
    }()

    /// "7:00–7:30 PM", or "11:30 AM–12:00 PM" when AM/PM differ.
    static func window(_ start: Date, _ end: Date) -> String {
        if meridiemFormatter.string(from: start) == meridiemFormatter.string(from: end) {
            return "\(shortFormatter.string(from: start))–\(fullFormatter.string(from: end))"
        }
        return "\(fullFormatter.string(from: start))–\(fullFormatter.string(from: end))"
    }

    static func time(_ date: Date) -> String {
        fullFormatter.string(from: date)
    }

    static func money(_ value: Double) -> String {
        String(format: "$%.2f", value)
    }

    /// Rounds down to the previous 5 minutes, so demo times look natural.
    static func roundedDown(_ date: Date, calendar: Calendar = .current) -> Date {
        let minute = calendar.component(.minute, from: date)
        let base = calendar.dateInterval(of: .minute, for: date)?.start ?? date
        return calendar.date(byAdding: .minute, value: -(minute % 5), to: base) ?? date
    }
}
