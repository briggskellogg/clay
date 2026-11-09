import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

struct ClaySettingsView: View {
    @ObservedObject var store: ClayStore
    @State private var choosingLibrary = false
    @AppStorage(ClayAppearance.storageKey) private var appearance: ClayAppearance = .system
    #if os(iOS)
    @Environment(\.dismiss) private var dismiss
    #endif

    var body: some View {
        #if os(macOS)
        settingsContent
            .formStyle(.grouped)
            .frame(width: 460, height: 620)
        #else
        NavigationStack {
            settingsContent
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .tint(ClayTheme.blue)
        #endif
    }

    private var settingsContent: some View {
        settingsForm
            .safeAreaInset(edge: .bottom, spacing: 0) {
                HStack {
                    Spacer(minLength: 0)
                    ClayMakerMark()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(ClayTheme.sidebar)
            }
    }

    private var settingsForm: some View {
        Form {
            Section {
                brandHeader
            }
            Section {
                Picker("Color scheme", selection: $appearance) {
                    ForEach(ClayAppearance.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                #if os(macOS)
                .pickerStyle(.segmented)
                #else
                .pickerStyle(.inline)
                #endif
            } header: {
                Text("Appearance")
            } footer: {
                Text("System follows your device’s appearance.")
            }
            Section {
                LabeledContent("Storage", value: store.syncFolderName ?? "This device")
                Text(store.syncStatus)
                    .font(.footnote)
                    .foregroundStyle(ClayTheme.secondary)
                    .accessibilityLabel("Library sync: " + store.syncStatus)
                if store.isLibraryConnected {
                    Text(store.syncDetail)
                        .font(.caption)
                        .foregroundStyle(ClayTheme.secondary)
                }
                Button(store.isLibraryConnected ? "Change iCloud Drive folder…" : "Choose iCloud Drive folder…") {
                    choosePrivateFolder()
                }
                .disabled(store.isSyncing || store.isConnectingLibrary)
                if store.isLibraryConnected {
                    HStack {
                        Button("Sync Now") { store.requestSync() }
                        Spacer()
                        Button("Disconnect") { Task { await store.disconnectLibraryFolder() } }
                    }
                    .disabled(store.isSyncing || store.isConnectingLibrary)
                }
            } header: {
                Text("Private library")
            } footer: {
                Text("Choose the same dedicated Clay folder in personal iCloud Drive on your devices. Connecting adds this device’s writing to that private library and keeps the originals here. Offline edits stay saved locally. Windows can read the shared Markdown copies. GitHub contains only app source.")
            }
        }
        #if os(iOS)
        .fileImporter(isPresented: $choosingLibrary, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { Task { await store.connectLibraryFolder(url) } }
            case .failure(let error):
                store.errorMessage = "Couldn’t choose the private library folder. " + error.localizedDescription
            }
        }
        #endif
    }

    private func choosePrivateFolder() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.title = "Connect Private Clay Library"
        panel.message = "Choose the dedicated Clay folder in personal iCloud Drive. This device’s writing will be added to that library."
        panel.prompt = "Connect"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        // Coordinated reads download cloud items after the directory is chosen.
        panel.canDownloadUbiquitousContents = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in await store.connectLibraryFolder(url) }
        }
        #else
        choosingLibrary = true
        #endif
    }

    private var brandHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            ClayBrandSignature()
            Text(versionLabel)
                .font(ClayTheme.uiFont(size: 11))
                .foregroundStyle(ClayTheme.secondary)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var versionLabel: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        if let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
            return "Version \(version) (\(build))"
        }
        return "Version \(version)"
    }
}

/// The app symbol and typeset name share the same compact family treatment.
@MainActor
struct ClayBrandSignature: View {
    var symbolSize: CGFloat = 26
    var nameSize: CGFloat = 20

    var body: some View {
        HStack(spacing: 8) {
            Image("ClayMark")
                .resizable()
                .renderingMode(.original)
                .interpolation(.high)
                .scaledToFit()
                .frame(width: symbolSize, height: symbolSize)
                .accessibilityHidden(true)
            Text("Clay")
                .font(ClayTheme.uiFont(size: nameSize, weight: .bold))
                .foregroundStyle(ClayTheme.ink)
                .fixedSize()
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Clay")
    }
}

/// Exact supplied gold artwork, kept separate from Clay's own symbol.
@MainActor
struct ClayMakerMark: View {
    var body: some View {
        Image("MakerMark")
            .resizable()
            .renderingMode(.original)
            .interpolation(.high)
            .scaledToFit()
            .frame(width: 14, height: 18)
            .accessibilityLabel("Made by Briggs Kellogg")
            #if os(macOS)
            .help("Made by Briggs Kellogg")
            #endif
    }
}
