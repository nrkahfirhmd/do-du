import SwiftUI

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha)
    }

    static func dynamic(light: Color, dark: Color) -> Color {
        #if canImport(UIKit)
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light) })
        #else
        Color(
            NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil ? NSColor(dark) : NSColor(light)
            })
        #endif
    }
}

enum DD {
    // MARK: Brand
    static let mint = Color(hex: 0x89D7B7)
    /// Forest that never adapts: text and glyphs on mint.
    static let onMint = Color(hex: 0x1A312C)
    /// Forest as ink: titles, selected text.
    static let forest = Color.dynamic(light: Color(hex: 0x1A312C), dark: Color(hex: 0xE3F1EB))
    /// Forest as a fill: recording hero, primary buttons, selected tab. Text on it is white.
    static let forestFill = Color.dynamic(light: Color(hex: 0x1A312C), dark: Color(hex: 0x22453C))
    static let sage = Color.dynamic(light: Color(hex: 0x428475), dark: Color(hex: 0x7CC2AE))

    // MARK: Neutrals
    static let page = Color.dynamic(light: .white, dark: Color(hex: 0x0B1110))
    static let surface = Color.dynamic(light: Color(hex: 0xF3F6F5), dark: Color(hex: 0x161E1C))
    static let fill = Color.dynamic(light: Color(hex: 0xE5EBE9), dark: Color(hex: 0x24302C))
    static let disabled = Color.dynamic(light: Color(hex: 0xC3CCC9), dark: Color(hex: 0x3A4542))
    static let ink = Color.dynamic(light: Color(hex: 0x17201E), dark: Color(hex: 0xEEF3F1))
    static let ink3 = Color.dynamic(light: Color(hex: 0x66716E), dark: Color(hex: 0x9AA6A2))
    static let separator = Color.dynamic(light: Color(hex: 0x1A312C, alpha: 0.12), dark: Color(white: 1, opacity: 0.12))
    static let track = Color.dynamic(light: Color(hex: 0x1A312C, alpha: 0.10), dark: Color(white: 1, opacity: 0.12))
    static let sheetButton = Color.dynamic(light: Color(hex: 0xEEF2F1), dark: Color(hex: 0x26302D))

    // MARK: Status
    static let danger = Color.dynamic(light: Color(hex: 0xC4314B), dark: Color(hex: 0xFF6F84))
    static let runningRow = Color.dynamic(light: Color(hex: 0x89D7B7, alpha: 0.40), dark: Color(hex: 0x89D7B7, alpha: 0.20))
    static let onDarkFill = Color(white: 1, opacity: 0.12)
    static let onDarkRule = Color(white: 1, opacity: 0.14)

    // MARK: Radii (continuous corners)
    enum Radius {
        static let bar: CGFloat = 10, menu: CGFloat = 16, group: CGFloat = 20
        static let card: CGFloat = 24, tile: CGFloat = 30, sheet: CGFloat = 38, hero: CGFloat = 42
    }

    // MARK: Motion (no bounce)
    static let colorChange = Animation.easeInOut(duration: 0.4)
    static let fillChange = Animation.easeInOut(duration: 0.6)
    static let listChange = Animation.easeInOut(duration: 0.25)
    static let hover = Animation.easeOut(duration: 0.15)
}

extension Font {
    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    static let ddClock = rounded(84)
    static let ddClockMac = rounded(128)
    static let ddTitle2 = rounded(28)
    static let ddTitle3 = rounded(20)
    static let ddStat = rounded(24)
    static let ddStatLG = rounded(34)
    static let ddStatXL = rounded(36)
    static let ddHeadlineRounded = rounded(17, .bold)
    static let ddOverline = rounded(12, .heavy)
    static let ddCaption = rounded(11, .bold)
}

extension Shape where Self == RoundedRectangle {
    static func dd(_ radius: CGFloat) -> RoundedRectangle { RoundedRectangle(cornerRadius: radius, style: .continuous) }
}

#if canImport(UIKit)
extension DD {
    /// Navigation titles in SF Rounded heavy, forest (UIKit appearance; SwiftUI has no API for it).
    static func applyAppearance() {
        func rounded(_ size: CGFloat, _ weight: UIFont.Weight) -> UIFont {
            let base = UIFont.systemFont(ofSize: size, weight: weight)
            return base.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: size) } ?? base
        }
        let ink = UIColor(DD.forest)
        let bar = UINavigationBar.appearance()
        bar.largeTitleTextAttributes = [.font: rounded(38, .heavy), .foregroundColor: ink, .kern: -0.6]
        bar.titleTextAttributes = [.font: rounded(17, .bold), .foregroundColor: ink]
    }
}
#endif
