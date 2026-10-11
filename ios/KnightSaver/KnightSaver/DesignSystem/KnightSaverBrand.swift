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

/// "KnightSaver" with the logo on its left, on the sign-in screen. The tabs inside the app
/// start with their own page title instead.
struct KnightSaverBrandBar: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            KnightSaverLogo(size: 36)
            // Plain flat colors, no shadow or effects: pure black/white and UCF gold.
            HStack(spacing: 0) {
                Text("Knight")
                    .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
                Text("Saver")
                    .foregroundStyle(KnightTheme.gold)
            }
            .font(.system(size: 23, weight: .bold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("KnightSaver")
        .accessibilityAddTraits(.isHeader)
    }
}
