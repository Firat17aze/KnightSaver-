import SwiftUI
import UIKit

enum KnightTheme {
    // Each color has a light and a dark value, picked from the appearance setting
    // (AppAppearance: System, Light or Dark), set by the moon button on Profile and Kitchen.
    static let gold = Color(red: 0.95, green: 0.74, blue: 0.17)
    static let goldDeep = dynamic(light: (0.76, 0.51, 0.05), dark: (0.89, 0.65, 0.18))
    static let ink = dynamic(light: (0.10, 0.09, 0.08), dark: (0.96, 0.94, 0.90))
    static let paper = dynamic(light: (0.965, 0.96, 0.945), dark: (0.075, 0.07, 0.06))
    static let surface = dynamic(light: (1.0, 1.0, 1.0), dark: (0.135, 0.125, 0.11))
    static let muted = dynamic(light: (0.39, 0.37, 0.33), dark: (0.68, 0.65, 0.59))
    static let line = dynamic(light: (0.88, 0.87, 0.84), dark: (0.25, 0.23, 0.20))
    static let green = dynamic(light: (0.08, 0.43, 0.28), dark: (0.38, 0.78, 0.56))
    static let red = dynamic(light: (0.69, 0.18, 0.14), dark: (0.95, 0.47, 0.40))

    // Supporting colors, so gold can mean "act" (primary buttons, selected tab) and UCF itself.
    /// Florida citrus: urgency and heat (low stock, streaks, countdowns).
    static let citrus = dynamic(light: (0.74, 0.33, 0.04), dark: (0.98, 0.62, 0.30))
    /// Lake Claire blue: information and place (pickup location, times).
    static let lake = dynamic(light: (0.12, 0.40, 0.64), dark: (0.47, 0.71, 0.95))
    /// Neutral tile behind plain icons, in place of gold tints.
    static let wash = dynamic(light: (0.93, 0.925, 0.905), dark: (0.19, 0.18, 0.16))
    /// League podium: second and third place next to gold.
    static let silver = Color(red: 0.76, green: 0.78, blue: 0.81)
    static let bronze = Color(red: 0.82, green: 0.55, blue: 0.33)

    /// Text and icons on gold. Stays dark in both modes so gold buttons stay readable.
    static let onAccent = Color(red: 0.10, green: 0.09, blue: 0.08)
    /// Surfaces that stay dark in both modes (toasts, camera frame, the K mark).
    static let night = Color(red: 0.10, green: 0.09, blue: 0.08)

    static let screenPadding: CGFloat = 20
    static let cardRadius: CGFloat = 24
    static let controlRadius: CGFloat = 16

    private static func dynamic(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
        Color(uiColor: UIColor { traits in
            let c = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
    }
}

/// App-wide appearance. "System" follows the iPhone's Light/Dark setting.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    static let storageKey = "knightsaver.appearance"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }

    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }

    /// Applies the style to every window, so sheets and alerts follow it too.
    /// (preferredColorScheme(nil) doesn't reliably switch back to System.)
    func apply() {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = interfaceStyle
            }
        }
    }

    /// The old Kitchen switch stored a Bool; carry an "on" over as Dark.
    static func migrateLegacySetting(_ defaults: UserDefaults = .standard) {
        guard defaults.object(forKey: storageKey) == nil,
              defaults.object(forKey: "knightsaver.darkMode") != nil else { return }
        defaults.set(defaults.bool(forKey: "knightsaver.darkMode") ? AppAppearance.dark.rawValue : AppAppearance.system.rawValue, forKey: storageKey)
        defaults.removeObject(forKey: "knightsaver.darkMode")
    }
}

/// Moon button for the top right of Profile and Kitchen. Tap switches between light and dark;
/// long press offers "Match iPhone" to follow the system setting again.
struct ThemeToggleButton: View {
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let isDark = colorScheme == .dark
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                appearance = isDark ? .light : .dark
            }
        } label: {
            Image(systemName: isDark ? "moon.fill" : "moon")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isDark ? KnightTheme.onAccent : KnightTheme.ink)
                .frame(width: 44, height: 44)
                .background(isDark ? KnightTheme.gold : KnightTheme.surface, in: Circle())
                .overlay {
                    Circle().stroke(KnightTheme.line, lineWidth: isDark ? 0 : 1)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                appearance = .system
            } label: {
                Label("Match iPhone", systemImage: AppAppearance.system.icon)
            }
        }
        .accessibilityLabel("Dark mode")
        .accessibilityValue(isDark ? "On" : "Off")
        .accessibilityHint("Switches the whole app between light and dark")
    }
}

extension View {
    /// Keeps a view in light colors even in dark mode (QR faces, white chips).
    func alwaysLight() -> some View {
        environment(\.colorScheme, .light)
    }
}

/// Height of the floating tab bar, measured by RootView. Scrolling screens read it so their
/// last items can scroll clear of the bar.
private struct TabBarInsetKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var tabBarInset: CGFloat {
        get { self[TabBarInsetKey.self] }
        set { self[TabBarInsetKey.self] = newValue }
    }
}

private struct ReservesTabBarSpace: ViewModifier {
    @Environment(\.tabBarInset) private var tabBarInset

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear
                .frame(height: tabBarInset)
                .allowsHitTesting(false)
        }
    }
}

extension View {
    /// Apply to a tab's scroll view (and to screens pushed inside a tab) so content can scroll
    /// above the floating tab bar. NavigationStack doesn't pass an outer inset down to its pages.
    func reservesTabBarSpace() -> some View {
        modifier(ReservesTabBarSpace())
    }
}
