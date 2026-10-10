import SwiftUI

// MARK: - Rules (student.md "Impact")

enum ImpactRules {
    /// Rough food weight per Surprise Bag when staff didn't weigh it. Always labeled "Est.".
    static let estimatedKgPerBag = BusinessRules.estimatedKgPerItem * Double(BusinessRules.targetItemsPerBag)
    /// Same factor the Kitchen report uses.
    static let co2ePerFoodKg = BusinessRules.estimatedCO2eKgPerFoodKg
    /// Campus Rescue League: one verified rescue per student per day earns a point.
    static let maxPointsPerDay = 1
}

// MARK: - A verified rescue, as the student sees it

struct StudentRescue: Identifiable, Hashable {
    let id: UUID
    let reservationCode: String
    let business: String
    let brand: BagBrand
    let location: String
    let verifiedAt: Date
    let bags: Int
    /// Only when staff weighed the bag at pickup.
    let measuredKg: Double?
    /// From the sample history, not from the live Kitchen store.
    let isDemoHistory: Bool

    var estimatedKg: Double { measuredKg == nil ? Double(bags) * ImpactRules.estimatedKgPerBag : 0 }
    var foodKg: Double { measuredKg ?? estimatedKg }
}

struct StudentImpactSummary {
    let rescues: [StudentRescue]

    var bags: Int { rescues.reduce(0) { $0 + $1.bags } }
    var measuredKg: Double { rescues.compactMap(\.measuredKg).reduce(0, +) }
    var estimatedKg: Double { rescues.map(\.estimatedKg).reduce(0, +) }
    var foodKg: Double { measuredKg + estimatedKg }
    var co2eKg: Double { foodKg * ImpactRules.co2ePerFoodKg }

    /// Verified rescues per calendar week, oldest first, for the last `weeks` weeks.
    func weeklyBags(weeks: Int, now: Date = Date(), calendar: Calendar = .current) -> [Int] {
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }
        return (0..<weeks).reversed().map { back in
            let start = calendar.date(byAdding: .weekOfYear, value: -back, to: thisWeek) ?? thisWeek
            let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) ?? start
            return rescues.filter { $0.verifiedAt >= start && $0.verifiedAt < end }.reduce(0) { $0 + $1.bags }
        }
    }

    /// Consecutive weeks with at least one verified rescue. A week that hasn't had one yet
    /// doesn't break the streak until it ends.
    func weeklyStreak(now: Date = Date(), calendar: Calendar = .current) -> Int {
        let counts = weeklyBags(weeks: 52, now: now, calendar: calendar)
        var streak = 0
        for (offset, count) in counts.reversed().enumerated() {
            if count > 0 {
                streak += 1
            } else if offset == 0 {
                continue
            } else {
                break
            }
        }
        return streak
    }

    /// League points this week: distinct days with a verified rescue.
    func pointsThisWeek(now: Date = Date(), calendar: Calendar = .current) -> Int {
        guard let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return 0 }
        let days = Set(rescues.filter { $0.verifiedAt >= start }.map { calendar.startOfDay(for: $0.verifiedAt) })
        return days.count * ImpactRules.maxPointsPerDay
    }

    var pointsAllTime: Int {
        Set(rescues.map { Calendar.current.startOfDay(for: $0.verifiedAt) }).count * ImpactRules.maxPointsPerDay
    }
}

// MARK: - Live data from the shared store

extension BusinessStore {
    /// This student's staff-verified pickups from the Kitchen tab. Cancelled, missed and
    /// unverified reservations never count.
    func verifiedRescues(passToken: String) -> [StudentRescue] {
        reservations
            .filter { $0.passToken == passToken && $0.isVerified }
            .compactMap { reservation in
                guard let listing = listing(id: reservation.listingID) else { return nil }
                return StudentRescue(
                    id: reservation.id,
                    reservationCode: reservation.code,
                    business: profile.name,
                    brand: profile.brand,
                    location: listing.pickupAddress,
                    verifiedAt: reservation.verifiedAt ?? reservation.pickupEnd,
                    bags: reservation.quantity,
                    measuredKg: reservation.measuredWeightKg,
                    isDemoHistory: false
                )
            }
    }

    func hasFeedback(reservationCode: String) -> Bool {
        feedback.contains { $0.reservationCode == reservationCode }
    }
}

// MARK: - Demo data (clearly labeled in the UI)

enum ImpactDemo {
    /// Built once per launch so the rows keep stable identities.
    static let sampleHistory: [StudentRescue] = history()

    /// Earlier verified pickups for the demo student, so the page has a history to show.
    static func history(now: Date = Date()) -> [StudentRescue] {
        func daysAgo(_ days: Int, hour: Int) -> Date {
            let day = Calendar.current.date(byAdding: .day, value: -days, to: now) ?? now
            return Calendar.current.date(bySettingHour: hour, minute: 20, second: 0, of: day) ?? day
        }
        let samples: [(Int, Int, String, BagBrand, String, Int, Double?)] = [
            (2, 18, "Campus Bakery", .campusBakery, "Memory Mall", 1, 0.55),
            (5, 17, "Library Café", .libraryCafe, "John C. Hitt Library", 1, nil),
            (9, 19, "Knightro's Kitchen", .knightros, "Student Union · Level 1", 1, 0.48),
            (15, 20, "Arena Market", .arenaMarket, "Addition Financial Arena", 2, nil),
            (23, 18, "Campus Bakery", .campusBakery, "Memory Mall", 1, nil),
            (30, 19, "Knightro's Kitchen", .knightros, "Student Union · Level 1", 1, nil)
        ]
        return samples.enumerated().map { index, sample in
            StudentRescue(
                id: UUID(),
                reservationCode: "KS-H\(100 + index)",
                business: sample.2,
                brand: sample.3,
                location: sample.4,
                verifiedAt: daysAgo(sample.0, hour: sample.1),
                bags: sample.5,
                measuredKg: sample.6,
                isDemoHistory: true
            )
        }
    }

    struct Campus {
        let bagsThisWeek: Int
        let weeklyGoal: Int
        let bagsAllTime: Int
        let measuredKg: Double
        let estimatedKg: Double
        let residenceHalls: Int
        let studentOrgs: Int

        var co2eKg: Double { (measuredKg + estimatedKg) * ImpactRules.co2ePerFoodKg }
    }

    /// Campus totals before this student's own rescues are added.
    static let campusBase = Campus(
        bagsThisWeek: 412,
        weeklyGoal: 600,
        bagsAllTime: 8_940,
        measuredKg: 1_210,
        estimatedKg: 2_860,
        residenceHalls: 14,
        studentOrgs: 37
    )

    static let weeklyStudents: [(String, Int)] = [
        ("BagelBaron", 6), ("SirScraps", 5), ("MossKnight", 5), ("LadyLeftover", 4),
        ("Gr8Rescuer", 4), ("CroissantQuest", 3), ("NightOwlNom", 2)
    ]
    static let allTimeStudents: [(String, Int)] = [
        ("SirScraps", 61), ("BagelBaron", 57), ("LadyLeftover", 49), ("MossKnight", 44),
        ("Gr8Rescuer", 38), ("CroissantQuest", 31), ("NightOwlNom", 22)
    ]
    static let weeklyHalls: [(String, Int)] = [
        ("Libra Community", 64), ("Nike Community", 58), ("Hercules Community", 51),
        ("Towers at Knights Plaza", 47), ("Lake Claire", 33)
    ]
    static let allTimeHalls: [(String, Int)] = [
        ("Nike Community", 1_204), ("Libra Community", 1_177), ("Towers at Knights Plaza", 1_032),
        ("Hercules Community", 968), ("Lake Claire", 611)
    ]
    static let weeklyOrgs: [(String, Int)] = [
        ("Sustainability Knights", 41), ("Hospitality Society", 36), ("Engineering Council", 29),
        ("Pre-Health Club", 24), ("Esports Knights", 17)
    ]
    static let allTimeOrgs: [(String, Int)] = [
        ("Sustainability Knights", 702), ("Hospitality Society", 655), ("Engineering Council", 498),
        ("Pre-Health Club", 377), ("Esports Knights", 260)
    ]

    /// The student's demo residence hall and org, so their points show up in those boards.
    static let studentHall = "Libra Community"
    static let studentOrg = "Sustainability Knights"
    static let weeklySponsor = "Knightro's Kitchen"
}

// MARK: - Campus Rescue League

enum LeagueBoard: String, CaseIterable, Identifiable {
    case students = "Students"
    case halls = "Halls"
    case orgs = "Orgs"
    var id: String { rawValue }
}

enum LeaguePeriod: String, CaseIterable, Identifiable {
    case week = "This week"
    case allTime = "All time"
    var id: String { rawValue }
}

struct LeagueEntry: Identifiable, Hashable {
    let name: String
    let points: Int
    let isYou: Bool
    var id: String { name }
}

enum CampusLeague {
    static func entries(
        board: LeagueBoard,
        period: LeaguePeriod,
        nickname: String?,
        yourPoints: Int
    ) -> [LeagueEntry] {
        let base: [(String, Int)]
        switch (board, period) {
        case (.students, .week): base = ImpactDemo.weeklyStudents
        case (.students, .allTime): base = ImpactDemo.allTimeStudents
        case (.halls, .week): base = ImpactDemo.weeklyHalls
        case (.halls, .allTime): base = ImpactDemo.allTimeHalls
        case (.orgs, .week): base = ImpactDemo.weeklyOrgs
        case (.orgs, .allTime): base = ImpactDemo.allTimeOrgs
        }

        var entries: [LeagueEntry]
        switch board {
        case .students:
            entries = base.map { LeagueEntry(name: $0.0, points: $0.1, isYou: false) }
            if let nickname, !nickname.isEmpty {
                entries.append(LeagueEntry(name: nickname, points: yourPoints, isYou: true))
            }
        case .halls, .orgs:
            let yours = board == .halls ? ImpactDemo.studentHall : ImpactDemo.studentOrg
            entries = base.map { name, points in
                // Your verified points also count for your hall and org.
                LeagueEntry(name: name, points: points + (name == yours && nickname != nil ? yourPoints : 0), isYou: name == yours)
            }
        }
        return entries.sorted { $0.points == $1.points ? $0.isYou && !$1.isYou : $0.points > $1.points }
    }

    /// Start of next week: when the league resets and Knight of the Week is crowned.
    static func nextReset(after now: Date = Date(), calendar: Calendar = .current) -> Date {
        let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        return calendar.date(byAdding: .weekOfYear, value: 1, to: start) ?? now
    }
}

// MARK: - Formatting

enum ImpactFormat {
    static func kg(_ value: Double) -> String {
        value >= 100 ? String(format: "%.0f kg", value) : String(format: "%.1f kg", value)
    }

    static func shortDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    static func countdown(to date: Date, now: Date = Date()) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(now)))
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        if days > 0 { return "\(days)d \(hours)h" }
        let minutes = (seconds % 3_600) / 60
        return "\(hours)h \(minutes)m"
    }
}
