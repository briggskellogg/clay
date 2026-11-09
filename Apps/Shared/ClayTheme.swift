import SwiftUI
import CoreText
import ClayCore
#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum ClayTheme {
    static let paper = adaptive(0xFFFFFF, 0x191B21)
    static let sidebar = adaptive(0xF4F5F7, 0x212329)
    static let ink = adaptive(0x30343B, 0xEFF0F4)
    static let secondary = adaptive(0x707785, 0xA6ADB9)
    static let rule = adaptive(0xE7E9EE, 0x343841)
    static let blue = adaptive(0x3676ED, 0x7EA7FF)
    static let amber = adaptive(0xC18A16, 0xEFBD55)
    static let selection = adaptive(0xEAEFF5, 0x2E323B)
    static let red = Color(red: 1, green: 0.251, blue: 0.329)

    static func bodyFont(size: CGFloat = 22) -> Font {
        .custom("PPNeueYork-NormalLight", size: size, relativeTo: .body)
    }

    static func uiFont(size: CGFloat = 15, weight: Font.Weight = .regular) -> Font {
        let bold = weight == .bold || weight == .semibold || weight == .heavy || weight == .black
        return .custom(bold ? "PPNeueMontreal-Bold" : "PPNeueMontreal-Regular", size: size)
    }

    @MainActor private static var fontsRegistered = false

    @MainActor static func registerFonts() {
        guard !fontsRegistered else { return }
        fontsRegistered = true
        for (name, ext) in [("PPNeueMontreal-Regular", "ttf"),
                            ("PPNeueMontreal-Bold", "ttf"),
                            ("PPNeueYork-NormalLight", "otf")] {
            let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Fonts")
                ?? Bundle.main.url(forResource: name, withExtension: ext)
            if let url {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }

    private static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        #if os(macOS)
        return Color(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                           green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        })
        #else
        return Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                           green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        })
        #endif
    }
}

struct SectionSymbol: View {
    let section: WritingSection
    var size: CGFloat = 22

    var body: some View {
        Image(systemName: section == .scratchpads ? "doc.text.fill" : "book.closed.fill")
            .symbolRenderingMode(.hierarchical)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(section == .scratchpads ? ClayTheme.amber : ClayTheme.blue)
            .accessibilityHidden(true)
    }
}

enum EditorTypeface: String, CaseIterable, Identifiable {
    case serif, mono, sans
    var id: String { rawValue }
    var title: String {
        switch self {
        case .serif: return "Serif"
        case .mono: return "Monospace"
        case .sans: return "Sans serif"
        }
    }
    func font(size: CGFloat) -> Font {
        switch self {
        case .serif: return ClayTheme.bodyFont(size: size)
        case .mono: return .system(size: size, design: .monospaced)
        case .sans: return ClayTheme.uiFont(size: size)
        }
    }
}
