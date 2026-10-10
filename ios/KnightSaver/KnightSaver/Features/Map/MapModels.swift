import CoreLocation
import SwiftUI

// KnightMap data (student.md "KnightMap"). Every kitchen on campus, its weekly hours,
// and what it has for students right now.

// MARK: - Kinds

enum KitchenKind: String, CaseIterable, Identifiable {
    case chain = "Chains"
    case cafe = "Cafés"
    case bakery = "Bakeries"
    case market = "Markets"

    var id: String { rawValue }

    var singular: String {
        switch self {
        case .chain: "Restaurant chain"
        case .cafe: "Café"
        case .bakery: "Bakery"
        case .market: "Market"
        }
    }

    var icon: String {
        switch self {
        case .chain: "fork.knife"
        case .cafe: "cup.and.saucer.fill"
        case .bakery: "birthday.cake.fill"
        case .market: "basket.fill"
        }
    }
}

// MARK: - Weekly hours

/// One opening span, in minutes after midnight. `close` can pass 1440 when a place
/// closes after midnight (for example 11:00 AM to 2:00 AM is 660...1560).
struct OpenSpan: Hashable {
    let open: Int
    let close: Int

    init(_ open: (Int, Int), _ close: (Int, Int)) {
        self.open = open.0 * 60 + open.1
        let end = close.0 * 60 + close.1
        self.close = end <= self.open ? end + 1_440 : end
    }

    var closesAfterMidnight: Bool { close > 1_440 }
}

enum KitchenStatus: Equatable {
    case open(until: Date)
    case closed(opensAt: Date?)

    var isOpen: Bool {
        if case .open = self { return true }
        return false
    }
}

/// Hours for each weekday. Keys follow `Calendar` weekdays: 1 = Sunday … 7 = Saturday.
/// A missing day means closed all day.
struct WeeklyHours: Hashable {
    let days: [Int: OpenSpan]

    /// Monday first, the way students read a week.
    static let displayOrder = [2, 3, 4, 5, 6, 7, 1]

    static func make(weekdays: OpenSpan?, friday: OpenSpan? = nil, saturday: OpenSpan?, sunday: OpenSpan?) -> WeeklyHours {
        var days: [Int: OpenSpan] = [:]
        for day in 2...5 { days[day] = weekdays }
        days[6] = friday ?? weekdays
        days[7] = saturday
        days[1] = sunday
        return WeeklyHours(days: days.compactMapValues { $0 })
    }

    func status(at now: Date = Date(), calendar: Calendar = .current) -> KitchenStatus {
        let today = calendar.startOfDay(for: now)
        // Yesterday's span may still be running after midnight, so check it first.
        for back in [1, 0] {
            guard let day = calendar.date(byAdding: .day, value: -back, to: today),
                  let span = days[calendar.component(.weekday, from: day)] else { continue }
            let start = day.addingTimeInterval(TimeInterval(span.open * 60))
            let end = day.addingTimeInterval(TimeInterval(span.close * 60))
            if now >= start && now < end { return .open(until: end) }
        }
        return .closed(opensAt: nextOpening(after: now, calendar: calendar))
    }

    func nextOpening(after now: Date, calendar: Calendar = .current) -> Date? {
        let today = calendar.startOfDay(for: now)
        for ahead in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: ahead, to: today),
                  let span = days[calendar.component(.weekday, from: day)] else { continue }
            let start = day.addingTimeInterval(TimeInterval(span.open * 60))
            if start > now { return start }
        }
        return nil
    }

    func span(weekday: Int) -> OpenSpan? { days[weekday] }
}

// MARK: - A kitchen on the map

struct CampusKitchen: Identifiable, Hashable {
    let id: String
    let name: String
    let kind: KitchenKind
    /// Kitchens that already sell bags in Explore use their Explore brand for the marker.
    let brand: BagBrand?
    let monogram: String
    let tint: Color
    let ink: Color
    let building: String
    let latitude: Double
    let longitude: Double
    let rating: Double
    let hours: WeeklyHours
    /// When this kitchen usually lists bags. Shown when nothing is listed right now.
    let usualDrop: String

    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
    var location: CLLocation { CLLocation(latitude: latitude, longitude: longitude) }

    static func == (lhs: CampusKitchen, rhs: CampusKitchen) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension CampusKitchen {
    private static func brandKitchen(
        _ brand: BagBrand, name: String, kind: KitchenKind, building: String,
        _ latitude: Double, _ longitude: Double, rating: Double, hours: WeeklyHours, usualDrop: String
    ) -> CampusKitchen {
        CampusKitchen(
            id: brand.rawValue, name: name, kind: kind, brand: brand, monogram: brand.mark,
            tint: brand.secondary, ink: brand.primary, building: building,
            latitude: latitude, longitude: longitude, rating: rating, hours: hours, usualDrop: usualDrop
        )
    }

    private static func kitchen(
        _ id: String, name: String, kind: KitchenKind, monogram: String,
        tint: (Double, Double, Double), ink: (Double, Double, Double), building: String,
        _ latitude: Double, _ longitude: Double, rating: Double, hours: WeeklyHours, usualDrop: String
    ) -> CampusKitchen {
        CampusKitchen(
            id: id, name: name, kind: kind, brand: nil, monogram: monogram,
            tint: Color(red: tint.0, green: tint.1, blue: tint.2),
            ink: Color(red: ink.0, green: ink.1, blue: ink.2), building: building,
            latitude: latitude, longitude: longitude, rating: rating, hours: hours, usualDrop: usualDrop
        )
    }

    /// Demo partner kitchens on UCF Main Campus. Names and hours are made up for the
    /// prototype; coordinates are approximate campus points. Kitchens that sell daily bags
    /// stay open through their pickup windows.
    static let campus: [CampusKitchen] = [
        brandKitchen(.knightros, name: "Knightro's Kitchen", kind: .chain, building: "Student Union · Level 1",
                     28.6016, -81.2005, rating: 4.8,
                     hours: .make(weekdays: OpenSpan((7, 0), (23, 0)), friday: OpenSpan((7, 0), (22, 0)),
                                  saturday: OpenSpan((9, 0), (22, 0)), sunday: OpenSpan((10, 0), (22, 0))),
                     usualDrop: "Bags usually drop around 6 PM"),
        brandKitchen(.campusBakery, name: "Campus Bakery", kind: .bakery, building: "Memory Mall",
                     28.6028, -81.1977, rating: 4.6,
                     hours: .make(weekdays: OpenSpan((6, 30), (19, 30)), saturday: OpenSpan((8, 0), (19, 30)), sunday: OpenSpan((9, 0), (19, 30))),
                     usualDrop: "Bags usually drop around 5:30 PM"),
        brandKitchen(.arenaMarket, name: "Arena Market", kind: .market, building: "Addition Financial Arena",
                     28.6071, -81.1974, rating: 4.5,
                     hours: .make(weekdays: OpenSpan((9, 0), (23, 0)), friday: OpenSpan((9, 0), (1, 0)),
                                  saturday: OpenSpan((9, 0), (1, 0)), sunday: OpenSpan((10, 0), (22, 0))),
                     usualDrop: "Bags usually drop after evening events"),
        brandKitchen(.libraryCafe, name: "Library Café", kind: .cafe, building: "John C. Hitt Library",
                     28.6004, -81.2019, rating: 4.7,
                     hours: .make(weekdays: OpenSpan((7, 30), (0, 0)), friday: OpenSpan((7, 30), (20, 0)),
                                  saturday: OpenSpan((10, 0), (20, 0)), sunday: OpenSpan((12, 0), (0, 0))),
                     usualDrop: "Bags usually drop around 5 PM"),
        kitchen("pegasus-pizza", name: "Pegasus Pizza Co.", kind: .chain, monogram: "P",
                tint: (0.93, 0.42, 0.30), ink: (0.32, 0.08, 0.04), building: "Recreation & Wellness Center",
                28.5962, -81.1980, rating: 4.4,
                hours: .make(weekdays: OpenSpan((11, 0), (23, 0)), friday: OpenSpan((11, 0), (2, 0)),
                             saturday: OpenSpan((11, 0), (2, 0)), sunday: OpenSpan((12, 0), (22, 0))),
                usualDrop: "Slices usually go into bags at 10 PM"),
        kitchen("reflecting-bowls", name: "Reflecting Pond Bowls", kind: .chain, monogram: "R",
                tint: (0.45, 0.76, 0.72), ink: (0.04, 0.27, 0.25), building: "Millican Hall · Reflecting Pond",
                28.6036, -81.2010, rating: 4.7,
                hours: .make(weekdays: OpenSpan((10, 30), (20, 0)), saturday: OpenSpan((11, 0), (16, 0)), sunday: nil),
                usualDrop: "Bags usually drop around 7:30 PM"),
        kitchen("citrus-grove", name: "Citrus Grove Café", kind: .cafe, monogram: "C",
                tint: (0.98, 0.78, 0.36), ink: (0.40, 0.22, 0.02), building: "Visual Arts Building",
                28.6037, -81.2033, rating: 4.6,
                hours: .make(weekdays: OpenSpan((7, 0), (17, 0)), saturday: nil, sunday: nil),
                usualDrop: "Bags usually drop around 4:30 PM"),
        kitchen("engineering-espresso", name: "Engineering Espresso", kind: .cafe, monogram: "E",
                tint: (0.70, 0.60, 0.90), ink: (0.20, 0.12, 0.40), building: "Engineering Atrium",
                28.6015, -81.1983, rating: 4.3,
                hours: .make(weekdays: OpenSpan((7, 0), (19, 0)), friday: OpenSpan((7, 0), (15, 0)), saturday: nil, sunday: nil),
                usualDrop: "Bags usually drop around 6:30 PM"),
        kitchen("towers-bagel", name: "Towers Bagel Co.", kind: .bakery, monogram: "T",
                tint: (0.86, 0.66, 0.46), ink: (0.33, 0.18, 0.06), building: "Towers at Knights Plaza",
                28.6086, -81.1992, rating: 4.5,
                hours: .make(weekdays: OpenSpan((6, 30), (15, 0)), saturday: OpenSpan((7, 30), (14, 0)), sunday: OpenSpan((7, 30), (14, 0))),
                usualDrop: "Bags usually drop around 2 PM"),
        kitchen("lakeside-market", name: "Lakeside Market", kind: .market, monogram: "L",
                tint: (0.48, 0.70, 0.92), ink: (0.05, 0.22, 0.40), building: "Lake Claire Community",
                28.6060, -81.2083, rating: 4.2,
                hours: .make(weekdays: OpenSpan((8, 0), (0, 0)), saturday: OpenSpan((9, 0), (0, 0)), sunday: OpenSpan((9, 0), (0, 0))),
                usualDrop: "Bags usually drop around 9 PM")
    ]

    /// Middle of UCF Main Campus, used to frame the map and as the last-resort origin.
    static let campusCenter = CLLocationCoordinate2D(latitude: 28.6024, longitude: -81.2001)
}

// MARK: - What a kitchen has right now

enum KitchenAvailability: Equatable {
    case available(Int)
    case fullyReserved
    case paused
    case closed
    case noBags

    var label: String {
        switch self {
        case .available(let count): count == 1 ? "1 bag left" : "\(count) bags"
        case .fullyReserved: "Fully reserved"
        case .paused: "Paused"
        case .closed: "No bags now"
        case .noBags: "No bags yet"
        }
    }

    /// A shape for each state so markers never rely on color alone.
    var badgeIcon: String? {
        switch self {
        case .available: nil
        case .fullyReserved: "lock.fill"
        case .paused: "pause.fill"
        case .closed: "moon.fill"
        case .noBags: nil
        }
    }

    var hasBags: Bool {
        if case .available = self { return true }
        return false
    }
}

/// A kitchen plus its live state, built fresh each time the map renders.
struct KitchenSnapshot: Identifiable {
    let kitchen: CampusKitchen
    let status: KitchenStatus
    let availability: KitchenAvailability
    /// The bag a student would open from the map (first one with bags left, else any).
    let bag: SurpriseBag?
    let hasReservation: Bool

    var id: String { kitchen.id }

    /// Where to walk: the bag's pickup spot when there is a bag, else the kitchen.
    var destination: CLLocationCoordinate2D {
        if let bag { return CLLocationCoordinate2D(latitude: bag.latitude, longitude: bag.longitude) }
        return kitchen.coordinate
    }

    var pickupDiffersFromKitchen: Bool {
        guard let bag else { return false }
        return bag.location != kitchen.building
    }
}

enum KnightMapData {
    static func snapshots(
        store: BusinessStore,
        extraReservations: [ActiveReservation],
        passToken: String,
        now: Date = Date()
    ) -> [KitchenSnapshot] {
        let reservations = store.studentReservations(passToken: passToken) + extraReservations
        let active = reservations.filter { $0.status != .verified }
        let reservedBusinesses = Set(active.map(\.bag.business))
        // Kitchen brands survive a business rename, so match on them first.
        let reservedBrands = Set(active.map(\.bag.brand))

        return CampusKitchen.campus.map { kitchen in
            let status = kitchen.hours.status(at: now)
            let isStoreKitchen = kitchen.brand == store.profile.brand
            let bags: [SurpriseBag]
            var paused = false
            if isStoreKitchen {
                bags = store.mapPins.map(\.bag)
                paused = bags.isEmpty && store.listings.contains { $0.status == .paused }
            } else {
                bags = SurpriseBag.samples.filter { $0.business == kitchen.name }
            }
            let bag = bags.first { $0.availableCount > 0 } ?? bags.first
            let left = bags.reduce(0) { $0 + $1.availableCount }

            let availability: KitchenAvailability
            if paused {
                availability = .paused
            } else if left > 0 {
                availability = .available(left)
            } else if !bags.isEmpty {
                availability = .fullyReserved
            } else if !status.isOpen {
                availability = .closed
            } else {
                availability = .noBags
            }

            return KitchenSnapshot(
                kitchen: kitchen,
                status: status,
                availability: availability,
                bag: bag,
                hasReservation: kitchen.brand.map { reservedBrands.contains($0) } ?? reservedBusinesses.contains(kitchen.name)
            )
        }
    }
}

// MARK: - Formatting

enum MapFormat {
    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    static func minutes(_ minutes: Int) -> String {
        let hour = (minutes / 60) % 24
        let minute = minutes % 60
        let suffix = hour < 12 ? "AM" : "PM"
        let twelve = hour % 12 == 0 ? 12 : hour % 12
        if hour == 0 && minute == 0 { return "Midnight" }
        return minute == 0 ? "\(twelve) \(suffix)" : String(format: "%d:%02d %@", twelve, minute, suffix)
    }

    static func span(_ span: OpenSpan?) -> String {
        guard let span else { return "Closed" }
        return "\(minutes(span.open)) – \(minutes(span.close))"
    }

    /// "Open · closes 10 PM", "Closes in 25 min", "Opens 7 AM tomorrow".
    static func status(_ status: KitchenStatus, now: Date = Date(), calendar: Calendar = .current) -> String {
        switch status {
        case .open(let until):
            let left = Int(until.timeIntervalSince(now) / 60)
            if left <= 60 { return "Open · closes in \(max(left, 1)) min" }
            return "Open · closes \(time(until))"
        case .closed(let opensAt):
            guard let opensAt else { return "Closed" }
            if calendar.isDate(opensAt, inSameDayAs: now) { return "Closed · opens \(time(opensAt))" }
            if calendar.isDateInTomorrow(opensAt) { return "Closed · opens \(time(opensAt)) tomorrow" }
            return "Closed · opens \(opensAt.formatted(.dateTime.weekday(.abbreviated))) \(time(opensAt))"
        }
    }

    static func weekday(_ weekday: Int, calendar: Calendar = .current) -> String {
        calendar.shortWeekdaySymbols[(weekday - 1) % 7]
    }

    static func distance(_ meters: CLLocationDistance) -> String {
        let miles = meters / 1_609.344
        return miles < 0.1 ? String(format: "%.0f ft", meters * 3.281) : String(format: "%.1f mi", miles)
    }

    /// Before a real route arrives: straight-line distance with a campus detour factor at
    /// an average walking pace. Always shown with "~".
    static func estimatedWalkMinutes(_ meters: CLLocationDistance) -> Int {
        max(1, Int((meters * 1.3 / 80).rounded()))
    }
}
