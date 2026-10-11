import SwiftUI

@main
struct KnightSaverApp: App {
    /// System, Light or Dark. Set by the moon button at the top right of Profile and Kitchen.
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system
    @Environment(\.scenePhase) private var scenePhase

    init() {
        AppAppearance.migrateLegacySetting()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .onAppear { appearance.apply() }
                .onChange(of: appearance) { _, newValue in newValue.apply() }
                // The window may not exist yet on first appear; re-apply once the scene is active.
                .onChange(of: scenePhase) { _, phase in if phase == .active { appearance.apply() } }
        }
    }
}
