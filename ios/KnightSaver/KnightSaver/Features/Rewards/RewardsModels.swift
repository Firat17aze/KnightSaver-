import Foundation
import SwiftUI

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

/// What the badges are counted from: the student's staff-verified pickups. Comes from the
/// server for Supabase accounts and from the phone's own history for the local demo.
struct BadgeStats: Hashable {
    var pickups: Int
    var bags: Int
    var kitchens: Int
    var weeklyStreak: Int
    var measuredKg: Double
    var co2eKg: Double
    var hasNightPickup: Bool

    init(pickups: Int, bags: Int, kitchens: Int, weeklyStreak: Int, measuredKg: Double, co2eKg: Double, hasNightPickup: Bool) {
        self.pickups = pickups
        self.bags = bags
        self.kitchens = kitchens
        self.weeklyStreak = weeklyStreak
        self.measuredKg = measuredKg
        self.co2eKg = co2eKg
        self.hasNightPickup = hasNightPickup
    }

    init(rescues: [StudentRescue], calendar: Calendar = .current) {
        let summary = StudentImpactSummary(rescues: rescues)
        self.init(
            pickups: rescues.count,
            bags: summary.bags,
            kitchens: Set(rescues.map(\.business)).count,
            weeklyStreak: summary.weeklyStreak(),
            measuredKg: summary.measuredKg,
            co2eKg: summary.co2eKg,
            hasNightPickup: rescues.contains { calendar.component(.hour, from: $0.verifiedAt) >= RewardRules.nightOwlHour }
        )
    }
}

enum RewardRules {
    static let badgeKitchenGoal = 4
    static let badgeStreakGoal = 3
    static let badgeBagsGoal = 5
    static let badgeWeighedKgGoal = 1.0
    static let badgeCO2eKgGoal = 10.0
    /// A pickup verified at or after this hour counts for Night Owl.
    static let nightOwlHour = 20

    static func badges(_ stats: BadgeStats, isKnightOfTheWeek: Bool) -> [RewardBadge] {
        [
            RewardBadge(
                id: "first", title: "First Rescue", detail: "Your first verified pickup",
                icon: "bag.fill", current: Double(min(stats.pickups, 1)), goal: 1,
                progressText: "0 / 1 pickup"
            ),
            RewardBadge(
                id: "regular", title: "Regular", detail: "Rescue \(badgeBagsGoal) bags",
                icon: "takeoutbag.and.cup.and.straw.fill", current: Double(stats.bags), goal: Double(badgeBagsGoal),
                progressText: "\(min(stats.bags, badgeBagsGoal)) / \(badgeBagsGoal) bags"
            ),
            RewardBadge(
                id: "streak", title: "Streak Knight", detail: "Pick up \(badgeStreakGoal) weeks in a row",
                icon: "flame.fill", current: Double(stats.weeklyStreak), goal: Double(badgeStreakGoal),
                progressText: "\(min(stats.weeklyStreak, badgeStreakGoal)) / \(badgeStreakGoal) weeks"
            ),
            RewardBadge(
                id: "explorer", title: "Campus Explorer", detail: "Rescue from \(badgeKitchenGoal) kitchens",
                icon: "building.2.fill", current: Double(stats.kitchens), goal: Double(badgeKitchenGoal),
                progressText: "\(min(stats.kitchens, badgeKitchenGoal)) / \(badgeKitchenGoal) kitchens"
            ),
            RewardBadge(
                id: "weighed", title: "Weighed In", detail: "1 kg weighed at pickup",
                icon: "scalemass.fill", current: stats.measuredKg, goal: badgeWeighedKgGoal,
                progressText: String(format: "%.1f / %.0f kg", min(stats.measuredKg, badgeWeighedKgGoal), badgeWeighedKgGoal)
            ),
            RewardBadge(
                id: "night", title: "Night Owl", detail: "A pickup after 8 PM",
                icon: "moon.stars.fill", current: stats.hasNightPickup ? 1 : 0, goal: 1,
                progressText: "Not yet"
            ),
            RewardBadge(
                id: "climate", title: "Climate Knight", detail: "10 kg CO₂e avoided, est.",
                icon: "leaf.fill", current: stats.co2eKg, goal: badgeCO2eKgGoal,
                progressText: String(format: "%.1f / %.0f kg", min(stats.co2eKg, badgeCO2eKgGoal), badgeCO2eKgGoal)
            ),
            RewardBadge(
                id: "crown", title: "Knight of the Week", detail: "Top the weekly league",
                icon: "crown.fill", current: isKnightOfTheWeek ? 1 : 0, goal: 1,
                progressText: "Not yet"
            )
        ]
    }
}

/// Everything the Rewards tab shows about the student, from the server or the local demo.
struct RewardsSnapshot: Hashable {
    var stats: BadgeStats
    var cashEarnedCents: Int
    var cashSpentCents: Int
    /// Partner rewards already used at the shop, by reward id.
    var redeemed: [String: PartnerRedemption]
    var pointsThisWeek: Int
    var pointsAllTime: Int
    var leagueJoined: Bool
    var nickname: String?

    var cashBalanceCents: Int { max(cashEarnedCents - cashSpentCents, 0) }
}

/// A partner reward used at the shop: the one-time code the cashier sees, and when.
struct PartnerRedemption: Hashable {
    let code: String
    let redeemedAt: Date
}

/// One row of the Rescue League.
struct LeagueStanding: Identifiable, Hashable {
    let rank: Int
    let entry: LeagueEntry
    var id: String { entry.id }
}

/// The league for one period: the top of the board, plus the student's own row.
struct LeagueBoard: Hashable {
    var top: [LeagueStanding]
    var you: LeagueStanding?
    /// When this week's league closes and Knight of the Week is crowned.
    var weekEndsAt: Date

    var leader: LeagueStanding? { top.first }

    /// The local demo board: the sample rivals plus the student, ranked by points.
    static func demo(period: LeaguePeriod, nickname: String?, yourPoints: Int, now: Date = Date()) -> LeagueBoard {
        let entries = CampusLeague.entries(period: period, nickname: nickname, yourPoints: yourPoints)
        let ranked = entries.enumerated().map { LeagueStanding(rank: $0.offset + 1, entry: $0.element) }
        return LeagueBoard(
            top: Array(ranked.prefix(5)),
            you: ranked.first { $0.entry.isYou },
            weekEndsAt: CampusLeague.nextReset(after: now)
        )
    }
}

// MARK: - Rewards by pickups

// Every staff-verified pickup counts toward the next reward. Rewards are either Saver Cash
// (money on the account, spent with a QR at a campus partner kitchen) or a partner reward from
// a local shop off campus (a toy, a keychain, a seed kit…), used once at that shop.

/// A shop off campus that gives KnightSaver students a reward. Demo partners: the names are
/// made up for the hackathon and must be replaced by real signed partners before launch.
struct RewardPartner: Hashable {
    let id: String
    let name: String
    /// Where it is, for example "Waterford Lakes".
    let area: String
    let icon: String
    let tint: Color
    /// Icon color on the tint.
    let onTint: Color
}

/// A reward a partner shop hands over once per student.
struct PartnerReward: Identifiable, Hashable {
    let id: String
    let name: String
    /// What it is, for example "5 cm mini figure".
    let detail: String
    let icon: String
    let partner: RewardPartner

    /// "Lantern Toys · Waterford Lakes"
    var place: String { "\(partner.name) · \(partner.area)" }
}

enum RoadReward: Hashable {
    case cash(cents: Int)
    case partner(PartnerReward)
}

struct RoadMilestone: Identifiable, Hashable {
    /// Verified pickups needed to reach this step.
    let orders: Int
    let reward: RoadReward
    var id: Int { orders }

    var title: String {
        switch reward {
        case .cash(let cents): "+\(SaverCash.format(cents)) Saver Cash"
        case .partner(let reward): reward.name
        }
    }

    var icon: String {
        switch reward {
        case .cash: "dollarsign"
        case .partner(let reward): reward.icon
        }
    }

    var partnerReward: PartnerReward? {
        if case .partner(let reward) = reward { return reward }
        return nil
    }
}

enum SaverCash {
    static func format(_ cents: Int, compact: Bool = false) -> String {
        if compact && cents % 100 == 0 { return "$\(cents / 100)" }
        return String(format: "$%d.%02d", cents / 100, cents % 100)
    }
}

enum RewardRoad {
    // Demo partners off campus. Mirrors reward_partners in the rewards migration.
    static let toyShop = RewardPartner(
        id: "lantern-toys", name: "Lantern Toys", area: "Waterford Lakes",
        icon: "teddybear.fill", tint: KnightTheme.gold, onTint: KnightTheme.onAccent
    )
    static let bookShop = RewardPartner(
        id: "paper-owl-books", name: "Paper Owl Books", area: "University Blvd",
        icon: "book.fill", tint: KnightTheme.lakeFill, onTint: .white
    )
    static let gardenShop = RewardPartner(
        id: "sprout-and-soil", name: "Sprout & Soil", area: "Oviedo",
        icon: "leaf.fill", tint: KnightTheme.fern, onTint: .white
    )
    static let bikeShop = RewardPartner(
        id: "spoke-line-bikes", name: "Spoke Line Bikes", area: "Alafaya Trail",
        icon: "bicycle", tint: KnightTheme.citrus, onTint: .white
    )

    static let miniToy = PartnerReward(
        id: "mini-toy", name: "Mystery mini toy", detail: "A surprise mini figure from the capsule shelf",
        icon: "gift.fill", partner: toyShop
    )
    static let bookmark = PartnerReward(
        id: "bookworm-keychain", name: "Bookworm keychain", detail: "Soft enamel keychain",
        icon: "book.fill", partner: bookShop
    )
    static let seedKit = PartnerReward(
        id: "herb-seed-kit", name: "Herb seed kit", detail: "Basil and mint seeds with a recycled pot",
        icon: "leaf.fill", partner: gardenShop
    )
    static let tuneUp = PartnerReward(
        id: "bike-tune-up", name: "Free bike tune-up", detail: "Brakes, gears and tires checked",
        icon: "bicycle", partner: bikeShop
    )
    static let goldenKnight = PartnerReward(
        id: "golden-knight", name: "Golden Knight plush", detail: "Rare 12 cm plush",
        icon: "shield.lefthalf.filled", partner: toyShop
    )

    static let partnerRewards = [miniToy, bookmark, seedKit, tuneUp, goldenKnight]

    static let milestones: [RoadMilestone] = [
        RoadMilestone(orders: 1, reward: .cash(cents: 100)),
        RoadMilestone(orders: 3, reward: .cash(cents: 200)),
        RoadMilestone(orders: 5, reward: .partner(miniToy)),
        RoadMilestone(orders: 8, reward: .cash(cents: 300)),
        RoadMilestone(orders: 10, reward: .partner(bookmark)),
        RoadMilestone(orders: 12, reward: .cash(cents: 400)),
        RoadMilestone(orders: 15, reward: .partner(seedKit)),
        RoadMilestone(orders: 18, reward: .cash(cents: 500)),
        RoadMilestone(orders: 20, reward: .partner(tuneUp)),
        RoadMilestone(orders: 25, reward: .cash(cents: 800)),
        RoadMilestone(orders: 30, reward: .partner(goldenKnight))
    ]

    /// Saver Cash added to the account so far.
    static func cashEarnedCents(orders: Int) -> Int {
        milestones.reduce(0) { total, step in
            if case .cash(let cents) = step.reward, step.orders <= orders { return total + cents }
            return total
        }
    }

    static func next(after orders: Int) -> RoadMilestone? {
        milestones.first { $0.orders > orders }
    }

    /// Pickups at the last step reached, or 0 before the first one.
    static func lastReachedOrders(_ orders: Int) -> Int {
        milestones.last { $0.orders <= orders }?.orders ?? 0
    }

    /// Progress from the last step reached to the next one.
    static func progressToNext(orders: Int) -> Double {
        guard let next = next(after: orders) else { return 1 }
        let start = lastReachedOrders(orders)
        return Double(orders - start) / Double(max(next.orders - start, 1))
    }

    static func unlockOrders(for reward: PartnerReward) -> Int {
        milestones.first { $0.partnerReward?.id == reward.id }?.orders ?? 0
    }
}
