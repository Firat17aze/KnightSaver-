import SwiftUI

enum ListingBannerCatalog {
    static let assetNames = [
        "BannerBagels",
        "BannerBakeryDisplay",
        "BannerCafeBrunch",
        "BannerCafeTable",
        "BannerCoffeePastry",
        "BannerCoffeeTable",
        "BannerCroissants",
        "BannerPastryFlatlay",
        "BannerPastryShelves"
    ]

    static func random(excluding previous: String? = nil) -> String {
        let choices = assetNames.filter { $0 != previous }
        return choices.randomElement() ?? assetNames[0]
    }
}

private extension Date {
    static func nextPickup(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        let today = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
        return today > Date() ? today : calendar.date(byAdding: .day, value: 1, to: today) ?? today
    }
}

/// Real UCF dining places (businessservices.ucf.edu, map.ucf.edu). The Surprise Bag listings
/// on them are demo data until each place joins KnightSaver.
enum BagBrand: String, CaseIterable, Hashable {
    case knightros
    case starbucks
    case smoothieKing
    case hueyMagoos
    case pandaExpress
    case qdoba
    case whichWich
    case barnies
    case chickFilA
    case foxtail
    case burgerU
    case dominos
    case dunkin
    case subway
    case sixtyThreeSouth
    case smallsSliders
    case einstein

    var mark: String {
        switch self {
        case .knightros: "K"
        case .starbucks: "S"
        case .smoothieKing: "SK"
        case .hueyMagoos: "H"
        case .pandaExpress: "P"
        case .qdoba: "Q"
        case .whichWich: "W"
        case .barnies: "B"
        case .chickFilA: "C"
        case .foxtail: "F"
        case .burgerU: "BU"
        case .dominos: "D"
        case .dunkin: "DK"
        case .subway: "SW"
        case .sixtyThreeSouth: "63"
        case .smallsSliders: "SS"
        case .einstein: "E"
        }
    }

    var wordmark: String {
        switch self {
        case .knightros: "KNIGHTRO’S"
        case .starbucks: "STARBUCKS"
        case .smoothieKing: "SMOOTHIE KING"
        case .hueyMagoos: "HUEY MAGOO’S"
        case .pandaExpress: "PANDA EXPRESS"
        case .qdoba: "QDOBA"
        case .whichWich: "WHICH WICH"
        case .barnies: "BARNIE’S"
        case .chickFilA: "CHICK-FIL-A"
        case .foxtail: "FOXTAIL COFFEE"
        case .burgerU: "BURGER U"
        case .dominos: "DOMINO’S"
        case .dunkin: "DUNKIN’"
        case .subway: "SUBWAY"
        case .sixtyThreeSouth: "’63 SOUTH"
        case .smallsSliders: "SMALLS SLIDERS"
        case .einstein: "EINSTEIN BROS."
        }
    }

    var primary: Color {
        switch self {
        case .knightros: Color(red: 0.10, green: 0.09, blue: 0.08)
        case .starbucks: Color(red: 0.00, green: 0.38, blue: 0.27)
        case .smoothieKing: Color(red: 0.65, green: 0.07, blue: 0.17)
        case .hueyMagoos: Color(red: 0.47, green: 0.10, blue: 0.10)
        case .pandaExpress: Color(red: 0.62, green: 0.06, blue: 0.10)
        case .qdoba: Color(red: 0.30, green: 0.14, blue: 0.08)
        case .whichWich: Color(red: 0.12, green: 0.12, blue: 0.12)
        case .barnies: Color(red: 0.33, green: 0.18, blue: 0.10)
        case .chickFilA: Color(red: 0.70, green: 0.05, blue: 0.15)
        case .foxtail: Color(red: 0.80, green: 0.33, blue: 0.10)
        case .burgerU: Color(red: 0.15, green: 0.13, blue: 0.11)
        case .dominos: Color(red: 0.00, green: 0.33, blue: 0.58)
        case .dunkin: Color(red: 0.76, green: 0.27, blue: 0.05)
        case .subway: Color(red: 0.00, green: 0.42, blue: 0.22)
        case .sixtyThreeSouth: Color(red: 0.12, green: 0.24, blue: 0.38)
        case .smallsSliders: Color(red: 0.85, green: 0.38, blue: 0.08)
        case .einstein: Color(red: 0.24, green: 0.16, blue: 0.35)
        }
    }

    var secondary: Color {
        switch self {
        case .knightros: KnightTheme.gold
        case .starbucks: Color(red: 0.80, green: 0.90, blue: 0.84)
        case .smoothieKing: Color(red: 0.98, green: 0.82, blue: 0.82)
        case .hueyMagoos: Color(red: 0.98, green: 0.78, blue: 0.36)
        case .pandaExpress: Color(red: 0.99, green: 0.80, blue: 0.75)
        case .qdoba: Color(red: 0.98, green: 0.70, blue: 0.40)
        case .whichWich: Color(red: 0.98, green: 0.85, blue: 0.20)
        case .barnies: Color(red: 0.90, green: 0.78, blue: 0.62)
        case .chickFilA: Color(red: 0.99, green: 0.86, blue: 0.86)
        case .foxtail: Color(red: 0.99, green: 0.86, blue: 0.72)
        case .burgerU: Color(red: 0.98, green: 0.74, blue: 0.25)
        case .dominos: Color(red: 0.80, green: 0.89, blue: 0.97)
        case .dunkin: Color(red: 1.00, green: 0.80, blue: 0.88)
        case .subway: Color(red: 0.99, green: 0.88, blue: 0.30)
        case .sixtyThreeSouth: Color(red: 0.70, green: 0.83, blue: 0.95)
        case .smallsSliders: Color(red: 1.00, green: 0.85, blue: 0.55)
        case .einstein: Color(red: 0.98, green: 0.80, blue: 0.45)
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
    var distance: Double
    let pickupWindow: String
    let pickupStart: Date?
    let pickupEnd: Date?
    let latitude: Double
    let longitude: Double
    let bannerAssetName: String
    let availableCount: Int
    let price: Double
    let description: String
    /// Street address of the pickup spot, shown in the bag details.
    var address: String = ""

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
            business: "Knightro's",
            location: "Dining hall · North campus",
            brand: .knightros,
            rating: 4.7,
            feedbackCount: 212,
            distance: 0.5,
            pickupWindow: "7:30–8:00 PM",
            pickupStart: .nextPickup(hour: 19, minute: 30),
            pickupEnd: .nextPickup(hour: 20, minute: 0),
            latitude: 28.60741,
            longitude: -81.19678,
            bannerAssetName: "BannerCafeBrunch",
            availableCount: 5,
            price: 5.99,
            description: "A mix of today's extra dishes from the dining hall stations, packed to go.",
            address: "4000 Central Florida Blvd, Orlando, FL 32816"
        ),
        SurpriseBag(
            business: "Starbucks",
            location: "Student Union",
            brand: .starbucks,
            rating: 4.6,
            feedbackCount: 188,
            distance: 0.1,
            pickupWindow: "8:00–8:30 PM",
            pickupStart: .nextPickup(hour: 20, minute: 0),
            pickupEnd: .nextPickup(hour: 20, minute: 30),
            latitude: 28.60167,
            longitude: -81.20053,
            bannerAssetName: "BannerCoffeePastry",
            availableCount: 3,
            price: 4.49,
            description: "Pastries and bakery items left at the end of the day.",
            address: "12715 Pegasus Cir, Bldg 52, Orlando, FL 32816"
        ),
        SurpriseBag(
            business: "Smoothie King",
            location: "Student Union",
            brand: .smoothieKing,
            rating: 4.4,
            feedbackCount: 73,
            distance: 0.1,
            pickupWindow: "7:00–7:30 PM",
            pickupStart: .nextPickup(hour: 19, minute: 0),
            pickupEnd: .nextPickup(hour: 19, minute: 30),
            latitude: 28.60167,
            longitude: -81.20053,
            bannerAssetName: "BannerCafeTable",
            availableCount: 2,
            price: 3.99,
            description: "Snacks and grab-and-go items from today's stock.",
            address: "12715 Pegasus Cir, Bldg 52, Orlando, FL 32816"
        ),
        SurpriseBag(
            business: "Huey Magoo's",
            location: "Student Union",
            brand: .hueyMagoos,
            rating: 4.5,
            feedbackCount: 96,
            distance: 0.1,
            pickupWindow: "8:30–9:00 PM",
            pickupStart: .nextPickup(hour: 20, minute: 30),
            pickupEnd: .nextPickup(hour: 21, minute: 0),
            latitude: 28.60167,
            longitude: -81.20053,
            bannerAssetName: "BannerCafeBrunch",
            availableCount: 2,
            price: 5.49,
            description: "Tenders and sides cooked today and not sold before close.",
            address: "12715 Pegasus Cir, Bldg 52, Orlando, FL 32816"
        ),
        SurpriseBag(
            business: "Panda Express",
            location: "Student Union",
            brand: .pandaExpress,
            rating: 4.3,
            feedbackCount: 141,
            distance: 0.1,
            pickupWindow: "8:15–8:45 PM",
            pickupStart: .nextPickup(hour: 20, minute: 15),
            pickupEnd: .nextPickup(hour: 20, minute: 45),
            latitude: 28.60167,
            longitude: -81.20053,
            bannerAssetName: "BannerCafeTable",
            availableCount: 4,
            price: 5.99,
            description: "Entrées and sides left on the line near close.",
            address: "12715 Pegasus Cir, Bldg 52, Orlando, FL 32816"
        ),
        SurpriseBag(
            business: "Qdoba",
            location: "Student Union",
            brand: .qdoba,
            rating: 4.4,
            feedbackCount: 88,
            distance: 0.1,
            pickupWindow: "8:00–8:30 PM",
            pickupStart: .nextPickup(hour: 20, minute: 0),
            pickupEnd: .nextPickup(hour: 20, minute: 30),
            latitude: 28.60167,
            longitude: -81.20053,
            bannerAssetName: "BannerCafeBrunch",
            availableCount: 0,
            price: 5.49,
            description: "Bowls and sides from today's prep. Join the waitlist for the next drop.",
            address: "12715 Pegasus Cir, Bldg 52, Orlando, FL 32816"
        ),
        SurpriseBag(
            business: "Which Wich",
            location: "Student Union",
            brand: .whichWich,
            rating: 4.3,
            feedbackCount: 54,
            distance: 0.1,
            pickupWindow: "7:45–8:15 PM",
            pickupStart: .nextPickup(hour: 19, minute: 45),
            pickupEnd: .nextPickup(hour: 20, minute: 15),
            latitude: 28.60167,
            longitude: -81.20053,
            bannerAssetName: "BannerCafeTable",
            availableCount: 3,
            price: 4.99,
            description: "Sandwiches and sides made today.",
            address: "12715 Pegasus Cir, Bldg 52, Orlando, FL 32816"
        ),
        SurpriseBag(
            business: "Barnie's Coffee & Tea",
            location: "John C. Hitt Library",
            brand: .barnies,
            rating: 4.7,
            feedbackCount: 119,
            distance: 0.1,
            pickupWindow: "6:00–6:30 PM",
            pickupStart: .nextPickup(hour: 18, minute: 0),
            pickupEnd: .nextPickup(hour: 18, minute: 30),
            latitude: 28.60005,
            longitude: -81.2016,
            bannerAssetName: "BannerCoffeeTable",
            availableCount: 2,
            price: 3.99,
            description: "Pastries and café bites from today's case.",
            address: "12701 Pegasus Dr, Orlando, FL 32816"
        ),
        SurpriseBag(
            business: "Chick-fil-A",
            location: "John T. Washington Center",
            brand: .chickFilA,
            rating: 4.8,
            feedbackCount: 233,
            distance: 0.1,
            pickupWindow: "5:30–6:00 PM",
            pickupStart: .nextPickup(hour: 17, minute: 30),
            pickupEnd: .nextPickup(hour: 18, minute: 0),
            latitude: 28.60084,
            longitude: -81.20213,
            bannerAssetName: "BannerCafeBrunch",
            availableCount: 1,
            price: 5.99,
            description: "Sandwiches and sides from today's extra prep.",
            address: "Aquarius Agora Dr, Bldg 26, Orlando, FL 32816"
        ),
        SurpriseBag(
            business: "Foxtail Coffee",
            location: "Knights Plaza",
            brand: .foxtail,
            rating: 4.8,
            feedbackCount: 102,
            distance: 0.4,
            pickupWindow: "4:30–5:00 PM",
            pickupStart: .nextPickup(hour: 16, minute: 30),
            pickupEnd: .nextPickup(hour: 17, minute: 0),
            latitude: 28.60689,
            longitude: -81.19842,
            bannerAssetName: "BannerCroissants",
            availableCount: 3,
            price: 3.99,
            description: "Pastries and baked goods from today's case.",
            address: "4201 E Plaza Dr, Orlando, FL 32816"
        ),
        SurpriseBag(
            business: "Burger U",
            location: "Knights Plaza",
            brand: .burgerU,
            rating: 4.5,
            feedbackCount: 97,
            distance: 0.4,
            pickupWindow: "9:00–9:30 PM",
            pickupStart: .nextPickup(hour: 21, minute: 0),
            pickupEnd: .nextPickup(hour: 21, minute: 30),
            latitude: 28.60689,
            longitude: -81.19842,
            bannerAssetName: "BannerCafeTable",
            availableCount: 2,
            price: 5.99,
            description: "Burgers and sides made today, packed after the evening rush.",
            address: "4233 E Plaza Dr, Orlando, FL 32816"
        ),
        SurpriseBag(
            business: "Domino's",
            location: "Knights Plaza",
            brand: .dominos,
            rating: 4.4,
            feedbackCount: 164,
            distance: 0.4,
            pickupWindow: "9:30–10:00 PM",
            pickupStart: .nextPickup(hour: 21, minute: 30),
            pickupEnd: .nextPickup(hour: 22, minute: 0),
            latitude: 28.60689,
            longitude: -81.19842,
            bannerAssetName: "BannerCafeBrunch",
            availableCount: 6,
            price: 4.99,
            description: "Pizza and sides made tonight and not picked up.",
            address: "Knights Plaza, Suite G, E Plaza Dr, Orlando, FL 32816"
        ),
        SurpriseBag(
            business: "Dunkin'",
            location: "Knights Plaza",
            brand: .dunkin,
            rating: 4.4,
            feedbackCount: 128,
            distance: 0.4,
            pickupWindow: "6:30–7:00 PM",
            pickupStart: .nextPickup(hour: 18, minute: 30),
            pickupEnd: .nextPickup(hour: 19, minute: 0),
            latitude: 28.60689,
            longitude: -81.19842,
            bannerAssetName: "BannerPastryShelves",
            availableCount: 4,
            price: 3.49,
            description: "Donuts and bagels left in the case at the end of the day.",
            address: "E Plaza Dr, Orlando, FL 32816"
        ),
        SurpriseBag(
            business: "Subway",
            location: "Knights Plaza",
            brand: .subway,
            rating: 4.3,
            feedbackCount: 109,
            distance: 0.4,
            pickupWindow: "8:45–9:15 PM",
            pickupStart: .nextPickup(hour: 20, minute: 45),
            pickupEnd: .nextPickup(hour: 21, minute: 15),
            latitude: 28.60689,
            longitude: -81.19842,
            bannerAssetName: "BannerCafeTable",
            availableCount: 3,
            price: 4.49,
            description: "Subs and sides made today.",
            address: "E Plaza Dr, Orlando, FL 32816"
        ),
        SurpriseBag(
            business: "'63 South",
            location: "Dining hall · South campus",
            brand: .sixtyThreeSouth,
            rating: 4.6,
            feedbackCount: 175,
            distance: 0.3,
            pickupWindow: "7:45–8:15 PM",
            pickupStart: .nextPickup(hour: 19, minute: 45),
            pickupEnd: .nextPickup(hour: 20, minute: 15),
            latitude: 28.59789,
            longitude: -81.19977,
            bannerAssetName: "BannerBakeryDisplay",
            availableCount: 4,
            price: 5.99,
            description: "Extra dishes from the dining hall stations, packed to go after dinner.",
            address: "4000 Central Florida Blvd, Orlando, FL 32816"
        ),
        SurpriseBag(
            business: "Smalls Sliders",
            location: "Gemini Blvd · next to the RWC",
            brand: .smallsSliders,
            rating: 4.7,
            feedbackCount: 41,
            distance: 0.4,
            pickupWindow: "9:15–9:45 PM",
            pickupStart: .nextPickup(hour: 21, minute: 15),
            pickupEnd: .nextPickup(hour: 21, minute: 45),
            latitude: 28.59605,
            longitude: -81.19877,
            bannerAssetName: "BannerCafeBrunch",
            availableCount: 2,
            price: 5.49,
            description: "Sliders and sides made today.",
            address: "4000 Central Florida Blvd, Orlando, FL 32816"
        ),
        SurpriseBag(
            business: "Einstein Bros. Bagels",
            location: "Business Administration I",
            brand: .einstein,
            rating: 4.5,
            feedbackCount: 86,
            distance: 0.1,
            pickupWindow: "3:00–3:30 PM",
            pickupStart: .nextPickup(hour: 15, minute: 0),
            pickupEnd: .nextPickup(hour: 15, minute: 30),
            latitude: 28.60101,
            longitude: -81.19922,
            bannerAssetName: "BannerBagels",
            availableCount: 3,
            price: 3.99,
            description: "Bagels and spreads from today's batch.",
            address: "Business Administration I, Bldg 45, 4000 Central Florida Blvd, Orlando, FL 32816"
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
