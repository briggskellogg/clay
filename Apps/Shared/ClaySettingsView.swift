import SwiftUI

struct ClaySettingsView: View {
    @AppStorage(ClayAppearance.storageKey) private var appearance: ClayAppearance = .system
    #if os(iOS)
    @Environment(\.dismiss) private var dismiss
    #endif

    var body: some View {
        #if os(macOS)
        settingsForm
            .formStyle(.grouped)
            .frame(width: 420)
            .fixedSize(horizontal: false, vertical: true)
        #else
        NavigationStack {
            settingsForm
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
        }
    }

    private var brandHeader: some View {
        HStack(spacing: 12) {
            Image("ClayMark")
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Clay")
                    .font(ClayTheme.uiFont(size: 22, weight: .bold))
                    .foregroundStyle(ClayTheme.ink)
                Text("by Briggs Kellogg")
                    .font(ClayTheme.uiFont(size: 13))
                    .foregroundStyle(ClayTheme.secondary)
                Text(versionLabel)
                    .font(ClayTheme.uiFont(size: 11))
                    .foregroundStyle(ClayTheme.secondary)
            }
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
