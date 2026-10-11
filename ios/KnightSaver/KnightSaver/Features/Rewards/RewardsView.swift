import SwiftUI

/// The Rewards tab: Saver Cash (spent at campus partner kitchens), partner rewards from shops off
/// campus, the Campus Rescue League (with Knight of the Week) and badges. Everything counts staff-verified pickups only. Supabase accounts read
/// their numbers from the server (`get_my_rewards`, `get_league`); local accounts use the
/// phone's own pickup history.
struct RewardsView: View {
    let student: KnightPass

    @EnvironmentObject var businessStore: BusinessStore
    @EnvironmentObject var sessionStore: SessionStore
    @AppStorage("knightsaver.league.joined") private var leagueJoined = true
    @AppStorage("knightsaver.league.nickname") private var storedNickname = ""
    /// Partner rewards used in the local demo: "id|seconds|code" entries. Server accounts keep these on the server.
    @AppStorage("knightsaver.rewards.redeemed") private var localRedemptions = ""
    @State private var period: LeaguePeriod = .week
    @State private var showSettings = false
    @State private var selectedBadge: RewardBadge?
    @State private var qrSheet: RewardQR?
    @State private var server: RewardsSnapshot?
    @State private var serverBoards: [LeaguePeriod: LeagueBoard] = [:]

    private var isDemoStudent: Bool { student.verificationToken == KnightPass.sample.verificationToken }

    /// Newest first. Live Kitchen verifications plus the demo history for the demo student.
    private var rescues: [StudentRescue] {
        let live = businessStore.verifiedRescues(passToken: student.verificationToken)
        let history = isDemoStudent ? ImpactDemo.sampleHistory : []
        return (live + history).sorted { $0.verifiedAt > $1.verifiedAt }
    }

    private var suggestedNickname: String {
        let first = student.displayName.split(separator: " ").first.map(String.init) ?? "Knight"
        return "Sir \(first.prefix(1).uppercased() + first.dropFirst())"
    }

    private var localSnapshot: RewardsSnapshot {
        let rescues = rescues
        let summary = StudentImpactSummary(rescues: rescues)
        return RewardsSnapshot(
            stats: BadgeStats(rescues: rescues),
            cashEarnedCents: RewardRoad.cashEarnedCents(orders: rescues.count),
            cashSpentCents: 0,
            redeemed: Self.parseRedemptions(localRedemptions),
            pointsThisWeek: summary.pointsThisWeek(),
            pointsAllTime: summary.pointsAllTime,
            leagueJoined: leagueJoined,
            nickname: storedNickname.isEmpty ? suggestedNickname : storedNickname
        )
    }

    private func board(_ period: LeaguePeriod, for data: RewardsSnapshot) -> LeagueBoard {
        if server != nil, let board = serverBoards[period] { return board }
        return LeagueBoard.demo(
            period: period,
            nickname: data.leagueJoined ? data.nickname : nil,
            yourPoints: period == .week ? data.pointsThisWeek : data.pointsAllTime
        )
    }

    var body: some View {
        let data = server ?? localSnapshot
        let weekBoard = board(.week, for: data)
        let badges = RewardRules.badges(data.stats, isKnightOfTheWeek: weekBoard.leader?.entry.isYou == true)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Rewards")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(KnightTheme.ink)
                            .accessibilityAddTraits(.isHeader)
                        Text("Earned from staff-verified pickups")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(KnightTheme.muted)
                    }

                    SaverCashCard(pickups: data.stats.pickups, balanceCents: data.cashBalanceCents) {
                        qrSheet = .cash
                    }

                    partnerSection(data)

                    leagueSection(board: period == .week ? weekBoard : board(.allTime, for: data), joined: data.leagueJoined)

                    badgeSection(badges)
                }
                .padding(.horizontal, KnightTheme.screenPadding)
                .padding(.top, 16)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .reservesTabBarSpace()
            .background(KnightTheme.paper)
            .navigationBarHidden(true)
            .refreshable { await loadFromServer() }
            .task(id: sessionStore.accessToken) { await loadFromServer() }
            .sheet(isPresented: $showSettings) {
                LeagueSettingsView(
                    joined: data.leagueJoined,
                    nickname: data.nickname ?? suggestedNickname,
                    onSave: saveLeagueSettings
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $selectedBadge) { badge in
                BadgeDetailView(badge: badge)
                    .presentationDetents([.height(320)])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $qrSheet) { sheet in
                rewardSheet(sheet, data: data)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: Server

    /// Loads the student's rewards and both league boards. Keeps the local numbers when the
    /// account isn't on the server or the server can't be reached.
    private func loadFromServer() async {
        guard let accessToken = sessionStore.accessToken else {
            server = nil
            serverBoards = [:]
            return
        }
        do {
            async let rewards = KnightSaverBackend.shared.fetchRewards(accessToken: accessToken)
            async let week = KnightSaverBackend.shared.fetchLeague(period: "week", accessToken: accessToken)
            async let allTime = KnightSaverBackend.shared.fetchLeague(period: "all_time", accessToken: accessToken)
            let (loadedRewards, loadedWeek, loadedAllTime) = try await (rewards, week, allTime)
            server = RewardsSnapshot(loadedRewards)
            serverBoards = [.week: LeagueBoard(loadedWeek), .allTime: LeagueBoard(loadedAllTime)]
        } catch {
            server = nil
            serverBoards = [:]
        }
    }

    /// Returns an error to show in the settings sheet, or nil once saved.
    private func saveLeagueSettings(joined: Bool, nickname: String) async -> String? {
        let trimmed = String(nickname.trimmingCharacters(in: .whitespacesAndNewlines).prefix(20))
        if joined && trimmed.count < 2 { return "Use a nickname of at least 2 characters." }
        guard server != nil, let accessToken = sessionStore.accessToken else {
            leagueJoined = joined
            storedNickname = trimmed
            return nil
        }
        do {
            try await KnightSaverBackend.shared.setLeagueProfile(optIn: joined, nickname: trimmed, accessToken: accessToken)
            await loadFromServer()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    // MARK: Partner rewards

    private static func parseRedemptions(_ stored: String) -> [String: PartnerRedemption] {
        var result: [String: PartnerRedemption] = [:]
        for entry in stored.split(separator: ",") {
            let parts = entry.split(separator: "|").map(String.init)
            guard parts.count == 3, let seconds = Double(parts[1]) else { continue }
            result[parts[0]] = PartnerRedemption(code: parts[2], redeemedAt: Date(timeIntervalSince1970: seconds))
        }
        return result
    }

    /// Uses a partner reward: on the server for Supabase accounts, on this phone for the local demo.
    /// Returns an error to show, or nil once used.
    private func redeem(_ reward: PartnerReward) async -> String? {
        if server != nil, let accessToken = sessionStore.accessToken {
            do {
                _ = try await KnightSaverBackend.shared.redeemPartnerReward(rewardID: reward.id, accessToken: accessToken)
                await loadFromServer()
                return nil
            } catch {
                return error.localizedDescription
            }
        }
        guard Self.parseRedemptions(localRedemptions)[reward.id] == nil else { return nil }
        let code = "KS-" + String(UUID().uuidString.prefix(6))
        let entry = "\(reward.id)|\(Int(Date().timeIntervalSince1970))|\(code)"
        localRedemptions = localRedemptions.isEmpty ? entry : localRedemptions + "," + entry
        return nil
    }

    /// Short code printed under the Saver Cash QR, so staff can type it if the camera struggles.
    private func counterCode(_ suffix: String) -> String {
        let tail = String(student.verificationToken.suffix(4)).uppercased()
        return "KS-\(tail)-\(suffix.uppercased())"
    }

    private func partnerSection(_ data: RewardsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            BizSectionHeader(
                title: "Partner rewards",
                subtitle: "From local shops off campus",
                trailing: "\(data.redeemed.count) of \(RewardRoad.partnerRewards.count)"
            )

            VStack(spacing: 0) {
                ForEach(Array(RewardRoad.partnerRewards.enumerated()), id: \.element.id) { index, reward in
                    PartnerRewardRow(
                        reward: reward,
                        unlockAt: RewardRoad.unlockOrders(for: reward),
                        pickups: data.stats.pickups,
                        isUsed: data.redeemed[reward.id] != nil
                    ) {
                        qrSheet = .partner(reward)
                    }
                    if index < RewardRoad.partnerRewards.count - 1 {
                        Divider().overlay(KnightTheme.line).padding(.leading, 70)
                    }
                }
            }
            .rewardsListCard()
        }
    }

    @ViewBuilder
    private func rewardSheet(_ sheet: RewardQR, data: RewardsSnapshot) -> some View {
        switch sheet {
        case .cash:
            RewardQRView(
                eyebrow: "Saver Cash",
                title: SaverCash.format(data.cashBalanceCents),
                subtitle: "Pay at any campus partner kitchen",
                payload: "knightsaver://cash/\(student.verificationToken)",
                code: counterCode("CASH"),
                note: "Staff scan this and take up to your balance off the bill. Your balance updates after the scan."
            )
        case .partner(let reward):
            PartnerRewardSheet(
                reward: reward,
                unlockAt: RewardRoad.unlockOrders(for: reward),
                pickups: data.stats.pickups,
                redemption: data.redeemed[reward.id]
            ) {
                await redeem(reward)
            }
        }
    }

    // MARK: League

    private func leagueSection(board: LeagueBoard, joined: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                BizSectionHeader(title: "Rescue League", subtitle: "1 point for each day you pick up")
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(KnightTheme.muted)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("League settings")
            }

            Picker("Period", selection: $period) {
                ForEach(LeaguePeriod.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            VStack(spacing: 0) {
                if period == .week, let leader = board.leader {
                    KnightOfTheWeekRow(leader: leader, endsAt: board.weekEndsAt)
                    Divider().overlay(KnightTheme.line)
                }
                ForEach(Array(board.top.enumerated()), id: \.element.id) { index, standing in
                    LeagueRow(standing: standing)
                    if index < board.top.count - 1 {
                        Divider().overlay(KnightTheme.line).padding(.leading, 54)
                    }
                }
                if let you = board.you, !board.top.contains(you) {
                    Divider().overlay(KnightTheme.line)
                    LeagueRow(standing: you)
                }
                if board.top.isEmpty {
                    Text("No one has joined the league yet.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(KnightTheme.muted)
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
            }
            .rewardsListCard()

            Text(joined
                 ? "Others see only your nickname. Cancelled, missed or unverified pickups earn nothing."
                 : "You're not in the league. Join from the settings button; only your nickname is shown.")
                .font(.system(size: 12))
                .foregroundStyle(KnightTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Badges

    private func badgeSection(_ badges: [RewardBadge]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            BizSectionHeader(title: "Badges", trailing: "\(badges.filter(\.isEarned).count) of \(badges.count)")

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 18) {
                ForEach(badges) { badge in
                    Button {
                        selectedBadge = badge
                    } label: {
                        BadgeTile(badge: badge)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

private extension View {
    func rewardsListCard() -> some View {
        background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(KnightTheme.line, lineWidth: 1)
            }
    }
}

// MARK: - Server data

extension RewardsSnapshot {
    init(_ remote: RemoteRewards) {
        self.init(
            stats: BadgeStats(
                pickups: remote.orders,
                bags: remote.bags,
                kitchens: remote.kitchens,
                weeklyStreak: remote.weeklyStreak,
                measuredKg: remote.measuredKg,
                co2eKg: remote.co2eKg,
                hasNightPickup: remote.nightPickup
            ),
            cashEarnedCents: remote.cashEarnedCents,
            cashSpentCents: remote.cashSpentCents,
            redeemed: Dictionary(
                remote.redeemed.map { ($0.rewardID, PartnerRedemption(code: $0.code, redeemedAt: $0.redeemedAt)) },
                uniquingKeysWith: { first, _ in first }
            ),
            pointsThisWeek: remote.pointsThisWeek,
            pointsAllTime: remote.pointsAllTime,
            leagueJoined: remote.leagueOptIn,
            nickname: remote.leagueNickname
        )
    }
}

extension LeagueBoard {
    init(_ remote: RemoteLeague) {
        func standing(_ row: RemoteLeague.Row) -> LeagueStanding {
            LeagueStanding(rank: row.rank, entry: LeagueEntry(name: row.nickname, points: row.points, isYou: row.isYou))
        }
        self.init(top: remote.entries.map(standing), you: remote.you.map(standing), weekEndsAt: remote.weekEndsAt)
    }
}

// MARK: - Saver Cash

private enum RewardQR: Identifiable {
    case cash
    case partner(PartnerReward)

    var id: String {
        switch self {
        case .cash: "cash"
        case .partner(let reward): "partner-\(reward.id)"
        }
    }
}

/// Saver Cash: money earned from verified pickups, paid with a QR at the counter.
private struct SaverCashCard: View {
    let pickups: Int
    let balanceCents: Int
    let onPay: () -> Void

    var body: some View {
        let next = RewardRoad.next(after: pickups)

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Saver Cash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(KnightTheme.muted)
                    Text(SaverCash.format(balanceCents))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(KnightTheme.ink)
                        .contentTransition(.numericText())
                        .accessibilityLabel("Saver Cash balance \(SaverCash.format(balanceCents))")
                }
                Spacer(minLength: 8)
                Button(action: onPay) {
                    Label("Pay", systemImage: "qrcode")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(KnightTheme.onAccent)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 44)
                        .background(KnightTheme.gold, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(balanceCents == 0)
                .opacity(balanceCents == 0 ? 0.45 : 1)
                .accessibilityHint("Shows a QR code for the counter")
            }

            Text("\(pickups) verified pickup\(pickups == 1 ? "" : "s") · spend it at any partner kitchen")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(KnightTheme.muted)

            Divider().overlay(KnightTheme.line)

            if let next {
                let toGo = next.orders - pickups
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(toGo) more pickup\(toGo == 1 ? "" : "s") to \(next.title)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(KnightTheme.ink)
                    BizProgressBar(progress: RewardRoad.progressToNext(orders: pickups), tint: KnightTheme.green, height: 6)
                }
                .accessibilityElement(children: .combine)
            } else {
                Text("You've unlocked every reward.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(KnightTheme.green)
            }
        }
        .bizCard()
    }
}

// MARK: - Partner rewards

/// One partner reward: the shop's color once unlocked, plain until then.
private struct PartnerRewardRow: View {
    let reward: PartnerReward
    let unlockAt: Int
    let pickups: Int
    let isUsed: Bool
    let onOpen: () -> Void

    var body: some View {
        let unlocked = pickups >= unlockAt

        Button(action: onOpen) {
            HStack(spacing: 14) {
                Image(systemName: reward.icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(unlocked && !isUsed ? reward.partner.onTint : KnightTheme.placeholder)
                    .frame(width: 44, height: 44)
                    .background(
                        unlocked && !isUsed ? reward.partner.tint : KnightTheme.wash,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(reward.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(KnightTheme.ink)
                        .lineLimit(1)
                    Text(reward.place)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(KnightTheme.muted)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                if isUsed {
                    Label("Used", systemImage: "checkmark")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(KnightTheme.muted)
                } else if unlocked {
                    Text("Use")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(KnightTheme.onAccent)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 34)
                        .background(KnightTheme.gold, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    Text("At \(unlockAt) pickups")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(KnightTheme.muted)
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 66)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(isUsed ? "Shows when it was used" : unlocked ? "Use it at the shop" : "Unlocks at \(unlockAt) verified pickups")
    }
}

/// A partner reward. Off-campus shops don't scan anything: at the counter the student taps
/// "Use at the shop", and the cashier sees a one-time screen with a code and a live clock.
private struct PartnerRewardSheet: View {
    let reward: PartnerReward
    let unlockAt: Int
    let pickups: Int
    let redemption: PartnerRedemption?
    let onRedeem: () async -> String?

    @State private var confirm = false
    @State private var isWorking = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: reward.icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(reward.partner.onTint)
                    .frame(width: 64, height: 64)
                    .background(reward.partner.tint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.top, 30)
                    .accessibilityHidden(true)

                VStack(spacing: 6) {
                    Text(reward.name)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(KnightTheme.ink)
                        .multilineTextAlignment(.center)
                    Text(reward.detail)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(KnightTheme.muted)
                        .multilineTextAlignment(.center)
                    Label(reward.place, systemImage: reward.partner.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(KnightTheme.lake)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 24)

                if let redemption {
                    RedeemedCard(redemption: redemption, place: reward.place)
                        .padding(.horizontal, KnightTheme.screenPadding)
                } else if pickups >= unlockAt {
                    Text("Use it at the \(reward.partner.name) counter: tap the button there and show the screen to the cashier. It works once.")
                        .font(.system(size: 14))
                        .foregroundStyle(KnightTheme.muted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 24)
                    Button {
                        confirm = true
                    } label: {
                        Text(isWorking ? "Using…" : "Use at the shop")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(KnightTheme.onAccent)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(KnightTheme.gold, in: RoundedRectangle(cornerRadius: KnightTheme.controlRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isWorking)
                    .padding(.horizontal, KnightTheme.screenPadding)
                } else {
                    Text("Unlocks at \(unlockAt) verified pickups. \(unlockAt - pickups) to go.")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(KnightTheme.muted)
                }

                if let error {
                    Text(error)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(KnightTheme.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 30)
        }
        .background(KnightTheme.paper)
        .alert("Use it now?", isPresented: $confirm) {
            Button("Cancel", role: .cancel) {}
            Button("Use now") {
                Task {
                    isWorking = true
                    error = await onRedeem()
                    isWorking = false
                }
            }
        } message: {
            Text("Only tap this at the \(reward.partner.name) counter. The reward can be used once.")
        }
    }
}

/// What the cashier checks: the code, when it was used, and a live clock so a screenshot can't be reused.
private struct RedeemedCard: View {
    let redemption: PartnerRedemption
    let place: String

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 10) {
                Label("Used", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(KnightTheme.green)
                Text(redemption.code)
                    .font(.system(size: 30, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(KnightTheme.ink)
                    .textSelection(.enabled)
                Text("Used \(redemption.redeemedAt.formatted(date: .abbreviated, time: .shortened)) at \(place)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(KnightTheme.muted)
                    .multilineTextAlignment(.center)
                Text(context.date.formatted(date: .omitted, time: .standard))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(KnightTheme.muted)
                    .accessibilityLabel("Current time")
            }
            .frame(maxWidth: .infinity)
            .padding(18)
            .background(KnightTheme.greenWash, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}

// MARK: - QR at the counter

private struct RewardQRView: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let payload: String
    let code: String
    let note: String

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 6) {
                    Text(eyebrow)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(KnightTheme.muted)
                    Text(title)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(KnightTheme.ink)
                        .multilineTextAlignment(.center)
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(KnightTheme.muted)
                }
                .padding(.top, 30)

                // QR on white in both appearances so counter scanners read it.
                QRCodeView(value: payload)
                    .frame(width: 210, height: 210)
                    .padding(16)
                    .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(KnightTheme.line, lineWidth: 1)
                    }
                    .accessibilityLabel("QR code for staff to scan")

                Text(code)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(KnightTheme.ink)
                    .textSelection(.enabled)

                Text(note)
                    .font(.system(size: 13))
                    .foregroundStyle(KnightTheme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)

            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 30)
        }
        .background(KnightTheme.paper)
    }
}

// MARK: - League rows and settings

/// The first line of this week's league: who leads, what they win and when the week closes.
private struct KnightOfTheWeekRow: View {
    let leader: LeagueStanding
    let endsAt: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(KnightTheme.goldDeep)
                    .frame(width: 28)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Knight of the Week: \(leader.entry.isYou ? "you" : leader.entry.name)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(KnightTheme.ink)
                        .lineLimit(1)
                    Text("Wins a free Surprise Bag from \(ImpactDemo.weeklySponsor) · ends in \(ImpactFormat.countdown(to: endsAt, now: context.date))")
                        .font(.system(size: 12, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(KnightTheme.muted)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .accessibilityElement(children: .combine)
        }
    }
}

private struct LeagueRow: View {
    let standing: LeagueStanding

    var body: some View {
        let entry = standing.entry
        HStack(spacing: 12) {
            Text("\(standing.rank)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(standing.rank <= 3 ? KnightTheme.ink : KnightTheme.muted)
                .frame(width: 28)
            Text(entry.name)
                .font(.system(size: 15, weight: entry.isYou ? .bold : .medium))
                .foregroundStyle(KnightTheme.ink)
                .lineLimit(1)
            if entry.isYou {
                Text("you")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(KnightTheme.muted)
            }
            Spacer(minLength: 8)
            Text("\(entry.points.formatted()) pt\(entry.points == 1 ? "" : "s")")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(KnightTheme.ink)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 52)
        .background(entry.isYou ? KnightTheme.wash : Color.clear)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(standing.rank), \(entry.name)\(entry.isYou ? ", you" : ""), \(entry.points) points")
    }
}

private struct LeagueSettingsView: View {
    let joined: Bool
    let nickname: String
    let onSave: (_ joined: Bool, _ nickname: String) async -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var draftJoined = true
    @State private var draftNickname = ""
    @State private var error: String?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Show me in the league", isOn: $draftJoined)
                        .tint(KnightTheme.green)
                    if draftJoined {
                        TextField("Nickname", text: $draftNickname)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                    }
                } footer: {
                    Text(error ?? "Only your nickname is shown, never your real name.")
                        .foregroundStyle(error == nil ? KnightTheme.muted : KnightTheme.red)
                }
            }
            .scrollContentBackground(.hidden)
            .background(KnightTheme.paper)
            .navigationTitle("League settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSaving ? "Saving…" : "Save") {
                        Task {
                            isSaving = true
                            error = await onSave(draftJoined, draftNickname)
                            isSaving = false
                            if error == nil { dismiss() }
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(isSaving)
                }
            }
            .onAppear {
                draftJoined = joined
                draftNickname = nickname
            }
        }
    }
}

// MARK: - Badges

/// Earned badges are filled green; locked ones are an outline.
private struct BadgeTile: View {
    let badge: RewardBadge

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: badge.icon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(badge.isEarned ? KnightTheme.green : KnightTheme.placeholder)
                .frame(width: 54, height: 54)
                .background(badge.isEarned ? KnightTheme.greenWash : KnightTheme.surface, in: Circle())
                .overlay {
                    Circle().stroke(badge.isEarned ? Color.clear : KnightTheme.line, lineWidth: 1)
                }

            Text(badge.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(badge.isEarned ? KnightTheme.ink : KnightTheme.muted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 28, alignment: .top)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(badge.title), \(badge.isEarned ? "earned" : "not earned yet, \(badge.progressText)")")
        .accessibilityHint(badge.detail)
    }
}

private struct BadgeDetailView: View {
    let badge: RewardBadge

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: badge.icon)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(badge.isEarned ? KnightTheme.green : KnightTheme.placeholder)
                .frame(width: 88, height: 88)
                .background(badge.isEarned ? KnightTheme.greenWash : KnightTheme.surface, in: Circle())
                .overlay {
                    Circle().stroke(badge.isEarned ? Color.clear : KnightTheme.line, lineWidth: 1)
                }
                .padding(.top, 28)

            Text(badge.title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(KnightTheme.ink)
            Text(badge.detail)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(KnightTheme.muted)

            if badge.isEarned {
                Text("Earned")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(KnightTheme.green)
            } else {
                VStack(spacing: 6) {
                    BizProgressBar(progress: badge.progress, tint: KnightTheme.green, height: 6)
                        .frame(width: 200, height: 6)
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
