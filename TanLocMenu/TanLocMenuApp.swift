import SwiftUI

@main
struct TanLocMenuApp: App {
    @StateObject private var store = SettingsStore()
    @StateObject private var arena = ArenaModel()

    init() { Theme.configureAppearance() }

    var body: some Scene {
        WindowGroup {
            ArenaView(model: arena, store: store)
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
        }
    }
}
