import SwiftUI

enum KnightTheme {
    static let gold = Color(red: 0.95, green: 0.74, blue: 0.17)
    static let goldDeep = Color(red: 0.76, green: 0.51, blue: 0.05)
    static let ink = Color(red: 0.10, green: 0.09, blue: 0.08)
    static let paper = Color(red: 0.97, green: 0.96, blue: 0.92)
    static let surface = Color.white
    static let muted = Color(red: 0.39, green: 0.37, blue: 0.33)
    static let line = Color(red: 0.88, green: 0.86, blue: 0.80)
    static let green = Color(red: 0.08, green: 0.43, blue: 0.28)
    static let red = Color(red: 0.69, green: 0.18, blue: 0.14)

    static let screenPadding: CGFloat = 20
    static let cardRadius: CGFloat = 24
    static let controlRadius: CGFloat = 16
}

extension View {
    func knightCardShadow() -> some View {
        shadow(color: KnightTheme.ink.opacity(0.08), radius: 18, x: 0, y: 8)
    }
}
