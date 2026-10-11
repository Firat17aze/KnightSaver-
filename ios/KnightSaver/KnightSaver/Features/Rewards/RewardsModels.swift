import Foundation

// Rewards tab: badges a student earns from staff-verified pickups only (student.md
// "Verified Impact Chain"). Cancelled, missed or unverified pickups never count.

struct RewardBadge: Identifiable, Hashable {
    let id: String
    let title: String
    /// How to earn it, in one short line.
    let detail: String
    let icon: String
    /// Progress toward the goal, for example 3 of 5.
    let current: Double
    let goal: Double
    /// Shown under a locked badge, for example "3 / 5 bags".
    let progressText: String

    var isEarned: Bool { current >= goal }
    var progress: Double { goal > 0 ? min(current / goal, 1) : 0 }
}

enum RewardRules {
    static let badgeKitchenGoal = 4
    static let badgeStreakGoal = 3
    static let badgeBagsGoal = 5
    static let badgeWeighedKgGoal = 1.0
    static let badgeCO2eKgGoal = 10.0
    /// A pickup verified at or after this hour counts for Night Owl.
    static let nightOwlHour = 20

    static func badges(
        rescues: [StudentRescue],
        summary: StudentImpactSummary,
        wonKnightOfTheWeek: Bool = false,
        calendar: Calendar = .current
    ) -> [RewardBadge] {
        let kitchens = Set(rescues.map(\.business)).count
        let streak = summary.weeklyStreak()
        let nightOwl = rescues.contains { calendar.component(.hour, from: $0.verifiedAt) >= nightOwlHour }

        return [
            RewardBadge(
                id: "first", title: "First Rescue", detail: "Your first verified pickup",
                icon: "bag.fill", current: Double(min(rescues.count, 1)), goal: 1,
                progressText: "0 / 1 pickup"
            ),
            RewardBadge(
                id: "regular", title: "Regular", detail: "Rescue \(badgeBagsGoal) bags",
                icon: "takeoutbag.and.cup.and.straw.fill", current: Double(summary.bags), goal: Double(badgeBagsGoal),
                progressText: "\(min(summary.bags, badgeBagsGoal)) / \(badgeBagsGoal) bags"
            ),
            RewardBadge(
                id: "streak", title: "Streak Knight", detail: "\(badgeStreakGoal) weeks in a row",
                icon: "flame.fill", current: Double(streak), goal: Double(badgeStreakGoal),
                progressText: "\(min(streak, badgeStreakGoal)) / \(badgeStreakGoal) weeks"
            ),
            RewardBadge(
                id: "explorer", title: "Campus Explorer", detail: "Rescue from \(badgeKitchenGoal) kitchens",
                icon: "building.2.fill", current: Double(kitchens), goal: Double(badgeKitchenGoal),
                progressText: "\(min(kitchens, badgeKitchenGoal)) / \(badgeKitchenGoal) kitchens"
            ),
            RewardBadge(
                id: "weighed", title: "Weighed In", detail: "1 kg weighed at pickup",
                icon: "scalemass.fill", current: summary.measuredKg, goal: badgeWeighedKgGoal,
                progressText: String(format: "%.1f / %.0f kg", min(summary.measuredKg, badgeWeighedKgGoal), badgeWeighedKgGoal)
            ),
            RewardBadge(
                id: "night", title: "Night Owl", detail: "A pickup after 8 PM",
                icon: "moon.stars.fill", current: nightOwl ? 1 : 0, goal: 1,
                progressText: "After 8 PM"
            ),
            RewardBadge(
                id: "climate", title: "Climate Knight", detail: "10 kg CO₂e avoided, est.",
                icon: "leaf.fill", current: summary.co2eKg, goal: badgeCO2eKgGoal,
                progressText: String(format: "%.1f / %.0f kg", min(summary.co2eKg, badgeCO2eKgGoal), badgeCO2eKgGoal)
            ),
            RewardBadge(
                id: "crown", title: "Knight of the Week", detail: "Top the weekly league",
                icon: "crown.fill", current: wonKnightOfTheWeek ? 1 : 0, goal: 1,
                progressText: "Top the league"
            )
        ]
    }
}

// MARK: - Reward Road

// Every staff-verified order moves the student one step along the Reward Road.
// Steps pay out Knight Cash (money on the account, paid with a QR at the counter)
// or unlock a small Rescue Crew toy that waits at a partner kitchen.

/// A small toy kept behind the counter at one partner kitchen.
struct Collectible: Identifiable, Hashable {
    let id: String
    let name: String
    /// What it is, for example "5 cm mini figure".
    let detail: String
    let icon: String
    /// Where to pick it up. Nil means any partner kitchen.
    let brand: BagBrand?
    let store: String

    /// "Campus Bakery", or "any partner kitchen" mid-sentence.
    var pickupPlace: String { brand == nil ? "any partner kitchen" : store }
}

enum RoadReward: Hashable {
    case cash(cents: Int)
    case collectible(Collectible)
}

struct RoadMilestone: Identifiable, Hashable {
    /// Verified orders needed to reach this step.
    let orders: Int
    let reward: RoadReward
    var id: Int { orders }

    var title: String {
        switch reward {
        case .cash(let cents): "+\(KnightCash.format(cents)) Knight Cash"
        case .collectible(let toy): toy.name
        }
    }

    var shortTitle: String {
        switch reward {
        case .cash(let cents): KnightCash.format(cents, compact: true)
        case .collectible(let toy): toy.name.split(separator: " ").last.map(String.init) ?? toy.name
        }
    }

    var icon: String {
        switch reward {
        case .cash: "dollarsign"
        case .collectible(let toy): toy.icon
        }
    }

    var collectible: Collectible? {
        if case .collectible(let toy) = reward { return toy }
        return nil
    }
}

enum KnightCash {
    static func format(_ cents: Int, compact: Bool = false) -> String {
        if compact && cents % 100 == 0 { return "$\(cents / 100)" }
        return String(format: "$%d.%02d", cents / 100, cents % 100)
    }
}

/// Student tier from verified orders, shown on the wallet.
enum KnightTier: String {
    case squire = "Squire"
    case knight = "Knight"
    case champion = "Champion"
    case legend = "Legend"

    init(orders: Int) {
        switch orders {
        case ..<5: self = .squire
        case ..<15: self = .knight
        case ..<30: self = .champion
        default: self = .legend
        }
    }
}

enum RewardRoad {
    /// The Rescue Crew: one toy per partner kitchen, plus a mystery capsule.
    static let capsule = Collectible(
        id: "capsule", name: "Mystery Capsule", detail: "A surprise mini toy from the capsule machine",
        icon: "capsule.fill", brand: nil, store: "Any partner kitchen"
    )
    static let cupcake = Collectible(
        id: "cupcake", name: "Cupcake Squire", detail: "5 cm mini figure",
        icon: "birthday.cake.fill", brand: .campusBakery, store: "Campus Bakery"
    )
    static let bookworm = Collectible(
        id: "bookworm", name: "Bookworm Keychain", detail: "Soft enamel keychain",
        icon: "book.fill", brand: .libraryCafe, store: "Library Café"
    )
    static let carrot = Collectible(
        id: "carrot", name: "Carrot Cavalier", detail: "Squishy stress toy",
        icon: "carrot.fill", brand: .arenaMarket, store: "Arena Market"
    )
    static let goldenKnight = Collectible(
        id: "golden", name: "Golden Knight", detail: "Rare 12 cm plush",
        icon: "shield.lefthalf.filled", brand: .knightros, store: "Knightro's Kitchen"
    )

    static let crew = [capsule, cupcake, bookworm, carrot, goldenKnight]

    static let milestones: [RoadMilestone] = [
        RoadMilestone(orders: 1, reward: .cash(cents: 100)),
        RoadMilestone(orders: 3, reward: .cash(cents: 200)),
        RoadMilestone(orders: 5, reward: .collectible(capsule)),
        RoadMilestone(orders: 8, reward: .cash(cents: 300)),
        RoadMilestone(orders: 10, reward: .collectible(cupcake)),
        RoadMilestone(orders: 12, reward: .cash(cents: 400)),
        RoadMilestone(orders: 15, reward: .collectible(bookworm)),
        RoadMilestone(orders: 18, reward: .cash(cents: 500)),
        RoadMilestone(orders: 20, reward: .collectible(carrot)),
        RoadMilestone(orders: 25, reward: .cash(cents: 800)),
        RoadMilestone(orders: 30, reward: .collectible(goldenKnight))
    ]

    /// Knight Cash added to the account so far.
    static func cashEarnedCents(orders: Int) -> Int {
        milestones.reduce(0) { total, step in
            if case .cash(let cents) = step.reward, step.orders <= orders { return total + cents }
            return total
        }
    }

    static func next(after orders: Int) -> RoadMilestone? {
        milestones.first { $0.orders > orders }
    }

    /// Orders at the last step reached, or 0 before the first one.
    static func lastReachedOrders(_ orders: Int) -> Int {
        milestones.last { $0.orders <= orders }?.orders ?? 0
    }

    /// Progress from the last step reached to the next one.
    static func progressToNext(orders: Int) -> Double {
        guard let next = next(after: orders) else { return 1 }
        let start = lastReachedOrders(orders)
        return Double(orders - start) / Double(max(next.orders - start, 1))
    }

    static func unlockOrders(for toy: Collectible) -> Int {
        milestones.first { $0.collectible?.id == toy.id }?.orders ?? 0
    }
}
