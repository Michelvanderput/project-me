import SwiftUI

/// Design tokens voor Project Me.
/// Rustig, warm, weinig prikkels. Volgt Apple HIG: systeemtypografie met Dynamic Type,
/// minimaal 44pt touch targets, kleuren met voldoende contrast in licht én donker.
enum Theme {
    // MARK: Kleuren
    enum Palette {
        /// Hoofdaccent: zachte terracotta-roos.
        static let accent = Color(light: 0xC9645A, dark: 0xF0A08F)
        /// Ochtend: abrikoos / dageraad.
        static let dawn = Color(light: 0xE8925E, dark: 0xF4B183)
        static let dawnSoft = Color(light: 0xFCE6D4, dark: 0x3A2A22)
        /// Avond: lavendel / schemering.
        static let dusk = Color(light: 0x6E62B6, dark: 0xB3A9F0)
        static let duskSoft = Color(light: 0xE7E3F8, dark: 0x25223D)
        /// Water.
        static let water = Color(light: 0x2E8FBF, dark: 0x7CCBEB)
        static let waterSoft = Color(light: 0xDDF1FA, dark: 0x16303D)
        /// Lichaam & oefeningen: salie.
        static let sage = Color(light: 0x4F8A6B, dark: 0x9BD1B2)
        static let sageSoft = Color(light: 0xE1F0E7, dark: 0x1D3328)
        /// Motivatie: roos.
        static let rose = Color(light: 0xC2557A, dark: 0xF2A3BF)
        static let roseSoft = Color(light: 0xF9E1EA, dark: 0x3A2030)

        static let canvas = Color(light: 0xFBF8F4, dark: 0x111014)
        static let surface = Color(light: 0xFFFFFF, dark: 0x1C1B21)
        static let surfaceRaised = Color(light: 0xF4EFE9, dark: 0x26252C)
        static let ink = Color(light: 0x23201D, dark: 0xF3EFEA)
        static let inkSecondary = Color(light: 0x6B635B, dark: 0xB4ACA4)

        /// Kleur voor een pijnscore 0...10 (salie → abrikoos → roos).
        static func pain(_ value: Int) -> Color {
            switch value {
            case ...2: sage
            case 3...5: dawn
            default: rose
            }
        }
    }

    // MARK: Ruimte (4pt-grid)
    enum Space {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        /// Zijmarge van schermen.
        static let gutter: CGFloat = 20
    }

    // MARK: Rondingen
    enum Radius {
        static let small: CGFloat = 12
        static let control: CGFloat = 18
        static let card: CGFloat = 26
        static let sheet: CGFloat = 34
    }

    // MARK: Beweging (150–300 ms voor feedback, 300–500 ms voor overgangen)
    enum Motion {
        static let quick: Animation = .snappy(duration: 0.2)
        static let standard: Animation = .smooth(duration: 0.3)
        static let gentle: Animation = .spring(duration: 0.45, bounce: 0.18)
        static let breathe: Animation = .easeInOut(duration: 4)
    }

    static let minTouchTarget: CGFloat = 44
}

extension Color {
    /// Adaptieve kleur uit twee hex-waarden.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension Font {
    /// Serif voor het boekje en citaten: rustig en persoonlijk.
    static func journal(_ style: Font.TextStyle = .body) -> Font {
        .system(style, design: .serif)
    }
}
