import SwiftUI

/// The Rewards tab: where the student stands, Knight of the Week, the Campus Rescue League
/// and badges. Everything here counts staff-verified pickups only.
struct RewardsView: View {
    let student: KnightPass

    @EnvironmentObject var businessStore: BusinessStore
    @AppStorage("knightsaver.league.joined") private var leagueJoined = true
    @AppStorage("knightsaver.league.nickname") private var storedNickname = ""
    @State private var period: LeaguePeriod = .week
    @State private var showSettings = false
    @State private var selectedBadge: RewardBadge?

    private var isDemoStudent: Bool { student.verificationToken == KnightPass.sample.verificationToken }

    /// Newest first. Live Kitchen verifications plus the demo history for the demo student.
    private var rescues: [StudentRescue] {
        let live = businessStore.verifiedRescues(passToken: student.verificationToken)
        let history = isDemoStudent ? ImpactDemo.sampleHistory : []
        return (live + history).sorted { $0.verifiedAt > $1.verifiedAt }
    }

    private var nickname: String {
        if !storedNickname.isEmpty { return storedNickname }
        let first = student.displayName.split(separator: " ").first.map(String.init) ?? "Knight"
        return "Sir \(first)"
    }

    var body: some View {
        let allRescues = rescues
        let summary = StudentImpactSummary(rescues: allRescues)
        let weekEntries = CampusLeague.entries(period: .week, nickname: leagueJoined ? nickname : nil, yourPoints: summary.pointsThisWeek())
        let badges = RewardRules.badges(rescues: allRescues, summary: summary)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 14) {
                        KnightSaverBrandBar()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Rewards")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(KnightTheme.ink)
                                .accessibilityAddTraits(.isHeader)
                            Text("Rescue food, climb the league, earn badges.")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(KnightTheme.muted)
                        }
                    }

                    StandingCard(
                        standing: LeagueStanding(entries: weekEntries),
                        nickname: leagueJoined ? nickname : nil,
                        streak: summary.weeklyStreak(),
                        earnedBadges: badges.filter(\.isEarned).count,
                        totalBadges: badges.count,
                        onJoin: { showSettings = true }
                    )

                    KnightOfTheWeekCard(podium: Array(weekEntries.prefix(3)))

                    leagueSection(summary: summary)

                    badgeSection(badges)
                }
                .padding(.horizontal, KnightTheme.screenPadding)
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .reservesTabBarSpace()
            .background(KnightTheme.paper)
            .navigationBarHidden(true)
            .sheet(isPresented: $showSettings) {
                LeagueSettingsView(joined: $leagueJoined, nickname: $storedNickname, suggested: nickname)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $selectedBadge) { badge in
                BadgeDetailView(badge: badge)
                    .presentationDetents([.height(320)])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: League

    private func leagueSection(summary: StudentImpactSummary) -> some View {
        let yourPoints = period == .week ? summary.pointsThisWeek() : summary.pointsAllTime
        let entries = CampusLeague.entries(period: period, nickname: leagueJoined ? nickname : nil, yourPoints: yourPoints)
        let top = Array(entries.prefix(5))
        let you = entries.enumerated().first { $0.element.isYou }

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 4) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Rescue League")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(KnightTheme.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text("1 point a day you rescue")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(KnightTheme.muted)
                }
                Spacer(minLength: 8)
                Menu {
                    Picker("Period", selection: $period) {
                        ForEach(LeaguePeriod.allCases) { Text($0.rawValue).tag($0) }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(period.rawValue)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(KnightTheme.ink)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 34)
                    .background(KnightTheme.surface, in: Capsule())
                    .overlay { Capsule().stroke(KnightTheme.line, lineWidth: 1) }
                }
                .accessibilityLabel("Period, \(period.rawValue)")
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(KnightTheme.ink)
                        .frame(width: 40, height: 44)
                }
                .accessibilityLabel("League settings")
            }

            VStack(spacing: 0) {
                ForEach(Array(top.enumerated()), id: \.element.id) { index, entry in
                    LeagueRow(rank: index + 1, entry: entry)
                    if index < top.count - 1 { Divider().overlay(KnightTheme.line).padding(.leading, 52) }
                }
                if let you, you.offset >= 5 {
                    Divider().overlay(KnightTheme.line)
                    LeagueRow(rank: you.offset + 1, entry: you.element)
                }
            }
            .rewardsListCard()

            Text("Joining is optional and shows only your nickname. Cancelled, missed or unverified pickups earn nothing.")
                .font(.system(size: 12))
                .foregroundStyle(KnightTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Badges

    private func badgeSection(_ badges: [RewardBadge]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Badges")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(KnightTheme.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("\(badges.filter(\.isEarned).count) of \(badges.count)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(KnightTheme.muted)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 16) {
                ForEach(badges) { badge in
                    Button {
                        selectedBadge = badge
                    } label: {
                        BadgeTile(badge: badge)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 6)
        }
    }
}

private extension View {
    func rewardsListCard() -> some View {
        background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(KnightTheme.ink.opacity(0.06), lineWidth: 1)
            }
    }
}

// MARK: - Your standing

private struct StandingCard: View {
    let standing: LeagueStanding
    let nickname: String?
    let streak: Int
    let earnedBadges: Int
    let totalBadges: Int
    let onJoin: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                // Rank medallion: gold ring, rank inside.
                ZStack {
                    Circle()
                        .stroke(KnightTheme.gold, lineWidth: 5)
                    VStack(spacing: -2) {
                        Text(standing.rank.map { "#\($0)" } ?? "–")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(KnightTheme.ink)
                        Text("this week")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(KnightTheme.muted)
                    }
                }
                .frame(width: 84, height: 84)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(standing.rank.map { "Rank \($0) of \(standing.total) this week" } ?? "Not in the league")

                VStack(alignment: .leading, spacing: 6) {
                    Text(nickname ?? "Not in the league")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(KnightTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("\(standing.points) pt\(standing.points == 1 ? "" : "s") this week")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(KnightTheme.muted)
                    HStack(spacing: 6) {
                        if streak > 0 {
                            pill("\(streak)-week streak", icon: "flame.fill", tint: KnightTheme.citrus)
                        }
                        pill("\(earnedBadges)/\(totalBadges) badges", icon: "seal.fill", tint: KnightTheme.goldDeep)
                    }
                }
                Spacer(minLength: 0)
            }

            if nickname == nil {
                Button(action: onJoin) {
                    Label("Join the league with a nickname", systemImage: "person.badge.plus")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(KnightTheme.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(KnightTheme.gold, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            } else if let target = standing.target, let toPass = standing.pointsToPass, let targetRank = standing.targetRank {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(toPass) pt\(toPass == 1 ? "" : "s") to pass \(target.name)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(KnightTheme.ink)
                        Spacer()
                        Text("#\(targetRank)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(KnightTheme.muted)
                    }
                    BizProgressBar(progress: Double(standing.points) / Double(max(target.points + 1, 1)), tint: KnightTheme.green, height: 8)
                    Text("Rescue on a new day to earn your next point.")
                        .font(.system(size: 12))
                        .foregroundStyle(KnightTheme.muted)
                }
            } else if standing.rank == 1 {
                Label("You're leading the week. Hold on until the reset.", systemImage: "crown.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(KnightTheme.goldDeep)
            }
        }
        .bizCard()
    }

    private func pill(_ text: String, icon: String, tint: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .frame(minHeight: 24)
            .background(tint.opacity(0.12), in: Capsule())
            .lineLimit(1)
    }
}

// MARK: - Knight of the Week

/// Dark card with the week's podium: first place in the middle, raised and crowned.
private struct KnightOfTheWeekCard: View {
    let podium: [LeagueEntry]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("KNIGHT OF THE WEEK", systemImage: "crown.fill")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(KnightTheme.gold)
                    Spacer()
                    Text("Ends in \(ImpactFormat.countdown(to: CampusLeague.nextReset(after: context.date), now: context.date))")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.75))
                }

                HStack(alignment: .bottom, spacing: 10) {
                    ForEach([1, 0, 2], id: \.self) { index in
                        if index < podium.count {
                            PodiumStep(place: index + 1, entry: podium[index])
                        } else {
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                }
                .frame(height: 150, alignment: .bottom)

                Label("Prize: a free Surprise Bag from \(ImpactDemo.weeklySponsor)", systemImage: "gift.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(17)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KnightTheme.night, in: RoundedRectangle(cornerRadius: KnightTheme.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: KnightTheme.cardRadius, style: .continuous)
                    .stroke(KnightTheme.line, lineWidth: 1)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

private struct PodiumStep: View {
    let place: Int
    let entry: LeagueEntry

    private var color: Color {
        switch place {
        case 1: KnightTheme.gold
        case 2: KnightTheme.silver
        default: KnightTheme.bronze
        }
    }

    private var height: CGFloat {
        switch place {
        case 1: 74
        case 2: 52
        default: 38
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            if place == 1 {
                Image(systemName: "crown.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(KnightTheme.gold)
            }
            Text(entry.isYou ? "\(entry.name) (you)" : entry.name)
                .font(.system(size: place == 1 ? 14 : 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("\(entry.points) pt\(entry.points == 1 ? "" : "s")")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
            Text("\(place)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(KnightTheme.onAccent)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(color, in: UnevenRoundedRectangle(topLeadingRadius: 10, topTrailingRadius: 10, style: .continuous))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Place \(place), \(entry.name), \(entry.points) points")
    }
}

// MARK: - League rows and settings

private struct LeagueRow: View {
    let rank: Int
    let entry: LeagueEntry

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(rank <= 3 ? KnightTheme.onAccent : KnightTheme.muted)
                .frame(width: 28, height: 28)
                .background(podium, in: Circle())
            Text(entry.name)
                .font(.system(size: 15, weight: entry.isYou ? .bold : .medium))
                .foregroundStyle(KnightTheme.ink)
                .lineLimit(1)
            if entry.isYou {
                Text("You")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(KnightTheme.green)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(KnightTheme.green.opacity(0.12), in: Capsule())
            }
            Spacer(minLength: 8)
            Text("\(entry.points.formatted()) pts")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(KnightTheme.ink)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 52)
        .background(entry.isYou ? KnightTheme.green.opacity(0.08) : Color.clear)
        .accessibilityElement(children: .combine)
    }

    /// Gold, silver and bronze for the top three.
    private var podium: Color {
        switch rank {
        case 1: KnightTheme.gold
        case 2: KnightTheme.silver
        case 3: KnightTheme.bronze
        default: .clear
        }
    }
}

private struct LeagueSettingsView: View {
    @Binding var joined: Bool
    @Binding var nickname: String
    let suggested: String
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Show me in the league", isOn: $joined)
                        .tint(KnightTheme.green)
                    if joined {
                        TextField("Nickname", text: $draft)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                    }
                } footer: {
                    Text("Only your nickname is shown, never your real name.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(KnightTheme.paper)
            .navigationTitle("League settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                        nickname = String(trimmed.prefix(20))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear { draft = nickname.isEmpty ? suggested : nickname }
        }
    }
}

// MARK: - Badges

private struct BadgeTile: View {
    let badge: RewardBadge

    var body: some View {
        VStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(badge.isEarned ? KnightTheme.gold : KnightTheme.wash)
                if !badge.isEarned {
                    // Progress ring around a locked badge.
                    Circle()
                        .trim(from: 0, to: badge.progress)
                        .stroke(KnightTheme.green, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(1.5)
                }
                Image(systemName: badge.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(badge.isEarned ? KnightTheme.onAccent : KnightTheme.muted)
            }
            .frame(width: 58, height: 58)
            .overlay(alignment: .bottomTrailing) {
                if !badge.isEarned {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(KnightTheme.muted)
                        .frame(width: 20, height: 20)
                        .background(KnightTheme.surface, in: Circle())
                        .overlay { Circle().stroke(KnightTheme.line, lineWidth: 1) }
                }
            }

            Text(badge.title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(badge.isEarned ? KnightTheme.ink : KnightTheme.muted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 28, alignment: .top)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(badge.title), \(badge.isEarned ? "earned" : "locked, \(badge.progressText)")")
        .accessibilityHint(badge.detail)
    }
}

private struct BadgeDetailView: View {
    let badge: RewardBadge

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(badge.isEarned ? KnightTheme.gold : KnightTheme.wash)
                Image(systemName: badge.icon)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(badge.isEarned ? KnightTheme.onAccent : KnightTheme.muted)
            }
            .frame(width: 92, height: 92)
            .padding(.top, 28)

            Text(badge.title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(KnightTheme.ink)
            Text(badge.detail)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(KnightTheme.muted)

            if badge.isEarned {
                Label("Earned", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(KnightTheme.green)
            } else {
                VStack(spacing: 6) {
                    BizProgressBar(progress: badge.progress, tint: KnightTheme.green, height: 8)
                        .frame(width: 200, height: 8)
                    Text(badge.progressText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(KnightTheme.muted)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .background(KnightTheme.paper)
    }
}
