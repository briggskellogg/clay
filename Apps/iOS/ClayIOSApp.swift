#if os(iOS)
import SwiftUI

@main
@MainActor
struct ClayIOSApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store: ClayStore
    @StateObject private var lifecycle = ClayIOSLifecycle()

    init() {
        ClayTheme.registerFonts()
        _store = StateObject(wrappedValue: ClayStore())
    }

    var body: some Scene {
        WindowGroup {
            ClayIOSLibraryView(store: store)
                .tint(ClayTheme.blue)
                .onChange(of: scenePhase) { _, phase in
                    lifecycle.scenePhaseChanged(to: phase, store: store)
                }
        }
    }
}
#endif
