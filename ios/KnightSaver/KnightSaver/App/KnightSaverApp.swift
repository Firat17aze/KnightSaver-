import SwiftUI

@main
struct KnightSaverApp: App {
    /// Set by the moon button at the top right of Business.
    @AppStorage("knightsaver.darkMode") private var darkMode = false

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(darkMode ? .dark : .light)
        }
    }
}
