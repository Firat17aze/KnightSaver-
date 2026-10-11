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

/// Where the student stands in the league and who to catch next.
struct LeagueStanding {
    let rank: Int?
    let points: Int
    let total: Int
    /// The next student above, when there is one.
    let target: LeagueEntry?
    let targetRank: Int?

    init(entries: [LeagueEntry]) {
        total = entries.count
        if let index = entries.firstIndex(where: \.isYou) {
            rank = index + 1
            points = entries[index].points
            // The closest entry with more points (ties share a score, so skip them).
            if let above = entries[..<index].lastIndex(where: { $0.points > entries[index].points }) {
                target = entries[above]
                targetRank = above + 1
            } else {
                target = nil
                targetRank = nil
            }
        } else {
            rank = nil
            points = 0
            target = nil
            targetRank = nil
        }
    }

    var pointsToPass: Int? {
        guard let target else { return nil }
        return target.points - points + 1
    }
}
