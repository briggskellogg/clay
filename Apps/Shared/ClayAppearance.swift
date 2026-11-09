import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum ClayAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    static let storageKey = "clay.appearance"
    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    #if os(macOS)
    @MainActor func apply() {
        switch self {
        case .system: NSApplication.shared.appearance = nil
        case .light: NSApplication.shared.appearance = NSAppearance(named: .aqua)
        case .dark: NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        }
    }
    #else
    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }
    #endif
}

private struct ClayAppearanceModifier: ViewModifier {
    @AppStorage(ClayAppearance.storageKey) private var appearance: ClayAppearance = .system

    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .onChange(of: appearance, initial: true) { _, value in
                value.apply()
            }
        #else
        content.background {
            ClayWindowAppearance(style: appearance.interfaceStyle)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
        #endif
    }
}

extension View {
    func clayAppearance() -> some View {
        modifier(ClayAppearanceModifier())
    }
}

#if os(iOS)
// A window override also styles native editors and presented content. Returning
// to .unspecified clears the override immediately and resumes device changes.
private struct ClayWindowAppearance: UIViewRepresentable {
    let style: UIUserInterfaceStyle

    func makeUIView(context: Context) -> AppearanceView {
        let view = AppearanceView()
        view.isUserInteractionEnabled = false
        view.style = style
        return view
    }

    func updateUIView(_ uiView: AppearanceView, context: Context) {
        uiView.style = style
    }

    final class AppearanceView: UIView {
        var style: UIUserInterfaceStyle = .unspecified {
            didSet { apply() }
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            apply()
        }

        private func apply() {
            guard let window, window.overrideUserInterfaceStyle != style else { return }
            window.overrideUserInterfaceStyle = style
        }
    }
}
#endif
