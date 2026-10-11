import SwiftUI

/// The Impact tab, split in two so each half reads on its own (student.md "Impact"):
/// "You" is verified personal impact and recent rescues; "Campus" is UCF's weekly goal.
/// Knight of the Week and the Campus Rescue League live in the Rewards tab.
struct ImpactView: View {
    let student: KnightPass

    @EnvironmentObject var businessStore: BusinessStore
    @AppStorage("knightsaver.league.joined") private var leagueJoined = true
    @AppStorage("knightsaver.league.nickname") private var storedNickname = ""
    /// Feedback for demo-history rescues (live ones go to the Kitchen store).
    @AppStorage("knightsaver.impact.ratedCodes") private var ratedCodes = ""
    @State private var section: ImpactSection = .you
    @State private var sheet: ImpactSheet?

    private enum ImpactSection: String, CaseIterable, Identifiable {
        case you = "You"
        case campus = "Campus"
        var id: String { rawValue }
    }

    private enum ImpactSheet: Identifiable {
        case feedback(StudentRescue)

        var id: String {
            switch self {
            case .feedback(let rescue): return "feedback-\(rescue.id.uuidString)"
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
