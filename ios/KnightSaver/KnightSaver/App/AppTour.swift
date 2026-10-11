import SwiftUI

// The app tour shown once after a new account is created (and again from Profile).
// It switches to the real tabs and outlines the real buttons, so people see the actual app,
// not screenshots. Flat scrim and a plain card: no blur or shadows.

/// Parts of the app the tour can point at. Views mark themselves with `.tourTarget(_:)`.
enum TourTarget: Hashable {
    case tab(AppTab)
    case scanPass
    case listSurplus
    case knightPass
}

struct TourTargetKey: PreferenceKey {
    static let defaultValue: [TourTarget: Anchor<CGRect>] = [:]

    static func reduce(value: inout [TourTarget: Anchor<CGRect>], nextValue: () -> [TourTarget: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// Lets the app tour find and outline this view.
    func tourTarget(_ target: TourTarget) -> some View {
        anchorPreference(key: TourTargetKey.self, value: .bounds) { [target: $0] }
    }
}

struct TourStep: Identifiable {
    let id = UUID()
    /// The tab shown behind the card.
    let tab: AppTab
    /// What to outline. Nil centers the card with nothing outlined.
    let target: TourTarget?
    let title: String
    let message: String
}

enum AppTour {
    static func steps(for account: AppAccount) -> [TourStep] {
        let firstName = account.displayName.split(separator: " ").first.map(String.init) ?? account.displayName
        switch account.role {
        case .student:
            return [
                TourStep(tab: .explore, target: nil,
                         title: "Welcome, \(firstName)!",
                         message: "Here's a quick look around KnightSaver. It takes half a minute, or skip it anytime."),
                TourStep(tab: .explore, target: .tab(.explore),
                         title: "Explore",
                         message: "Campus kitchens post their leftover food as Surprise Bags at a discount. Reserve one here before it's gone."),
                TourStep(tab: .profile, target: .knightPass,
                         title: "Your Knight Pass",
                         message: "Show it when you pick up. Staff scan it to hand over your bag, so there's no code to type."),
                TourStep(tab: .impact, target: .tab(.impact),
                         title: "Impact",
                         message: "Every bag you rescue adds up: food saved and CO₂e avoided. Ask EcoKnight AI what it means."),
                TourStep(tab: .rewards, target: .tab(.rewards),
                         title: "Rewards",
                         message: "Climb the Campus Rescue League and collect badges as you rescue more food."),
                TourStep(tab: .profile, target: .tab(.profile),
                         title: "Profile",
                         message: "Your pickups, settings and help. You can replay this tour from here anytime.")
            ]
        case .business:
            let kitchen = account.businessName.flatMap { $0.isEmpty ? nil : $0 } ?? firstName
            return [
                TourStep(tab: .business, target: nil,
                         title: "Welcome, \(kitchen)!",
                         message: "Here's how your Kitchen works. It takes half a minute, or skip it anytime."),
                TourStep(tab: .business, target: .scanPass,
                         title: "Scan Knight Pass",
                         message: "When a student arrives, scan the QR code on their Knight Pass. It checks the reservation and takes the payment."),
                TourStep(tab: .business, target: .listSurplus,
                         title: "List surplus",
                         message: "Say or type what's left. The AI proposes Surprise Bags, and nothing goes live until you approve."),
                TourStep(tab: .business, target: .tab(.business),
                         title: "Your Kitchen",
                         message: "Scroll down for current bags, reserved pickups, today's total and your impact report."),
                TourStep(tab: .profile, target: .tab(.profile),
                         title: "Profile",
                         message: "Business details and the most bags per listing. You can replay this tour from here.")
            ]
        }
    }
}

/// The tour on top of the app: a dark scrim with a cut-out around the target, a gold outline,
/// and a card with Skip and Next.
struct AppTourOverlay: View {
    let steps: [TourStep]
    let anchors: [TourTarget: Anchor<CGRect>]
    @Binding var index: Int
    let finishTitle: String
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var step: TourStep { steps[min(index, steps.count - 1)] }
    private var isLast: Bool { index >= steps.count - 1 }

    var body: some View {
        ZStack {
            // Scrim and outline cover the whole screen, safe areas included.
            GeometryReader { proxy in
                let hole = holeRect(in: proxy)
                ZStack {
                    SpotlightShape(hole: hole, cornerRadius: 20)
                        .fill(Color.black.opacity(0.66), style: FillStyle(eoFill: true))
                    if let hole {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(KnightTheme.gold, lineWidth: 3)
                            .frame(width: hole.width, height: hole.height)
                            .position(x: hole.midX, y: hole.midY)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { }
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)

            // The card stays inside the safe area, on the side away from the outline.
            GeometryReader { proxy in
                let hole = holeRect(in: proxy)
                let alignment: Alignment = {
                    guard let hole else { return .center }
                    return hole.midY > proxy.size.height * 0.5 ? .top : .bottom
                }()
                card
                    .padding(.horizontal, KnightTheme.screenPadding)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: index)
    }

    private func holeRect(in proxy: GeometryProxy) -> CGRect? {
        guard let target = step.target, let anchor = anchors[target] else { return nil }
        return proxy[anchor].insetBy(dx: -6, dy: -6)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                LeafSprig(color: KnightTheme.green, accent: KnightTheme.green, vein: KnightTheme.surface, size: 22)
                Text("\(index + 1) of \(steps.count)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(KnightTheme.muted)
                Spacer(minLength: 8)
                if !isLast {
                    Button("Skip tour", action: onFinish)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(KnightTheme.ink)
                        .frame(minHeight: 44)
                        .accessibilityHint("Closes the tour")
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(step.title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(KnightTheme.ink)
                Text(step.message)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(KnightTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .id(index)
            .accessibilityElement(children: .combine)

            HStack(spacing: 10) {
                StepDots(count: steps.count, index: index)
                Spacer(minLength: 8)
                if index > 0 {
                    Button {
                        index -= 1
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(KnightTheme.ink)
                            .frame(width: 48, height: 48)
                            .background(KnightTheme.wash, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back")
                }
                Button {
                    if isLast { onFinish() } else { index += 1 }
                } label: {
                    HStack(spacing: 7) {
                        Text(isLast ? finishTitle : "Next")
                        if !isLast { Image(systemName: "arrow.right") }
                    }
                    .lineLimit(1)
                    .fixedSize()
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(KnightTheme.onAccent)
                    .padding(.horizontal, 22)
                    .frame(minHeight: 48)
                    .background(KnightTheme.gold, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: KnightTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: KnightTheme.cardRadius, style: .continuous)
                .stroke(KnightTheme.line, lineWidth: 1)
        }
        .accessibilityAddTraits(.isModal)
    }
}

/// The whole screen with a rounded hole cut out (even-odd fill).
private struct SpotlightShape: Shape {
    var hole: CGRect?
    var cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        if let hole {
            path.addRoundedRect(in: hole, cornerSize: CGSize(width: cornerRadius, height: cornerRadius), style: .continuous)
        }
        return path
    }
}

private struct StepDots: View {
    let count: Int
    let index: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { dot in
                Capsule()
                    .fill(dot == index ? KnightTheme.green : KnightTheme.line)
                    .frame(width: dot == index ? 18 : 7, height: 7)
            }
        }
        .accessibilityHidden(true)
    }
}

/// "Take the tour" row for Profile, above Sign out.
struct TourReplayButton: View {
    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        Button {
            sessionStore.showsTour = true
        } label: {
            HStack(spacing: 12) {
                LeafSprig(color: KnightTheme.green, accent: KnightTheme.green, vein: KnightTheme.greenWash, size: 18)
                    .frame(width: 36, height: 36)
                    .background(KnightTheme.greenWash, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                Text("Take the tour")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(KnightTheme.ink)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(KnightTheme.muted)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 58)
            .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: KnightTheme.controlRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: KnightTheme.controlRadius, style: .continuous)
                    .stroke(KnightTheme.line, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows the main parts of the app again")
    }
}
