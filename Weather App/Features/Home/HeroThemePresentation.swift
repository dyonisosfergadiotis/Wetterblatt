import SwiftUI
import UIKit

extension HeroThemeColor {
    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }

    init(color: Color) {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        self.init(
            red: Double(red),
            green: Double(green),
            blue: Double(blue),
            alpha: Double(alpha)
        )
    }
}

extension HeroThemeMatchMode {
    var title: String {
        switch self {
        case .all:
            return "Alle"
        case .any:
            return "Eine"
        }
    }
}

extension HeroThemeCriterion {
    var title: String {
        switch self {
        case .rain:
            return "Regen"
        case .heavyRain:
            return "Starkregen"
        case .thunderstorm:
            return "Gewitter"
        case .strongWind:
            return "Starker Wind"
        case .heat:
            return "Hitze"
        case .frost:
            return "Frost"
        case .highUV:
            return "Hoher UV-Index"
        case .poorAir:
            return "Schlechte Luft"
        case .pollen:
            return "Pollen"
        case .fog:
            return "Nebel"
        case .snow:
            return "Schnee"
        }
    }

    var detail: String {
        switch self {
        case .rain:
            return "Passt bei nassem Wetter oder hoher Regenwahrscheinlichkeit."
        case .heavyRain:
            return "Passt bei kräftigen Regenmengen oder Starkregen-Codes."
        case .thunderstorm:
            return "Passt, wenn Gewitter im kurzfristigen Verlauf liegen."
        case .strongWind:
            return "Passt bei spürbar starkem Wind."
        case .heat:
            return "Passt bei sehr warmen Tageswerten."
        case .frost:
            return "Passt bei Frost oder Temperaturen nahe null Grad."
        case .highUV:
            return "Passt bei hoher UV-Belastung."
        case .poorAir:
            return "Passt bei erhöhter Luftbelastung."
        case .pollen:
            return "Passt bei ausgewählten Pollen mit relevanter Belastung."
        case .fog:
            return "Passt bei Nebel-Wettercodes."
        case .snow:
            return "Passt bei Schnee oder Schneeschauern."
        }
    }

    var symbolName: String {
        switch self {
        case .rain:
            return "cloud.rain.fill"
        case .heavyRain:
            return "cloud.heavyrain.fill"
        case .thunderstorm:
            return "cloud.bolt.rain.fill"
        case .strongWind:
            return "wind"
        case .heat:
            return "thermometer.sun.fill"
        case .frost:
            return "snowflake"
        case .highUV:
            return "sun.max.fill"
        case .poorAir:
            return "aqi.medium"
        case .pollen:
            return "allergens"
        case .fog:
            return "cloud.fog.fill"
        case .snow:
            return "cloud.snow.fill"
        }
    }
}
