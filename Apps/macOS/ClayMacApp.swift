import SwiftUI

@main
@MainActor
struct ClayMacApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @NSApplicationDelegateAdaptor(ClayMacAppDelegate.self) private var appDelegate
    @StateObject private var store: ClayStore
    @StateObject private var actions = ClayMacActions()

    init() {
        ClayTheme.registerFonts()
        _store = StateObject(wrappedValue: ClayStore())
    }

    var body: some Scene {
        Window("Clay", id: "library") {
            ClayMacLibraryView(store: store, actions: actions)
                .clayAppearance()
                .frame(minWidth: 900, minHeight: 600)
                .onAppear {
                    appDelegate.configure(store: store, actions: actions)
                    store.setSyncActive(true)
                }
                .onChange(of: scenePhase) { _, phase in
                    store.setSyncActive(phase == .active)
                }
        }
        .defaultSize(width: 1180, height: 800)
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unified)
        .commands {
            ClayMacCommands(store: store, actions: actions)
        }

        Settings {
            ClaySettingsView(store: store)
                .clayAppearance()
        }
    }
}
