import SwiftUI

/// The Rewards tab: Knight Cash, the Rescue Crew toys, Knight of the Week,
/// the Campus Rescue League and badges. Everything here counts staff-verified pickups only.
struct RewardsView: View {
    let student: KnightPass

    @EnvironmentObject var businessStore: BusinessStore
    @AppStorage("knightsaver.league.joined") private var leagueJoined = true
    @AppStorage("knightsaver.league.nickname") private var storedNickname = ""
    @State private var period: LeaguePeriod = .week
    @State private var showSettings = false
    @State private var selectedBadge: RewardBadge?
    /// Rescue Crew toys the student has picked up, by id.
    @AppStorage("knightsaver.rewards.collected") private var collectedIDs = ""
    @State private var qrSheet: RewardQR?

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
        let badges = RewardRules.badges(rescues: allRescues, summary: summary, wonKnightOfTheWeek: weekEntries.first?.isYou == true)
        // One verified pickup is one order, however many bags it held.
        let orders = allRescues.count

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
                            Text("The more you order, the more you earn.")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(KnightTheme.muted)
                        }
                    }

                    KnightCashCard(orders: orders, balanceCents: RewardRoad.cashEarnedCents(orders: orders)) {
                        qrSheet = .cash
                    }

                    crewSection(orders: orders)

                    // The podium follows the league's period picker.
                    KnightOfTheWeekCard(
                        period: period,
                        podium: Array((period == .week ? weekEntries : CampusLeague.entries(
                            period: .allTime, nickname: leagueJoined ? nickname : nil, yourPoints: summary.pointsAllTime
                        )).prefix(3))
                    )

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
            .sheet(item: $qrSheet) { sheet in
                rewardQRSheet(sheet, orders: orders)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: Knight Cash and toys

    private var collected: Set<String> {
        Set(collectedIDs.split(separator: ",").map(String.init))
    }

    private func markCollected(_ toy: Collectible) {
        guard !collected.contains(toy.id) else { return }
        collectedIDs = (collectedIDs.isEmpty ? "" : collectedIDs + ",") + toy.id
    }

    /// Short code printed under each QR, so staff can type it if the camera struggles.
    private func counterCode(_ suffix: String) -> String {
        let tail = String(student.verificationToken.suffix(4)).uppercased()
        return "KS-\(tail)-\(suffix.uppercased())"
    }

    private func crewSection(orders: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            BizSectionHeader(
                title: "Rescue Crew",
                subtitle: "Little toys waiting behind partner counters",
                trailing: "\(RewardRoad.crew.filter { collected.contains($0.id) }.count) of \(RewardRoad.crew.count)"
            )

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(RewardRoad.crew) { toy in
                        let unlockAt = RewardRoad.unlockOrders(for: toy)
                        let isReady = orders >= unlockAt && !collected.contains(toy.id)
                        Button {
                            qrSheet = .collectible(toy)
                        } label: {
                            CrewCard(toy: toy, unlockAt: unlockAt, orders: orders, isCollected: collected.contains(toy.id))
                        }
                        .buttonStyle(.plain)
                        // Only a toy ready to pick up opens its QR.
                        .allowsHitTesting(isReady)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
    }

    @ViewBuilder
    private func rewardQRSheet(_ sheet: RewardQR, orders: Int) -> some View {
        switch sheet {
        case .cash:
            RewardQRView(
                eyebrow: "Knight Cash",
                title: KnightCash.format(RewardRoad.cashEarnedCents(orders: orders)),
                subtitle: "Pay at any partner kitchen counter",
                payload: "knightsaver://cash/\(student.verificationToken)",
                code: counterCode("CASH"),
                tint: KnightTheme.green,
                icon: "dollarsign",
                note: "Staff scan this and take up to your balance off the bill. Your balance updates after the scan.",
                onCollected: nil
            )
        case .collectible(let toy):
            RewardQRView(
                eyebrow: "Rescue Crew",
                title: toy.name,
                subtitle: "Pick up at \(toy.pickupPlace)",
                payload: "knightsaver://reward/\(student.verificationToken)/\(toy.id)",
                code: counterCode(String(toy.id.prefix(4))),
                tint: toy.brand?.secondary ?? KnightTheme.gold,
                icon: toy.icon,
                note: "\(toy.detail). Show this at the counter and staff hand it over. One per student.",
                onCollected: collected.contains(toy.id) ? nil : { markCollected(toy) }
            )
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
                    .stroke(KnightTheme.line, lineWidth: 1)
            }
    }
}

// MARK: - Knight Cash

private enum RewardQR: Identifiable {
    case cash
    case collectible(Collectible)

    var id: String {
        switch self {
        case .cash: "cash"
        case .collectible(let toy): "toy-\(toy.id)"
        }
    }
}

/// The wallet: Knight Cash earned from verified orders, paid with a QR at the counter.
private struct KnightCashCard: View {
    let orders: Int
    let balanceCents: Int
    let onPay: () -> Void

    var body: some View {
        let next = RewardRoad.next(after: orders)
        let tier = KnightTier(orders: orders)

        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                // Flat gold coin with a K, the wallet's mark.
                Text("K")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(KnightTheme.onAccent)
                    .frame(width: 40, height: 40)
                    .background(KnightTheme.gold, in: Circle())
                    .overlay { Circle().stroke(KnightTheme.goldDeep, lineWidth: 2).padding(3) }
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Knight Cash")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(KnightTheme.ink)
                    Text("Spend it at any partner kitchen")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(KnightTheme.muted)
                }
                Spacer(minLength: 8)
                Label(tier.rawValue, systemImage: "shield.lefthalf.filled")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(KnightTheme.lake)
                    .padding(.horizontal, 9)
                    .frame(minHeight: 26)
                    .background(KnightTheme.lake.opacity(0.12), in: Capsule())
                    .accessibilityLabel("\(tier.rawValue) tier")
            }

            HStack(alignment: .lastTextBaseline) {
                Text(KnightCash.format(balanceCents))
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(KnightTheme.ink)
                    .contentTransition(.numericText())
                    .accessibilityLabel("Balance \(KnightCash.format(balanceCents))")
                Spacer(minLength: 8)
                Button(action: onPay) {
                    Label("Pay with QR", systemImage: "qrcode")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(KnightTheme.onAccent)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .background(KnightTheme.gold, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(balanceCents == 0)
                .opacity(balanceCents == 0 ? 0.5 : 1)
            }

            Divider().overlay(KnightTheme.line)

            if let next {
                let toGo = next.orders - orders
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: next.icon)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(KnightTheme.green)
                        Text("\(toGo) more order\(toGo == 1 ? "" : "s") to \(next.title)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(KnightTheme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    BizProgressBar(progress: RewardRoad.progressToNext(orders: orders), tint: KnightTheme.green, height: 8)
                }
                .accessibilityElement(children: .combine)
            } else {
                Label("Every reward unlocked. Legend.", systemImage: "crown.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(KnightTheme.goldDeep)
            }
        }
        .bizCard()
    }
}

// MARK: - Rescue Crew

/// A toy box: brand colors once unlocked, a dim silhouette until then.
private struct CrewCard: View {
    let toy: Collectible
    let unlockAt: Int
    let orders: Int
    let isCollected: Bool

    var body: some View {
        let unlocked = orders >= unlockAt
        // The mystery capsule has no kitchen, so it gets the app's gold.
        let primary = toy.brand?.primary ?? KnightTheme.gold
        let secondary = toy.brand?.secondary ?? KnightTheme.onAccent

        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(unlocked ? primary : KnightTheme.wash)
                Image(systemName: toy.icon)
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(unlocked ? secondary : KnightTheme.muted.opacity(0.35))
                if !unlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(KnightTheme.muted)
                        .frame(width: 24, height: 24)
                        .background(KnightTheme.surface, in: Circle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(8)
                }
            }
            .frame(height: 96)

            VStack(alignment: .leading, spacing: 2) {
                Text(toy.name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(KnightTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(toy.store)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(KnightTheme.muted)
                    .lineLimit(1)
            }

            status(unlocked: unlocked)
        }
        .padding(10)
        .frame(width: 148)
        .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(KnightTheme.line, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func status(unlocked: Bool) -> some View {
        if isCollected {
            Label("Collected", systemImage: "checkmark.seal.fill")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(KnightTheme.green)
                .frame(minHeight: 26)
        } else if unlocked {
            Label("Show QR", systemImage: "qrcode")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(KnightTheme.onAccent)
                .padding(.horizontal, 10)
                .frame(minHeight: 26)
                .background(KnightTheme.gold, in: Capsule())
        } else {
            Text("\(unlockAt - orders) more order\(unlockAt - orders == 1 ? "" : "s")")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(KnightTheme.muted)
                .frame(minHeight: 26)
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
    let tint: Color
    let icon: String
    let note: String
    /// Set for toys not picked up yet.
    let onCollected: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(KnightTheme.onAccent)
                        .frame(width: 52, height: 52)
                        .background(tint, in: Circle())
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
                .padding(.top, 26)

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

                if let onCollected {
                    Button {
                        onCollected()
                        dismiss()
                    } label: {
                        Label("I got it, mark as collected", systemImage: "checkmark.seal.fill")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(KnightTheme.ink)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(KnightTheme.wash, in: RoundedRectangle(cornerRadius: KnightTheme.controlRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, KnightTheme.screenPadding)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 30)
        }
        .background(KnightTheme.paper)
    }
}

// MARK: - Knight of the Week

/// Dark card with the podium: first place in the middle, raised and crowned.
/// "This week" is Knight of the Week with its countdown and prize; "All time" is the hall of fame.
private struct KnightOfTheWeekCard: View {
    let period: LeaguePeriod
    let podium: [LeagueEntry]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label(period == .week ? "KNIGHT OF THE WEEK" : "ALL-TIME LEGENDS", systemImage: period == .week ? "crown.fill" : "trophy.fill")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(KnightTheme.gold)
                    Spacer()
                    Text(period == .week
                         ? "Ends in \(ImpactFormat.countdown(to: CampusLeague.nextReset(after: context.date), now: context.date))"
                         : "Since launch")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(KnightTheme.paleText)
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

                Label(period == .week ? "Prize: a free Surprise Bag from \(ImpactDemo.weeklySponsor)" : "Most rescue days since KnightSaver started",
                      systemImage: period == .week ? "gift.fill" : "sparkles")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(KnightTheme.paleText)
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
                .foregroundStyle(KnightTheme.paleText)
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
