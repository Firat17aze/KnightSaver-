import Foundation

// MARK: - Listing

enum ListingStatus: String, CaseIterable, Identifiable {
    case available
    case fullyReserved
    case paused
    case closed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .available: return "Available"
        case .fullyReserved: return "Fully reserved"
        case .paused: return "Paused"
        case .closed: return "Closed"
        }
    }
}

/// Food a business has put up for students to rescue.
struct Listing: Identifiable, Equatable {
    let id: UUID
    var name: String
    var details: String
    /// Entered and confirmed by staff only. The AI assistant never fills this in.
    var allergens: String
    /// Portions still available for students to reserve.
    var quantityRemaining: Int
    var price: Double
    /// Normal menu price, used to calculate student savings.
    var originalPrice: Double
    var pickupDeadline: Date
    var weightPerPortionKg: Double
    /// true = weighed on a scale, false = estimate. Must stay clearly labeled.
    var weightIsMeasured: Bool
    var isPaused: Bool
    var isClosed: Bool

    init(
        id: UUID = UUID(),
        name: String,
        details: String = "",
        allergens: String,
        quantityRemaining: Int,
        price: Double,
        originalPrice: Double,
        pickupDeadline: Date,
        weightPerPortionKg: Double,
        weightIsMeasured: Bool,
        isPaused: Bool = false,
        isClosed: Bool = false
    ) {
        self.id = id
        self.name = name
        self.details = details
        self.allergens = allergens
        self.quantityRemaining = quantityRemaining
        self.price = price
        self.originalPrice = originalPrice
        self.pickupDeadline = pickupDeadline
        self.weightPerPortionKg = weightPerPortionKg
        self.weightIsMeasured = weightIsMeasured
        self.isPaused = isPaused
        self.isClosed = isClosed
    }

    var status: ListingStatus {
        if isClosed { return .closed }
        if isPaused { return .paused }
        if quantityRemaining <= 0 { return .fullyReserved }
        return .available
    }
}

// MARK: - Reservations

enum PaymentStatus: String {
    /// Card authorized at reservation time, not charged yet.
    case authorized
    /// Student cancelled, the hold was released.
    case released
    /// Staff verified pickup, payment was charged.
    case captured

    var label: String {
        switch self {
        case .authorized: return "Payment authorized"
        case .released: return "Payment released"
        case .captured: return "Payment captured"
        }
    }
}

/// A student's upcoming pickup.
struct Reservation: Identifiable, Equatable {
    let id: UUID
    /// Short code shown on the student's QR pickup pass, e.g. "KS-4821".
    let code: String
    var studentName: String
    var listingID: UUID
    var itemName: String
    var quantity: Int
    var unitPrice: Double
    var originalUnitPrice: Double
    var pickupDeadline: Date
    var payment: PaymentStatus
    /// true when this spot was given to a student from the waitlist.
    var fromWaitlist: Bool

    init(
        id: UUID = UUID(),
        code: String = Reservation.makeCode(),
        studentName: String,
        listingID: UUID,
        itemName: String,
        quantity: Int,
        unitPrice: Double,
        originalUnitPrice: Double,
        pickupDeadline: Date,
        payment: PaymentStatus = .authorized,
        fromWaitlist: Bool = false
    ) {
        self.id = id
        self.code = code
        self.studentName = studentName
        self.listingID = listingID
        self.itemName = itemName
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.originalUnitPrice = originalUnitPrice
        self.pickupDeadline = pickupDeadline
        self.payment = payment
        self.fromWaitlist = fromWaitlist
    }

    var total: Double { unitPrice * Double(quantity) }

    static func makeCode() -> String {
        "KS-\(Int.random(in: 1000...9999))"
    }
}

/// A student waiting for a portion of a fully reserved listing.
struct WaitlistEntry: Identifiable, Equatable {
    let id: UUID
    var studentName: String
    var listingID: UUID
    var quantity: Int

    init(id: UUID = UUID(), studentName: String, listingID: UUID, quantity: Int = 1) {
        self.id = id
        self.studentName = studentName
        self.listingID = listingID
        self.quantity = quantity
    }
}

// MARK: - Completed rescues

/// A pickup that staff verified with the student's QR pass.
struct Rescue: Identifiable, Equatable {
    let id: UUID
    let reservationCode: String
    var studentName: String
    var itemName: String
    var quantity: Int
    var pickedUpAt: Date
    var amountCaptured: Double
    var studentSavings: Double
    var weightKg: Double
    var weightIsMeasured: Bool

    init(
        id: UUID = UUID(),
        reservationCode: String,
        studentName: String,
        itemName: String,
        quantity: Int,
        pickedUpAt: Date,
        amountCaptured: Double,
        studentSavings: Double,
        weightKg: Double,
        weightIsMeasured: Bool
    ) {
        self.id = id
        self.reservationCode = reservationCode
        self.studentName = studentName
        self.itemName = itemName
        self.quantity = quantity
        self.pickedUpAt = pickedUpAt
        self.amountCaptured = amountCaptured
        self.studentSavings = studentSavings
        self.weightKg = weightKg
        self.weightIsMeasured = weightIsMeasured
    }
}

// MARK: - Impact

struct ImpactSummary: Equatable {
    var portionsRescued: Int
    var measuredWeightKg: Double
    var estimatedWeightKg: Double
    var revenueRecovered: Double
    var studentSavings: Double
    /// nil when there is nothing to measure yet.
    var pickupCompletionRate: Double?

    var totalWeightKg: Double { measuredWeightKg + estimatedWeightKg }
}

// MARK: - Draft used by the create / edit forms

/// Editable copy of a listing. Staff review this before anything goes live.
struct ListingDraft: Equatable {
    var name: String = ""
    var details: String = ""
    var allergens: String = ""
    var quantity: Int = 1
    var price: Double = 0
    var originalPrice: Double = 0
    var pickupDeadline: Date = ListingDraft.defaultDeadline()
    var weightPerPortionKg: Double = 0.3
    var weightIsMeasured: Bool = false
    /// Staff must tick these. AI can never set them.
    var staffConfirmedAllergens: Bool = false
    var staffConfirmedFoodSafety: Bool = false

    init() {}

    init(listing: Listing) {
        name = listing.name
        details = listing.details
        allergens = listing.allergens
        quantity = listing.quantityRemaining
        price = listing.price
        originalPrice = listing.originalPrice
        pickupDeadline = listing.pickupDeadline
        weightPerPortionKg = listing.weightPerPortionKg
        weightIsMeasured = listing.weightIsMeasured
        // Already confirmed when the listing was first published.
        staffConfirmedAllergens = true
        staffConfirmedFoodSafety = true
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Reasons the draft cannot be published yet. Empty means it is ready.
    var problems: [String] {
        var result: [String] = []
        if trimmedName.isEmpty { result.append("Add a food name.") }
        if quantity < 1 { result.append("Quantity must be at least 1.") }
        if price < 0 { result.append("Price can't be negative.") }
        if !staffConfirmedAllergens { result.append("Staff must confirm the allergen info.") }
        if !staffConfirmedFoodSafety { result.append("Staff must confirm food safety.") }
        return result
    }

    var isReady: Bool { problems.isEmpty }

    /// Today at 8:00 PM, or one hour from now if that has already passed.
    static func defaultDeadline(now: Date = Date(), calendar: Calendar = .current) -> Date {
        let eightPM = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: now) ?? now
        return eightPM > now ? eightPM : now.addingTimeInterval(3600)
    }
}
