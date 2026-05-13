import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct WeatherPaperPalette {
    let paperTop: Color
    let paperMid: Color
    let paperBottom: Color
    let heroTop: Color
    let heroBottom: Color
    let cardTop: Color
    let cardMid: Color
    let cardBottom: Color
    let border: Color
    let accent: Color
    let chromeWashTop: Color
    let chromeWashBottom: Color
    let vignetteTop: Color
    let vignetteBottom: Color

    var paperGradient: LinearGradient {
        LinearGradient(
            colors: [paperTop, paperMid, paperBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var heroGradient: LinearGradient {
        LinearGradient(
            colors: [heroTop, paperMid, heroBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var cardGradient: LinearGradient {
        LinearGradient(
            colors: [cardTop, cardMid, cardBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

enum DesignTokens {
    static let background = adaptive(light: 0xF7F0E4, dark: 0x100D08)
    static let surface = adaptive(light: 0xFBF5EA, dark: 0x1A1510)
    static let muted = adaptive(light: 0xEFE5D6, dark: 0x221E17)
    static let border = adaptive(light: 0xCDBFAA, dark: 0x3D3528)
    static let secondaryText = adaptive(light: 0x746856, dark: 0x8A7D68)
    static let tertiaryText = adaptive(light: 0x8F8170, dark: 0x6B5F4E)
    static let ink = adaptive(light: 0x2C2218, dark: 0xF0E4C8)
    static let rain = adaptive(light: 0x2F73A8, dark: 0x73A6D6)
    static let drizzle = adaptive(light: 0x4E91B8, dark: 0x8ABED8)
    static let uv = adaptive(light: 0xC97A11, dark: 0xF0C55B)
    static let wind = adaptive(light: 0x2C817D, dark: 0x66BCB4)
    static let windLow = adaptive(light: 0x6FA6A0, dark: 0x9FD6D0)
    static let airQualityGood = adaptive(light: 0x2E8A5A, dark: 0x63C98F)
    static let airQualityFair = adaptive(light: 0x2F8B8A, dark: 0x72C9C4)
    static let airQualityModerate = adaptive(light: 0xC98B1B, dark: 0xE4BE4A)
    static let airQualityPoor = adaptive(light: 0xBE5F2A, dark: 0xE08A55)
    static let airQualityVeryPoor = adaptive(light: 0xA63D3D, dark: 0xD66B6B)
    static let airQualityExtreme = adaptive(light: 0x7B4C8F, dark: 0xB587C7)
    static let sun = adaptive(light: 0xB97A18, dark: 0xE0B54B)
    static let hazySun = adaptive(light: 0xC98A28, dark: 0xE8C15A)
    static let moon = adaptive(light: 0x9B7B57, dark: 0xD9C39A)
    static let cloud = adaptive(light: 0x7C6F5E, dark: 0x5A5042)
    static let mist = adaptive(light: 0x7C6F5E, dark: 0xC2B59B, lightAlpha: 0.12, darkAlpha: 0.18)
    static let frost = adaptive(light: 0x7B91A7, dark: 0xD0D8E4)
    static let storm = adaptive(light: 0x665E56, dark: 0x7A746A)
    static let darkAccent = adaptive(light: 0x8B5E22, dark: 0x7A5820)
    static let toggleAccent = adaptive(light: 0xA46D24, dark: 0xA6782B)
    static let chromeFill = adaptive(light: 0xFFF8EE, dark: 0x221E17, lightAlpha: 0.94, darkAlpha: 0.94)
    static let chromeWash = adaptive(light: 0xFFFFFF, dark: 0xF0E4C8, lightAlpha: 0.16, darkAlpha: 0.03)
    static let trackFill = adaptive(light: 0xE6D7C1, dark: 0x2A241C)
    static let backdropVignetteTop = adaptive(light: 0x6A512B, dark: 0x000000, lightAlpha: 0.03, darkAlpha: 0.04)
    static let backdropVignetteBottom = adaptive(light: 0x4B3517, dark: 0x000000, lightAlpha: 0.12, darkAlpha: 0.32)

    static let paperGradient = LinearGradient(
        colors: [
            adaptive(light: 0xFCF6EC, dark: 0x140F09),
            adaptive(light: 0xF4EADB, dark: 0x100D08),
            adaptive(light: 0xE8D9C3, dark: 0x000000, lightAlpha: 1, darkAlpha: 0.98),
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let shadow = adaptive(light: 0x4A3720, dark: 0x000000, lightAlpha: 0.14, darkAlpha: 0.34)

    static var defaultWeatherPaperPalette: WeatherPaperPalette {
        WeatherPaperPalette(
            paperTop: adaptive(light: 0xFCF6EC, dark: 0x140F09),
            paperMid: adaptive(light: 0xF4EADB, dark: 0x100D08),
            paperBottom: adaptive(light: 0xE8D9C3, dark: 0x000000, lightAlpha: 1, darkAlpha: 0.98),
            heroTop: adaptive(light: 0xEFE5D6, dark: 0x221E17),
            heroBottom: adaptive(light: 0xF7F0E4, dark: 0x100D08),
            cardTop: adaptive(light: 0xFFF8EE, dark: 0x221E17, lightAlpha: 0.98, darkAlpha: 0.98),
            cardMid: adaptive(light: 0xF5EBDD, dark: 0x1A1510, lightAlpha: 0.98, darkAlpha: 0.98),
            cardBottom: adaptive(light: 0xEFE0CB, dark: 0x100D08, lightAlpha: 0.96, darkAlpha: 0.98),
            border: adaptive(light: 0xCDBFAA, dark: 0x3D3528),
            accent: sun,
            chromeWashTop: adaptive(light: 0xFFFFFF, dark: 0xF0E4C8, lightAlpha: 0.18, darkAlpha: 0.04),
            chromeWashBottom: adaptive(light: 0x8B5E22, dark: 0xE0B54B, lightAlpha: 0.05, darkAlpha: 0.03),
            vignetteTop: backdropVignetteTop,
            vignetteBottom: backdropVignetteBottom
        )
    }

    static func weatherPaperPalette(
        weatherCode: Int,
        isDay: Bool,
        rainIntensity: Double
    ) -> WeatherPaperPalette {
        let kind = weatherPaperKind(for: weatherCode)
        let rainWeight = min(max(rainIntensity, 0), 1)

        switch kind {
        case .clear:
            if isDay {
                return WeatherPaperPalette(
                    paperTop: adaptive(light: 0xFFF9E8, dark: 0x161006),
                    paperMid: adaptive(light: 0xF5E8BF, dark: 0x120F09),
                    paperBottom: adaptive(light: 0xE3D7B6, dark: 0x050504),
                    heroTop: adaptive(light: 0xF0D88C, dark: 0x2A210D),
                    heroBottom: adaptive(light: 0xF7F0E4, dark: 0x100D08),
                    cardTop: adaptive(light: 0xFFF8EA, dark: 0x231D12, lightAlpha: 0.98, darkAlpha: 0.98),
                    cardMid: adaptive(light: 0xF6EBD1, dark: 0x1A1510, lightAlpha: 0.98, darkAlpha: 0.98),
                    cardBottom: adaptive(light: 0xEFE0C0, dark: 0x100D08, lightAlpha: 0.96, darkAlpha: 0.98),
                    border: adaptive(light: 0xC8B378, dark: 0x4A3A1C),
                    accent: sun,
                    chromeWashTop: adaptive(light: 0xFFFFFF, dark: 0xF3DB82, lightAlpha: 0.20, darkAlpha: 0.04),
                    chromeWashBottom: adaptive(light: 0xC98A28, dark: 0xE0B54B, lightAlpha: 0.08, darkAlpha: 0.04),
                    vignetteTop: adaptive(light: 0xAA7724, dark: 0x000000, lightAlpha: 0.05, darkAlpha: 0.08),
                    vignetteBottom: adaptive(light: 0x6D4B18, dark: 0x000000, lightAlpha: 0.14, darkAlpha: 0.34)
                )
            } else {
                return WeatherPaperPalette(
                    paperTop: adaptive(light: 0xEEF2EA, dark: 0x0D1118),
                    paperMid: adaptive(light: 0xE6E3D2, dark: 0x0B0D12),
                    paperBottom: adaptive(light: 0xD8CFB5, dark: 0x030407),
                    heroTop: adaptive(light: 0xD9DFE2, dark: 0x172034),
                    heroBottom: adaptive(light: 0xEFE6D1, dark: 0x0B0D12),
                    cardTop: adaptive(light: 0xF9F5E8, dark: 0x181B22, lightAlpha: 0.98, darkAlpha: 0.98),
                    cardMid: adaptive(light: 0xECE5D4, dark: 0x12141A, lightAlpha: 0.98, darkAlpha: 0.98),
                    cardBottom: adaptive(light: 0xDED4BE, dark: 0x090B10, lightAlpha: 0.96, darkAlpha: 0.98),
                    border: adaptive(light: 0xA9A68F, dark: 0x384257),
                    accent: moon,
                    chromeWashTop: adaptive(light: 0xFFFFFF, dark: 0xD9C39A, lightAlpha: 0.16, darkAlpha: 0.05),
                    chromeWashBottom: adaptive(light: 0x62718E, dark: 0x7E90B4, lightAlpha: 0.07, darkAlpha: 0.04),
                    vignetteTop: adaptive(light: 0x62718E, dark: 0x000000, lightAlpha: 0.06, darkAlpha: 0.10),
                    vignetteBottom: adaptive(light: 0x33291C, dark: 0x000000, lightAlpha: 0.14, darkAlpha: 0.36)
                )
            }

        case .partlyCloudy:
            return WeatherPaperPalette(
                paperTop: adaptive(light: 0xF4F5E9, dark: 0x101317),
                paperMid: adaptive(light: 0xECE3CD, dark: 0x10100D),
                paperBottom: adaptive(light: 0xDACBB1, dark: 0x050605),
                heroTop: adaptive(light: isDay ? 0xD8E3E4 : 0x1A2330, dark: isDay ? 0x182026 : 0x111724),
                heroBottom: adaptive(light: 0xF2E6D0, dark: 0x100D08),
                cardTop: adaptive(light: 0xFAF6E9, dark: 0x1D1E1A, lightAlpha: 0.98, darkAlpha: 0.98),
                cardMid: adaptive(light: 0xEFE6D4, dark: 0x171612, lightAlpha: 0.98, darkAlpha: 0.98),
                cardBottom: adaptive(light: 0xE1D3B8, dark: 0x0C0D0B, lightAlpha: 0.96, darkAlpha: 0.98),
                border: adaptive(light: 0xB9B09A, dark: 0x3D4138),
                accent: isDay ? hazySun : moon,
                chromeWashTop: adaptive(light: 0xFFFFFF, dark: 0xF0E4C8, lightAlpha: 0.17, darkAlpha: 0.04),
                chromeWashBottom: adaptive(light: 0x6C8790, dark: 0x879AA3, lightAlpha: 0.07, darkAlpha: 0.04),
                vignetteTop: adaptive(light: 0x6C8790, dark: 0x000000, lightAlpha: 0.05, darkAlpha: 0.09),
                vignetteBottom: adaptive(light: 0x5B4524, dark: 0x000000, lightAlpha: 0.13, darkAlpha: 0.34)
            )

        case .overcast:
            return WeatherPaperPalette(
                paperTop: adaptive(light: 0xEFF1E8, dark: 0x111312),
                paperMid: adaptive(light: 0xE4DFD0, dark: 0x10100E),
                paperBottom: adaptive(light: 0xD2C7B0, dark: 0x050505),
                heroTop: adaptive(light: 0xC6CCC6, dark: 0x1C201F),
                heroBottom: adaptive(light: 0xE8DED0, dark: 0x0F0E0D),
                cardTop: adaptive(light: 0xF7F4EA, dark: 0x1D1D1A, lightAlpha: 0.98, darkAlpha: 0.98),
                cardMid: adaptive(light: 0xEAE4D6, dark: 0x171612, lightAlpha: 0.98, darkAlpha: 0.98),
                cardBottom: adaptive(light: 0xDCD1BC, dark: 0x0C0B09, lightAlpha: 0.96, darkAlpha: 0.98),
                border: adaptive(light: 0xAAA89B, dark: 0x3F423C),
                accent: cloud,
                chromeWashTop: adaptive(light: 0xFFFFFF, dark: 0xDDD6C2, lightAlpha: 0.14, darkAlpha: 0.04),
                chromeWashBottom: adaptive(light: 0x6B746F, dark: 0x8D968F, lightAlpha: 0.08, darkAlpha: 0.04),
                vignetteTop: adaptive(light: 0x6B746F, dark: 0x000000, lightAlpha: 0.06, darkAlpha: 0.10),
                vignetteBottom: adaptive(light: 0x403726, dark: 0x000000, lightAlpha: 0.15, darkAlpha: 0.36)
            )

        case .fog:
            return WeatherPaperPalette(
                paperTop: adaptive(light: 0xF0F0E7, dark: 0x121514),
                paperMid: adaptive(light: 0xE6DFD1, dark: 0x10110F),
                paperBottom: adaptive(light: 0xD5C9B4, dark: 0x050605),
                heroTop: adaptive(light: 0xD5D8D0, dark: 0x1B211F),
                heroBottom: adaptive(light: 0xE8DFD0, dark: 0x0F0F0C),
                cardTop: adaptive(light: 0xFAF7ED, dark: 0x1C1E1A, lightAlpha: 0.98, darkAlpha: 0.98),
                cardMid: adaptive(light: 0xEDE7D9, dark: 0x161713, lightAlpha: 0.98, darkAlpha: 0.98),
                cardBottom: adaptive(light: 0xDDD2BE, dark: 0x0B0C09, lightAlpha: 0.96, darkAlpha: 0.98),
                border: adaptive(light: 0xA7AA9D, dark: 0x3E4640),
                accent: mist,
                chromeWashTop: adaptive(light: 0xFFFFFF, dark: 0xE2DDCA, lightAlpha: 0.16, darkAlpha: 0.04),
                chromeWashBottom: adaptive(light: 0x83918B, dark: 0x9AA69F, lightAlpha: 0.08, darkAlpha: 0.04),
                vignetteTop: adaptive(light: 0x83918B, dark: 0x000000, lightAlpha: 0.05, darkAlpha: 0.09),
                vignetteBottom: adaptive(light: 0x4D432F, dark: 0x000000, lightAlpha: 0.13, darkAlpha: 0.34)
            )

        case .drizzle, .rain:
            return WeatherPaperPalette(
                paperTop: adaptive(light: rainWeight > 0.58 ? 0xE1EAEC : 0xE8F0ED, dark: 0x0E1416),
                paperMid: adaptive(light: rainWeight > 0.58 ? 0xD8DDD7 : 0xE1E2D4, dark: 0x0D1010),
                paperBottom: adaptive(light: rainWeight > 0.58 ? 0xC7CCBD : 0xD1CFB8, dark: 0x050606),
                heroTop: adaptive(light: rainWeight > 0.58 ? 0xAEBFC5 : 0xC2D3D4, dark: 0x142029),
                heroBottom: adaptive(light: 0xE4DED0, dark: 0x0D0F10),
                cardTop: adaptive(light: 0xF4F6EA, dark: 0x181D1F, lightAlpha: 0.98, darkAlpha: 0.98),
                cardMid: adaptive(light: 0xE7E5D5, dark: 0x121618, lightAlpha: 0.98, darkAlpha: 0.98),
                cardBottom: adaptive(light: 0xD6D0BC, dark: 0x080B0C, lightAlpha: 0.96, darkAlpha: 0.98),
                border: adaptive(light: 0x9EB0AF, dark: 0x34444B),
                accent: kind == .drizzle ? drizzle : rain,
                chromeWashTop: adaptive(light: 0xFFFFFF, dark: 0xD3E4EC, lightAlpha: 0.14, darkAlpha: 0.04),
                chromeWashBottom: adaptive(light: 0x2F73A8, dark: 0x73A6D6, lightAlpha: 0.08 + rainWeight * 0.06, darkAlpha: 0.04 + rainWeight * 0.04),
                vignetteTop: adaptive(light: 0x2F73A8, dark: 0x000000, lightAlpha: 0.05 + rainWeight * 0.04, darkAlpha: 0.11),
                vignetteBottom: adaptive(light: 0x31454E, dark: 0x000000, lightAlpha: 0.16 + rainWeight * 0.05, darkAlpha: 0.38)
            )

        case .snow:
            return WeatherPaperPalette(
                paperTop: adaptive(light: 0xF5F7F4, dark: 0x10151A),
                paperMid: adaptive(light: 0xE8ECE4, dark: 0x0E1114),
                paperBottom: adaptive(light: 0xD8DDCF, dark: 0x050608),
                heroTop: adaptive(light: 0xDBE6EC, dark: 0x172231),
                heroBottom: adaptive(light: 0xEDE8D8, dark: 0x0D1013),
                cardTop: adaptive(light: 0xFBFAF1, dark: 0x191D20, lightAlpha: 0.98, darkAlpha: 0.98),
                cardMid: adaptive(light: 0xECEADD, dark: 0x131619, lightAlpha: 0.98, darkAlpha: 0.98),
                cardBottom: adaptive(light: 0xDDE0D2, dark: 0x090C0E, lightAlpha: 0.96, darkAlpha: 0.98),
                border: adaptive(light: 0xA9B9C2, dark: 0x3B4A59),
                accent: frost,
                chromeWashTop: adaptive(light: 0xFFFFFF, dark: 0xD0D8E4, lightAlpha: 0.20, darkAlpha: 0.06),
                chromeWashBottom: adaptive(light: 0x7B91A7, dark: 0xD0D8E4, lightAlpha: 0.08, darkAlpha: 0.04),
                vignetteTop: adaptive(light: 0x7B91A7, dark: 0x000000, lightAlpha: 0.05, darkAlpha: 0.10),
                vignetteBottom: adaptive(light: 0x405063, dark: 0x000000, lightAlpha: 0.13, darkAlpha: 0.36)
            )

        case .storm:
            return WeatherPaperPalette(
                paperTop: adaptive(light: 0xE4E5DE, dark: 0x0B0D10),
                paperMid: adaptive(light: 0xD4D1C5, dark: 0x090A0D),
                paperBottom: adaptive(light: 0xBDB7A8, dark: 0x030405),
                heroTop: adaptive(light: 0x8E989E, dark: 0x121722),
                heroBottom: adaptive(light: 0xD4CAB8, dark: 0x08090C),
                cardTop: adaptive(light: 0xF2F0E6, dark: 0x17191D, lightAlpha: 0.98, darkAlpha: 0.98),
                cardMid: adaptive(light: 0xE2DED0, dark: 0x111317, lightAlpha: 0.98, darkAlpha: 0.98),
                cardBottom: adaptive(light: 0xCEC6B4, dark: 0x07090C, lightAlpha: 0.96, darkAlpha: 0.98),
                border: adaptive(light: 0x928B7E, dark: 0x3E4350),
                accent: storm,
                chromeWashTop: adaptive(light: 0xFFFFFF, dark: 0xD8D1C5, lightAlpha: 0.12, darkAlpha: 0.04),
                chromeWashBottom: adaptive(light: 0x665E56, dark: 0x7A746A, lightAlpha: 0.10 + rainWeight * 0.05, darkAlpha: 0.05),
                vignetteTop: adaptive(light: 0x454E5A, dark: 0x000000, lightAlpha: 0.09, darkAlpha: 0.14),
                vignetteBottom: adaptive(light: 0x24252A, dark: 0x000000, lightAlpha: 0.20, darkAlpha: 0.42)
            )
        }
    }

    static func heroFont(size: CGFloat) -> Font {
        heroDisplayFont(size: size)
    }

    static func serif(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        editorialSerif(size: size, weight: weight, italic: false)
    }

    static func serifItalic(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        editorialSerif(size: size, weight: weight, italic: true)
    }

    static func mono(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        editorialMono(size: size, weight: weight)
    }

    private static func adaptive(light: Int, dark: Int, lightAlpha: Double = 1, darkAlpha: Double = 1) -> Color {
        #if canImport(UIKit)
        Color(uiColor: UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            return uiColor(
                isDark ? dark : light,
                alpha: isDark ? darkAlpha : lightAlpha
            )
        })
        #else
        hex(dark, alpha: darkAlpha)
        #endif
    }

    private static func hex(_ value: Int, alpha: Double = 1) -> Color {
        Color(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: alpha
        )
    }

    #if canImport(UIKit)
    private static func uiColor(_ value: Int, alpha: Double = 1) -> UIColor {
        UIColor(
            red: CGFloat(Double((value >> 16) & 0xFF) / 255),
            green: CGFloat(Double((value >> 8) & 0xFF) / 255),
            blue: CGFloat(Double(value & 0xFF) / 255),
            alpha: alpha
        )
    }
    #endif

    #if canImport(UIKit)
    private static func heroDisplayFont(size: CGFloat) -> Font {
        let candidates = [
            "DINAlternate-Bold",
            "HelveticaNeue-CondensedBlack",
            "AvenirNextCondensed-Heavy",
            "ArialNarrow-Bold",
        ]

        if let fontName = availableFontName(in: candidates, size: size) {
            return .custom(fontName, size: size)
        }

        return .system(size: size, weight: .heavy, design: .default)
    }

    private static func editorialSerif(size: CGFloat, weight: Font.Weight, italic: Bool) -> Font {
        let candidates: [String]
        switch (prefersBold(weight), italic) {
        case (true, true):
            candidates = [
                "IowanOldStyle-BoldItalic",
                "Georgia-BoldItalic",
                "Baskerville-BoldItalic",
                "TimesNewRomanPS-BoldItalicMT",
            ]
        case (true, false):
            candidates = [
                "IowanOldStyle-Bold",
                "Georgia-Bold",
                "Baskerville-Bold",
                "TimesNewRomanPS-BoldMT",
            ]
        case (false, true):
            candidates = [
                "IowanOldStyle-Italic",
                "Georgia-Italic",
                "Baskerville-Italic",
                "TimesNewRomanPS-ItalicMT",
            ]
        case (false, false):
            candidates = [
                "IowanOldStyle-Roman",
                "Georgia",
                "Baskerville",
                "TimesNewRomanPSMT",
            ]
        }

        if let fontName = availableFontName(in: candidates, size: size) {
            return .custom(fontName, size: size)
        }

        let fallback = Font.system(size: size, weight: weight, design: .serif)
        return italic ? fallback.italic() : fallback
    }

    private static func editorialMono(size: CGFloat, weight: Font.Weight) -> Font {
        let candidates = prefersBold(weight)
            ? ["Menlo-Bold", "CourierNewPS-BoldMT"]
            : ["Menlo-Regular", "CourierNewPSMT"]

        if let fontName = availableFontName(in: candidates, size: size) {
            return .custom(fontName, size: size)
        }

        return .system(size: size, weight: weight, design: .monospaced)
    }

    private static func availableFontName(in candidates: [String], size: CGFloat) -> String? {
        candidates.first { UIFont(name: $0, size: size) != nil }
    }
    #else
    private static func heroDisplayFont(size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .default)
    }

    private static func editorialSerif(size: CGFloat, weight: Font.Weight, italic: Bool) -> Font {
        let fallback = Font.system(size: size, weight: weight, design: .serif)
        return italic ? fallback.italic() : fallback
    }

    private static func editorialMono(size: CGFloat, weight: Font.Weight) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    #endif

    private static func prefersBold(_ weight: Font.Weight) -> Bool {
        switch weight {
        case .bold, .heavy, .black, .semibold:
            return true
        default:
            return false
        }
    }

    private enum WeatherPaperKind {
        case clear
        case partlyCloudy
        case overcast
        case fog
        case drizzle
        case rain
        case snow
        case storm
    }

    private static func weatherPaperKind(for weatherCode: Int) -> WeatherPaperKind {
        switch weatherCode {
        case 0:
            return .clear
        case 1, 2:
            return .partlyCloudy
        case 3:
            return .overcast
        case 45, 48:
            return .fog
        case 51...57:
            return .drizzle
        case 61...67, 80...82:
            return .rain
        case 71...77, 85...86:
            return .snow
        case 95...99:
            return .storm
        default:
            return .partlyCloudy
        }
    }
}

private struct WeatherPaperPaletteEnvironmentKey: EnvironmentKey {
    static let defaultValue = DesignTokens.defaultWeatherPaperPalette
}

extension EnvironmentValues {
    var weatherPaperPalette: WeatherPaperPalette {
        get { self[WeatherPaperPaletteEnvironmentKey.self] }
        set { self[WeatherPaperPaletteEnvironmentKey.self] = newValue }
    }
}

extension View {
    func vintageCard() -> some View {
        modifier(VintageCardModifier())
    }

    func paperBackground() -> some View {
        self.background(WeatherBackdrop())
    }

    func weatherSheetChrome(_ palette: WeatherPaperPalette) -> some View {
        modifier(WeatherSheetChromeModifier(palette: palette))
    }
}

private struct VintageCardModifier: ViewModifier {
    @Environment(\.weatherPaperPalette) private var palette

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background {
                SecondaryCardChrome()
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(palette.border.opacity(0.84), lineWidth: 0.75)
            )
            .shadow(color: DesignTokens.shadow.opacity(0.18), radius: 16, y: 8)
    }
}

private struct WeatherSheetChromeModifier: ViewModifier {
    let palette: WeatherPaperPalette

    func body(content: Content) -> some View {
        content
            .environment(\.weatherPaperPalette, palette)
            .presentationBackground {
                WeatherBackdrop()
                    .environment(\.weatherPaperPalette, palette)
            }
            .tint(palette.accent)
    }
}

struct SecondaryCardChrome: View {
    @Environment(\.weatherPaperPalette) private var palette

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(palette.cardGradient)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                palette.chromeWashTop,
                                .clear,
                                palette.accent.opacity(0.045),
                                palette.chromeWashBottom,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(palette.border.opacity(0.38), lineWidth: 0.65)
            }
    }
}

struct GentlePressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var scale: CGFloat = 0.985
    var verticalOffset: CGFloat = 1
    var pressedOpacity: Double = 0.97

    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed
        let appliesMotion = isPressed && !reduceMotion

        configuration.label
            .scaleEffect(appliesMotion ? scale : 1)
            .offset(y: appliesMotion ? verticalOffset : 0)
            .opacity(isPressed ? pressedOpacity : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: isPressed)
    }
}

private struct WeatherBackdrop: View {
    @Environment(\.weatherPaperPalette) private var palette

    var body: some View {
        ZStack {
            palette.paperGradient

            LinearGradient(
                colors: [
                    palette.chromeWashTop,
                    .clear,
                ],
                startPoint: .topLeading,
                endPoint: .center
            )

            LinearGradient(
                colors: [
                    .clear,
                    palette.chromeWashBottom,
                ],
                startPoint: .center,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [
                    palette.vignetteTop,
                    .clear,
                    palette.vignetteBottom,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}
