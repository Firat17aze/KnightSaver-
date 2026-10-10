import SwiftUI
import UIKit

enum KnightTheme {
    // Each color has a light and a dark value. The app picks one from the dark mode switch
    // (moon button, top right of Business), stored in AppStorage "knightsaver.darkMode".
    static let gold = Color(red: 0.95, green: 0.74, blue: 0.17)
    static let goldDeep = dynamic(light: (0.76, 0.51, 0.05), dark: (0.89, 0.65, 0.18))
    static let ink = dynamic(light: (0.10, 0.09, 0.08), dark: (0.96, 0.94, 0.90))
    static let paper = dynamic(light: (0.97, 0.96, 0.92), dark: (0.075, 0.07, 0.06))
    static let surface = dynamic(light: (1.0, 1.0, 1.0), dark: (0.135, 0.125, 0.11))
    static let muted = dynamic(light: (0.39, 0.37, 0.33), dark: (0.68, 0.65, 0.59))
    static let line = dynamic(light: (0.88, 0.86, 0.80), dark: (0.25, 0.23, 0.20))
    static let green = dynamic(light: (0.08, 0.43, 0.28), dark: (0.38, 0.78, 0.56))
    static let red = dynamic(light: (0.69, 0.18, 0.14), dark: (0.95, 0.47, 0.40))

    /// Text and icons on gold. Stays dark in both modes so gold buttons stay readable.
    static let onAccent = Color(red: 0.10, green: 0.09, blue: 0.08)
    /// Surfaces that stay dark in both modes (toasts, camera frame, the K mark).
    static let night = Color(red: 0.10, green: 0.09, blue: 0.08)
    /// Card shadow: soft ink in light mode, deeper black in dark mode.
    static let shadow = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0, alpha: 0.45)
            : UIColor(red: 0.10, green: 0.09, blue: 0.08, alpha: 0.08)
    })

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

extension View {
    func knightCardShadow() -> some View {
        shadow(color: KnightTheme.shadow, radius: 18, x: 0, y: 8)
    }

    /// Keeps a view in light colors even in dark mode (QR faces, white chips).
    func alwaysLight() -> some View {
        environment(\.colorScheme, .light)
    }
}
