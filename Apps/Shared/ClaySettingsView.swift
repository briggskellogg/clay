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
}
