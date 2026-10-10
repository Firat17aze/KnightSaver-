import SwiftUI

/// The third tab: verified personal impact, campus impact, the Campus Rescue League with
/// Knight of the Week, and EcoKnight AI for the latest verified rescue (student.md "Impact").
struct ImpactView: View {
    let student: KnightPass

    @EnvironmentObject var businessStore: BusinessStore
    @AppStorage("knightsaver.league.joined") private var leagueJoined = true
    @AppStorage("knightsaver.league.nickname") private var storedNickname = ""
    /// Feedback for demo-history rescues (live ones go to the Kitchen store).
    @AppStorage("knightsaver.impact.ratedCodes") private var ratedCodes = ""
    @State private var board: LeagueBoard = .students
    @State private var period: LeaguePeriod = .week
    @State private var sheet: ImpactSheet?

    private enum ImpactSheet: Identifiable {
        case eco(StudentRescue?)
        case feedback(StudentRescue)
        case league

        var id: String {
            switch self {
            case .eco(let rescue): return "eco-\(rescue?.id.uuidString ?? "chat")"
            case .feedback(let rescue): return "feedback-\(rescue.id.uuidString)"
            case .league: return "league"
            }
        }
    }

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
        let summary = StudentImpactSummary(rescues: rescues)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 12) {
                        KnightSaverBrandBar()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Impact")
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .foregroundStyle(KnightTheme.ink)
                            Text("Only pickups verified by staff count.")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(KnightTheme.muted)
                        }
                    }

                    YourImpactCard(summary: summary)

                    if let latest = rescues.first {
                        LatestRescueCard(
                            rescue: latest,
                            isRated: isRated(latest),
                            onEcoKnight: { sheet = .eco(latest) },
                            onFeedback: { sheet = .feedback(latest) }
                        )
                    } else {
                        FirstRescueCard { sheet = .eco(nil) }
                    }

                    CampusImpactCard(studentBagsThisWeek: summary.weeklyBags(weeks: 1).first ?? 0)

                    KnightOfTheWeekCard(
                        leader: CampusLeague.entries(board: .students, period: .week, nickname: leagueJoined ? nickname : nil, yourPoints: summary.pointsThisWeek()).first
                    )

                    leagueSection(summary: summary)

                    if !rescues.isEmpty {
                        recentSection
                    }
                }
                .padding(.horizontal, KnightTheme.screenPadding)
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .background(KnightTheme.paper)
            .navigationBarHidden(true)
            .sheet(item: $sheet) { sheet in
                switch sheet {
                case .eco(let rescue):
                    EcoKnightView(rescue: rescue)
                        .presentationDragIndicator(.visible)
                case .feedback(let rescue):
                    RevealFeedbackView(rescue: rescue) { feedback in
                        submit(feedback, for: rescue)
                    }
                    .presentationDragIndicator(.visible)
                case .league:
                    LeagueSettingsView(joined: $leagueJoined, nickname: $storedNickname, suggested: nickname)
                        .presentationDetents([.medium])
                        .presentationDragIndicator(.visible)
                }
            }
        }
    }

    // MARK: League

    private func leagueSection(summary: StudentImpactSummary) -> some View {
        let yourPoints = period == .week ? summary.pointsThisWeek() : summary.pointsAllTime
        let entries = CampusLeague.entries(board: board, period: period, nickname: leagueJoined ? nickname : nil, yourPoints: yourPoints)
        let top = Array(entries.prefix(5))
        let you = entries.enumerated().first { $0.element.isYou }

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Campus Rescue League")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(KnightTheme.ink)
                    Text("One point per day with a verified pickup")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(KnightTheme.muted)
                }
                Spacer(minLength: 8)
                Button {
                    sheet = .league
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(KnightTheme.ink)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("League settings")
            }

            Picker("Period", selection: $period) {
                ForEach(LeaguePeriod.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 8) {
                ForEach(LeagueBoard.allCases) { option in
                    Button {
                        board = option
                    } label: {
                        Text(option.rawValue)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(board == option ? KnightTheme.onAccent : KnightTheme.muted)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 36)
                            .background(board == option ? KnightTheme.gold : KnightTheme.surface, in: Capsule())
                            .overlay { Capsule().stroke(KnightTheme.line, lineWidth: board == option ? 0 : 1) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(board == option ? .isSelected : [])
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(top.enumerated()), id: \.element.id) { index, entry in
                    LeagueRow(rank: index + 1, entry: entry, board: board)
                    if index < top.count - 1 { Divider().overlay(KnightTheme.line).padding(.leading, 52) }
                }
                if let you, you.offset >= 5 {
                    Divider().overlay(KnightTheme.line)
                    LeagueRow(rank: you.offset + 1, entry: you.element, board: board)
                }
            }
            .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(KnightTheme.ink.opacity(0.06), lineWidth: 1)
            }

            if board == .students && !leagueJoined {
                Button {
                    sheet = .league
                } label: {
                    Label("Join with a nickname", systemImage: "person.badge.plus")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(KnightTheme.ink)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(KnightTheme.line, lineWidth: 1) }
                }
                .buttonStyle(.plain)
            }

            Text("Joining is optional and uses a nickname. Cancelled, missed or unverified pickups earn nothing. Leaderboard names and other schools' points are demo data.")
                .font(.system(size: 12))
                .foregroundStyle(KnightTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Recent

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent verified rescues")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(KnightTheme.ink)
            VStack(spacing: 0) {
                let recent = Array(rescues.prefix(4))
                ForEach(Array(recent.enumerated()), id: \.element.id) { index, rescue in
                    HStack(spacing: 12) {
                        BrandMark(brand: rescue.brand, size: 38)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rescue.business)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(KnightTheme.ink)
                            Text("\(ImpactFormat.shortDate(rescue.verifiedAt)) · \(rescue.bags) bag\(rescue.bags == 1 ? "" : "s")")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(KnightTheme.muted)
                        }
                        Spacer(minLength: 8)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(ImpactFormat.kg(rescue.foodKg))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(KnightTheme.ink)
                            Text(rescue.measuredKg == nil ? "Est." : "Weighed")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(rescue.measuredKg == nil ? KnightTheme.goldDeep : KnightTheme.green)
                        }
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 60)
                    .accessibilityElement(children: .combine)
                    if index < recent.count - 1 { Divider().overlay(KnightTheme.line).padding(.leading, 64) }
                }
            }
            .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(KnightTheme.ink.opacity(0.06), lineWidth: 1)
            }
        }
    }

    // MARK: Feedback

    private func isRated(_ rescue: StudentRescue) -> Bool {
        rescue.isDemoHistory
            ? ratedCodes.split(separator: ",").contains(Substring(rescue.reservationCode))
            : businessStore.hasFeedback(reservationCode: rescue.reservationCode)
    }

    private func submit(_ feedback: RevealFeedback, for rescue: StudentRescue) {
        if rescue.isDemoHistory {
            ratedCodes = (ratedCodes.isEmpty ? "" : ratedCodes + ",") + rescue.reservationCode
        } else {
            businessStore.submitFeedback(
                reservationCode: rescue.reservationCode,
                overall: feedback.overall,
                portion: feedback.portion,
                surpriseQuality: feedback.surprise,
                pickupExperience: feedback.pickup,
                comment: feedback.comment,
                wouldReserveAgain: feedback.again
            )
        }
    }
}

// MARK: - Cards

private struct YourImpactCard: View {
    let summary: StudentImpactSummary
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grown = false

    var body: some View {
        let weeks = summary.weeklyBags(weeks: 6)
        let peak = max(weeks.max() ?? 1, 1)
        let streak = summary.weeklyStreak()

        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("YOUR VERIFIED IMPACT")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(KnightTheme.goldDeep)
                Spacer()
                if streak > 0 {
                    Label("\(streak)-week streak", systemImage: "flame.fill")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(KnightTheme.onAccent)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 28)
                        .background(KnightTheme.gold, in: Capsule())
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(summary.bags)")
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(KnightTheme.ink)
                Text(summary.bags == 1 ? "bag rescued" : "bags rescued")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(KnightTheme.muted)
            }

            HStack(spacing: 12) {
                miniStat(
                    title: "Food rescued",
                    value: ImpactFormat.kg(summary.foodKg),
                    caption: String(format: "%.1f weighed · %.1f est.", summary.measuredKg, summary.estimatedKg),
                    estimate: false
                )
                miniStat(
                    title: "CO₂e avoided",
                    value: ImpactFormat.kg(summary.co2eKg),
                    caption: "From food rescued",
                    estimate: true
                )
            }

            // Last six weeks of verified bags.
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(weeks.enumerated()), id: \.offset) { index, count in
                        VStack(spacing: 4) {
                            Text("\(count)")
                                .font(.system(size: 10, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(KnightTheme.muted)
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(index == weeks.count - 1 ? KnightTheme.green : KnightTheme.gold.opacity(count == 0 ? 0.25 : 0.85))
                                .frame(height: grown ? max(4, 44 * CGFloat(count) / CGFloat(peak)) : 4)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 64, alignment: .bottom)
                HStack {
                    Text("6 weeks ago")
                    Spacer()
                    Text("This week")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(KnightTheme.muted)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Bags rescued per week, oldest first: \(weeks.map(String.init).joined(separator: ", "))")
        }
        .padding(17)
        .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(KnightTheme.ink.opacity(0.07), lineWidth: 1)
        }
        .knightCardShadow()
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.7).delay(0.1)) { grown = true }
        }
    }

    private func miniStat(title: String, value: String, caption: String, estimate: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(KnightTheme.muted)
                    .lineLimit(1)
                if estimate { BizEstimateTag() }
            }
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(KnightTheme.ink)
            Text(caption)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(KnightTheme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(KnightTheme.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct LatestRescueCard: View {
    let rescue: StudentRescue
    let isRated: Bool
    let onEcoKnight: () -> Void
    let onFeedback: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                BrandMark(brand: rescue.brand, size: 46)
                VStack(alignment: .leading, spacing: 3) {
                    Label("Verified pickup", systemImage: "checkmark.seal.fill")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(KnightTheme.green)
                    Text(rescue.business)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(KnightTheme.ink)
                    Text("\(ImpactFormat.shortDate(rescue.verifiedAt)) · \(rescue.bags) bag\(rescue.bags == 1 ? "" : "s") · \(rescue.location)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(KnightTheme.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }

            Button(action: onEcoKnight) {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Open EcoKnight AI")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                        Text("What to make, what to eat first, how to store it")
                            .font(.system(size: 12, weight: .medium))
                            .opacity(0.75)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(KnightTheme.onAccent)
                .padding(.horizontal, 16)
                .frame(minHeight: 60)
                .background(KnightTheme.gold, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)

            Button(action: onFeedback) {
                Label(isRated ? "Thanks for your feedback" : "Rate it and share your reveal", systemImage: isRated ? "checkmark" : "camera")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(isRated ? KnightTheme.muted : KnightTheme.ink)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(KnightTheme.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(KnightTheme.line, lineWidth: 1) }
            }
            .buttonStyle(.plain)
            .disabled(isRated)
        }
        .padding(17)
        .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(KnightTheme.ink.opacity(0.07), lineWidth: 1)
        }
    }
}

private struct FirstRescueCard: View {
    let onAsk: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No verified rescues yet")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(KnightTheme.ink)
            Text("Reserve a Surprise Bag in Explore and show your Knight Pass at pickup. Your impact appears here once staff verify it.")
                .font(.system(size: 14))
                .foregroundStyle(KnightTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onAsk) {
                Label("Ask EcoKnight a question", systemImage: "sparkles")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(KnightTheme.onAccent)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .background(KnightTheme.gold, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(17)
        .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct CampusImpactCard: View {
    let studentBagsThisWeek: Int

    var body: some View {
        let campus = ImpactDemo.campusBase
        let thisWeek = campus.bagsThisWeek + studentBagsThisWeek
        let progress = min(Double(thisWeek) / Double(campus.weeklyGoal), 1)

        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("UCF this week")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(KnightTheme.ink)
                Spacer()
                Text("Demo data")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(KnightTheme.muted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(KnightTheme.ink.opacity(0.06), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(thisWeek)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(KnightTheme.ink)
                    Text("of \(campus.weeklyGoal) bags · campus goal")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(KnightTheme.muted)
                    Spacer()
                    Text("\(Int((progress * 100).rounded()))%")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(KnightTheme.green)
                }
                BizProgressBar(progress: progress, tint: KnightTheme.green, height: 10)
            }

            HStack(spacing: 0) {
                campusStat("\(campus.bagsAllTime.formatted())", "bags all time")
                campusStat(ImpactFormat.kg(campus.measuredKg + campus.estimatedKg), "food rescued")
                campusStat(ImpactFormat.kg(campus.co2eKg), "CO₂e avoided, est.")
            }

            Label("\(campus.residenceHalls) residence halls and \(campus.studentOrgs) student orgs are taking part", systemImage: "building.2")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(KnightTheme.muted)
        }
        .padding(17)
        .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(KnightTheme.ink.opacity(0.07), lineWidth: 1)
        }
    }

    private func campusStat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(KnightTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(KnightTheme.muted)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct KnightOfTheWeekCard: View {
    let leader: LeagueEntry?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("KNIGHT OF THE WEEK", systemImage: "crown.fill")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(KnightTheme.gold)
                    Spacer()
                    Text("Crowned in \(ImpactFormat.countdown(to: CampusLeague.nextReset(after: context.date), now: context.date))")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.75))
                }

                if let leader {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(leader.isYou ? "\(leader.name) (you)" : leader.name)
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text("\(leader.points) pt\(leader.points == 1 ? "" : "s")")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(KnightTheme.gold)
                    }
                    Text("Leading this week")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "gift.fill")
                        .foregroundStyle(KnightTheme.gold)
                    Text("The winner gets a free Surprise Bag from \(ImpactDemo.weeklySponsor), a Rescue Knight badge for a week and a shout-out in the app.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text("Sponsor-funded, so no one's bag is taken away. Demo reward.")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(17)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.055, green: 0.053, blue: 0.05), Color(red: 0.16, green: 0.135, blue: 0.09)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(KnightTheme.gold.opacity(0.25), lineWidth: 1)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

private struct LeagueRow: View {
    let rank: Int
    let entry: LeagueEntry
    let board: LeagueBoard

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(rank <= 3 ? KnightTheme.onAccent : KnightTheme.muted)
                .frame(width: 28, height: 28)
                .background(rank <= 3 ? KnightTheme.gold.opacity(rank == 1 ? 1 : 0.55) : Color.clear, in: Circle())
            Text(entry.name)
                .font(.system(size: 15, weight: entry.isYou ? .bold : .medium))
                .foregroundStyle(KnightTheme.ink)
                .lineLimit(1)
            if entry.isYou {
                Text(board == .students ? "You" : "Yours")
                    .font(.system(size: 10, weight: .black, design: .rounded))
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
        .background(entry.isYou ? KnightTheme.gold.opacity(0.10) : Color.clear)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - League settings

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
                    Text("Only your nickname is shown, never your real name. Your points still count for your hall and org.")
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
