import SwiftUI

enum BagBrand: String, CaseIterable, Hashable {
    case knightros
    case campusBakery
    case arenaMarket
    case libraryCafe

    var mark: String {
        switch self {
        case .knightros: "K"
        case .campusBakery: "B"
        case .arenaMarket: "A"
        case .libraryCafe: "L"
        }
    }

    var wordmark: String {
        switch self {
        case .knightros: "KNIGHTRO’S KITCHEN"
        case .campusBakery: "CAMPUS BAKERY"
        case .arenaMarket: "ARENA MARKET"
        case .libraryCafe: "LIBRARY CAFÉ"
        }
    }

    var primary: Color {
        switch self {
        case .knightros: Color(red: 0.10, green: 0.09, blue: 0.08)
        case .campusBakery: Color(red: 0.36, green: 0.17, blue: 0.10)
        case .arenaMarket: Color(red: 0.09, green: 0.30, blue: 0.25)
        case .libraryCafe: Color(red: 0.16, green: 0.23, blue: 0.40)
        }
    }

    var secondary: Color {
        switch self {
        case .knightros: KnightTheme.gold
        case .campusBakery: Color(red: 0.94, green: 0.61, blue: 0.39)
        case .arenaMarket: Color(red: 0.55, green: 0.78, blue: 0.55)
        case .libraryCafe: Color(red: 0.57, green: 0.69, blue: 0.88)
        }
    }
}

struct SurpriseBag: Identifiable, Hashable {
    /// Bags published from Business use their listing id, so they keep the same identity when updated.
    var id = UUID()
    let business: String
    let location: String
    let brand: BagBrand
    let rating: Double
    let feedbackCount: Int
    let distance: Double
    let pickupWindow: String
    let availableCount: Int
    let price: Double
    let description: String

    var availabilityText: String {
        if availableCount == 0 { return "Fully reserved" }
        if availableCount <= 2 { return "Only \(availableCount) left" }
        return "\(availableCount) bags available"
    }

    var formattedPrice: String {
        price == 0 ? "Free" : String(format: "$%.2f", price)
    }

    static let samples: [SurpriseBag] = [
        SurpriseBag(
            business: "Knightro's Kitchen",
            location: "Student Union · Level 1",
            brand: .knightros,
            rating: 4.8,
            feedbackCount: 126,
            distance: 0.4,
            pickupWindow: "7:00–7:30 PM",
            availableCount: 3,
            price: 5.99,
            description: "A changing mix of today’s surplus items, packed for one easy campus pickup."
        ),
        SurpriseBag(
            business: "Campus Bakery",
            location: "Memory Mall",
            brand: .campusBakery,
            rating: 4.6,
            feedbackCount: 84,
            distance: 0.7,
            pickupWindow: "6:30–7:00 PM",
            availableCount: 2,
            price: 4.49,
            description: "A surprise selection prepared from the bakery’s remaining items for the day."
        ),
        SurpriseBag(
            business: "Arena Market",
            location: "Addition Financial Arena",
            brand: .arenaMarket,
            rating: 4.5,
            feedbackCount: 61,
            distance: 1.1,
            pickupWindow: "8:00–8:30 PM",
            availableCount: 6,
            price: 6.49,
            description: "A convenient assortment of surplus market items available after evening service."
        ),
        SurpriseBag(
            business: "Library Café",
            location: "John C. Hitt Library",
            brand: .libraryCafe,
            rating: 4.7,
            feedbackCount: 93,
            distance: 0.2,
            pickupWindow: "5:45–6:15 PM",
            availableCount: 0,
            price: 3.99,
            description: "A rotating selection from the café’s available surplus. Join the waitlist for updates."
        )
    ]
}

enum ReservationStatus: String, Hashable {
    case confirmed = "Confirmed"
    case waitlistOffer = "Waitlist offer"
    case waitlisted = "Waitlisted"
    case verified = "Pickup verified"
}

struct KnightPass: Hashable {
    let memberID: String
    let displayName: String
    let campusName: String
    let verificationToken: String

    var verificationPayload: String {
        "knightsaver://verify-user/\(verificationToken)"
    }

    static let sample = KnightPass(
        memberID: "KNIGHT-0428",
        displayName: "Alex Knight",
        campusName: "UCF Main Campus",
        verificationToken: "demo-7F4C92B1A8E6"
    )
}

struct ActiveReservation: Identifiable, Hashable {
    /// Matches the BusinessReservation id for reservations from the shared BusinessStore.
    var id = UUID()
    let bag: SurpriseBag
    let status: ReservationStatus
    let paymentStatus: String
    let attentionMessage: String?

    var pickupCode: String {
        let compactID = id.uuidString.replacingOccurrences(of: "-", with: "")
        return "KS-\(compactID.prefix(12))"
    }

    static let sample = ActiveReservation(
        bag: SurpriseBag.samples[0],
        status: .confirmed,
        paymentStatus: "Payment authorized",
        attentionMessage: "Pickup starts in 1 hr 20 min"
    )
}
