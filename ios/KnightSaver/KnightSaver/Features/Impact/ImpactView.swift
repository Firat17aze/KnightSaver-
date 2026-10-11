import SwiftUI

/// The third tab, split in two so each half reads on its own (student.md "Impact"):
/// "You" is verified personal impact and recent rescues;
/// "Campus" is the weekly goal, Knight of the Week and the Campus Rescue League.
struct ImpactView: View {
    let student: KnightPass

    @EnvironmentObject var businessStore: BusinessStore
    @AppStorage("knightsaver.league.joined") private var leagueJoined = true
    @AppStorage("knightsaver.league.nickname") private var storedNickname = ""
    /// Feedback for demo-history rescues (live ones go to the Kitchen store).
    @AppStorage("knightsaver.impact.ratedCodes") private var ratedCodes = ""
    @State private var section: ImpactSection = .you
    @State private var period: LeaguePeriod = .week
    @State private var sheet: ImpactSheet?

    private enum ImpactSection: String, CaseIterable, Identifiable {
        case you = "You"
        case campus = "Campus"
        var id: String { rawValue }
    }

    private enum ImpactSheet: Identifiable {
        case feedback(StudentRescue)
        case league

        var id: String {
            switch self {
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
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 12) {
                        KnightSaverBrandBar()
                        EcoKnightAskBar(stats: EcoStats(summary: summary, rescues: rescues, leagueNickname: leagueJoined ? nickname : nil))
                    }

                    Picker("Section", selection: $section) {
                        ForEach(ImpactSection.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    switch section {
                    case .you: youSection(summary: summary)
                    case .campus: campusSection(summary: summary)
                    }
                }
                .padding(.horizontal, KnightTheme.screenPadding)
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .reservesTabBarSpace()
            .background(KnightTheme.paper)
            .navigationBarHidden(true)
            .sheet(item: $sheet) { sheet in
                switch sheet {
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

    // MARK: You

    @ViewBuilder
    private func youSection(summary: StudentImpactSummary) -> some View {
        YourImpactCard(summary: summary)

        let recent = Array(rescues.prefix(5))
        if recent.isEmpty {
            FirstRescueCard()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                BizSectionHeader(title: "Recent rescues")
                VStack(spacing: 0) {
                    ForEach(Array(recent.enumerated()), id: \.element.id) { index, rescue in
                        RescueRow(rescue: rescue)
                        if index < recent.count - 1 { Divider().overlay(KnightTheme.line).padding(.leading, 64) }
                    }
                }
                .listCard()
            }
        }
    }

    // MARK: Campus

    @ViewBuilder
    private func campusSection(summary: StudentImpactSummary) -> some View {
        CampusGoalCard(studentBagsThisWeek: summary.weeklyBags(weeks: 1).first ?? 0)

        KnightOfTheWeekCard(
            leader: CampusLeague.entries(period: .week, nickname: leagueJoined ? nickname : nil, yourPoints: summary.pointsThisWeek()).first
        )

        leagueSection(summary: summary)
    }

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
                    sheet = .league
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
            .listCard()

            if !leagueJoined {
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

            Text("Joining is optional and shows only your nickname. Cancelled, missed or unverified pickups earn nothing.")
                .font(.system(size: 12))
                .foregroundStyle(KnightTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
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

private extension View {
    /// White rounded container for list rows (league, earlier rescues).
    func listCard() -> some View {
        background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(KnightTheme.ink.opacity(0.06), lineWidth: 1)
            }
    }
}

// MARK: - You

private struct YourImpactCard: View {
    let summary: StudentImpactSummary
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grown = false

    var body: some View {
        let weeks = summary.weeklyBags(weeks: 6)
        let peak = max(weeks.max() ?? 1, 1)
        let streak = summary.weeklyStreak()

        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(summary.bags)")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(KnightTheme.ink)
                    Text(summary.bags == 1 ? "bag rescued" : "bags rescued")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(KnightTheme.muted)
                }
                .accessibilityElement(children: .combine)
                Spacer()
                if streak > 0 {
                    Label("\(streak)-week streak", systemImage: "flame.fill")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(KnightTheme.citrus)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 28)
                        .background(KnightTheme.citrus.opacity(0.13), in: Capsule())
                }
            }

            HStack(spacing: 0) {
                stat(
                    title: "Food rescued",
                    value: ImpactFormat.kg(summary.foodKg),
                    caption: String(format: "%.1f weighed · %.1f est.", summary.measuredKg, summary.estimatedKg),
                    estimate: false
                )
                Rectangle()
                    .fill(KnightTheme.line)
                    .frame(width: 1, height: 44)
                    .padding(.horizontal, 14)
                stat(
                    title: "CO₂e avoided",
                    value: ImpactFormat.kg(summary.co2eKg),
                    caption: "From food rescued",
                    estimate: true
                )
            }

            // Last six weeks of verified bags, in impact green; this week at full strength.
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(weeks.enumerated()), id: \.offset) { index, count in
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(KnightTheme.green.opacity(index == weeks.count - 1 ? 1 : count == 0 ? 0.15 : 0.4))
                            .frame(height: grown ? max(4, 40 * CGFloat(count) / CGFloat(peak)) : 4)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 40, alignment: .bottom)
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
        .bizCard()
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.7).delay(0.1)) { grown = true }
        }
    }

    private func stat(title: String, value: String, caption: String, estimate: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(KnightTheme.muted)
                    .lineLimit(1)
                if estimate { BizEstimateTag() }
            }
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(KnightTheme.ink)
            Text(caption)
                .font(.system(size: 11))
                .foregroundStyle(KnightTheme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct FirstRescueCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No verified rescues yet")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(KnightTheme.ink)
            Text("Reserve a Surprise Bag in Explore and show your Knight Pass at pickup. Your impact appears here once staff verify it.")
                .font(.system(size: 14))
                .foregroundStyle(KnightTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .bizCard()
    }
}

private struct RescueRow: View {
    let rescue: StudentRescue

    var body: some View {
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
                    .foregroundStyle(rescue.measuredKg == nil ? KnightTheme.muted : KnightTheme.green)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 60)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Campus

private struct CampusGoalCard: View {
    let studentBagsThisWeek: Int

    var body: some View {
        let campus = ImpactDemo.campusBase
        let thisWeek = campus.bagsThisWeek + studentBagsThisWeek
        let progress = min(Double(thisWeek) / Double(campus.weeklyGoal), 1)

        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("UCF this week")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(KnightTheme.muted)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(thisWeek)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(KnightTheme.ink)
                    Text("/ \(campus.weeklyGoal) bags")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(KnightTheme.muted)
                    Spacer()
                    Text("\(Int((progress * 100).rounded()))% of goal")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(KnightTheme.green)
                }
                BizProgressBar(progress: progress, tint: KnightTheme.green, height: 10)
            }
            .accessibilityElement(children: .combine)

            Divider().overlay(KnightTheme.line)

            HStack(alignment: .top, spacing: 0) {
                campusStat("\(campus.bagsAllTime.formatted())", "bags all time")
                campusStat(ImpactFormat.kg(campus.measuredKg + campus.estimatedKg), "food rescued")
                campusStat(ImpactFormat.kg(campus.co2eKg), "CO₂e avoided, est.")
            }
        }
        .bizCard()
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
        .accessibilityElement(children: .combine)
    }
}

private struct KnightOfTheWeekCard: View {
    let leader: LeagueEntry?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(alignment: .leading, spacing: 12) {
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

                if let leader {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(leader.isYou ? "\(leader.name) (you)" : leader.name)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text("\(leader.points) pt\(leader.points == 1 ? "" : "s")")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(KnightTheme.gold)
                    }
                }

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
