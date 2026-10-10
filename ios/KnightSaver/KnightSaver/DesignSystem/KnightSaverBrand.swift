import SwiftUI

/// The KnightSaver mark: a gold knight's helm with a plume of fresh leaves.
/// Vector asset "KnightSaverMark" (PDF), so it stays sharp at any size.
struct KnightSaverLogo: View {
    var size: CGFloat = 36
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Image("KnightSaverMark")
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .overlay {
                // The tile is dark, so give it a faint edge on dark backgrounds.
                RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }
}

/// "KnightSaver" with the logo on its left. Sits at the very top of every tab.
/// Optional trailing content (for example the dark mode button on Business).
struct KnightSaverBrandBar<Trailing: View>: View {
    private let trailing: Trailing

    init(@ViewBuilder trailing: () -> Trailing) {
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            HStack(spacing: 10) {
                KnightSaverLogo(size: 36)
                HStack(spacing: 0) {
                    Text("Knight")
                        .foregroundStyle(KnightTheme.ink)
                    Text("Saver")
                        .foregroundStyle(KnightTheme.goldDeep)
                }
                .font(.system(size: 24, weight: .black, design: .rounded))
                .tracking(-0.3)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("KnightSaver")
            .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 8)

            trailing
        }
        .frame(minHeight: 44)
    }
}

extension KnightSaverBrandBar where Trailing == EmptyView {
    init() {
        self.init { EmptyView() }
    }
}
