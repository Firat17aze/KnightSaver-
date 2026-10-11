import SwiftUI

/// The Impact tab (student.md "Impact"): EcoKnight on top, then UCF's weekly goal,
/// the student's verified impact and recent rescues.
/// Knight of the Week, the Campus Rescue League and the Reward Road live in the Rewards tab.
struct ImpactView: View {
    let student: KnightPass

    @EnvironmentObject var businessStore: BusinessStore
    @AppStorage("knightsaver.league.joined") private var leagueJoined = true
    @AppStorage("knightsaver.league.nickname") private var storedNickname = ""
    /// Feedback for demo-history rescues (live ones go to the Kitchen store).
    @AppStorage("knightsaver.impact.ratedCodes") private var ratedCodes = ""
    @State private var sheet: ImpactSheet?
    /// Recent rescues shown; "Show more" adds the next few.
    @State private var visibleRescues = Self.rescuesPerPage

    private static let rescuesPerPage = 3

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
                    EcoKnightAskBar(stats: EcoStats(summary: summary, rescues: rescues, leagueNickname: leagueJoined ? nickname : nil))

                    CampusGoalCard(studentBagsThisWeek: summary.weeklyBags(weeks: 1).first ?? 0)

                    youSection(summary: summary)
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
        VStack(alignment: .leading, spacing: 10) {
            YourImpactCard(summary: summary)
            NavigationLink {
                CO2eMethodView(summary: summary)
            } label: {
                Label("How is CO₂e estimated?", systemImage: "info.circle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(KnightTheme.lake)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }

        let all = rescues
        let recent = Array(all.prefix(visibleRescues))
        if recent.isEmpty {
            FirstRescueCard()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                BizSectionHeader(title: "Recent rescues", trailing: "\(all.count) total")
                VStack(spacing: 0) {
                    ForEach(Array(recent.enumerated()), id: \.element.id) { index, rescue in
                        RescueRow(rescue: rescue)
                        if index < recent.count - 1 { Divider().overlay(KnightTheme.line).padding(.leading, 64) }
                    }
                    if all.count > Self.rescuesPerPage {
                        Divider().overlay(KnightTheme.line)
                        Button {
                            withAnimation(.easeOut(duration: 0.2)) {
                                visibleRescues = recent.count < all.count ? visibleRescues + Self.rescuesPerPage : Self.rescuesPerPage
                            }
                        } label: {
                            Text(recent.count < all.count ? "Show \(min(Self.rescuesPerPage, all.count - recent.count)) more" : "Show less")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(KnightTheme.ink)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listCard()
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

private extension View {
    /// White rounded container for list rows (league, earlier rescues).
    func listCard() -> some View {
        background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(KnightTheme.line, lineWidth: 1)
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
            Spacer(minLength: 0)
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

// MARK: - How CO₂e is estimated

/// Explains the CO₂e numbers: the food weight, the factor and its source, a worked example and
/// the limits. Opened from Impact and from Profile › Help.
struct CO2eMethodView: View {
    /// The student's own totals, for a line with their numbers. Nil shows only the example.
    var summary: StudentImpactSummary?

    private var factor: Double { ImpactRules.co2ePerFoodKg }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Food weight × \(formatted(factor)) = kg CO₂e avoided")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(KnightTheme.ink)
                    Text("Every CO₂e number in KnightSaver comes from this one calculation, and only for pickups staff verified.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(KnightTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    if let summary, summary.bags > 0 {
                        Divider().overlay(KnightTheme.line)
                        Text("You: \(ImpactFormat.kg(summary.foodKg)) of food × \(formatted(factor)) ≈ \(ImpactFormat.kg(summary.co2eKg)) CO₂e")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(KnightTheme.green)
                    }
                }
                .bizCard()

                section("1. The food weight",
                        "When staff weigh a bag at pickup, that weight is used and marked as weighed. Otherwise we estimate \(formatted(BusinessRules.estimatedKgPerItem)) kg per item, about \(formatted(ImpactRules.estimatedKgPerBag)) kg for a typical 3-item bag. That per-item weight is our own assumption, not a measurement, which is why estimated numbers say \u{201C}Est.\u{201D}")
                section("2. The CO₂e factor",
                        "Each kilogram of food counts as \(formatted(factor)) kg of CO₂e. This is the world average footprint of food that goes to waste: the FAO estimates about 3.3 billion tonnes of CO₂e for about 1.3 billion tonnes of food wasted a year. It covers growing, processing, transporting and storing the food, but not changes in land use.")
                section("3. An example",
                        "One Surprise Bag with 3 items: 3 × \(formatted(BusinessRules.estimatedKgPerItem)) kg = \(formatted(ImpactRules.estimatedKgPerBag)) kg of food. \(formatted(ImpactRules.estimatedKgPerBag)) kg × \(formatted(factor)) ≈ \(formatted(ImpactRules.estimatedKgPerBag * factor)) kg CO₂e.")
                section("What this doesn't tell you",
                        "It's an average, not your bag's real footprint: meat and dairy have a much larger footprint than bread or pastries, so a bakery bag is likely below the average and a sandwich with meat above it. It also counts the food's footprint as avoided once it's eaten instead of thrown away, without subtracting your trip to pick it up. Treat the numbers as a fair estimate of the right size, not a measurement.")

                Text("Source: FAO (2013), Food Wastage Footprint: Impacts on Natural Resources.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(KnightTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(KnightTheme.screenPadding)
            .padding(.bottom, 24)
        }
        .background(KnightTheme.paper)
        .navigationTitle("How CO₂e is estimated")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(KnightTheme.ink)
            Text(body)
                .font(.system(size: 15))
                .foregroundStyle(KnightTheme.muted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 2.5, 0.45, 1.1: no trailing zeros.
    private func formatted(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }
}
