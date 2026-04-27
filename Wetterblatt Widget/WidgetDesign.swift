import SwiftUI

enum WidgetDesign {
    static let background = Color(red: 0.96, green: 0.94, blue: 0.91)
    static let surface = Color(red: 0.93, green: 0.91, blue: 0.86)
    static let border = Color(red: 0.78, green: 0.75, blue: 0.67)
    static let secondaryText = Color(red: 0.60, green: 0.56, blue: 0.49)
    static let tertiaryText = Color(red: 0.42, green: 0.38, blue: 0.31)
    static let ink = Color(red: 0.16, green: 0.13, blue: 0.08)
    static let rain = Color(red: 0.28, green: 0.48, blue: 0.73)
    static let drizzle = Color(red: 0.42, green: 0.56, blue: 0.71)
    static let sun = Color(red: 0.78, green: 0.58, blue: 0.35)
    static let hazySun = Color(red: 0.71, green: 0.60, blue: 0.42)
    static let moon = Color(red: 0.52, green: 0.58, blue: 0.71)
    static let darkAccent = Color(red: 0.24, green: 0.18, blue: 0.10)

    static let paperGradient = LinearGradient(
        colors: [
            Color(red: 0.98, green: 0.96, blue: 0.93),
            background,
            Color(red: 0.92, green: 0.89, blue: 0.84),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func heroFont(size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .serif)
    }

    static func serif(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func mono(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func tint(for weatherCode: Int, isDay: Bool) -> Color {
        switch weatherCode {
        case 0:
            return isDay ? sun : moon
        case 1, 2:
            return isDay ? hazySun : moon
        case 51...57:
            return drizzle
        case 61...67, 80...82:
            return rain
        case 71...77, 85...86:
            return Color(red: 0.44, green: 0.58, blue: 0.75)
        case 95...99:
            return darkAccent
        default:
            return ink
        }
    }
}

struct WidgetPaperBackground: View {
    var body: some View {
        ZStack {
            WidgetDesign.paperGradient

            Circle()
                .fill(WidgetDesign.sun.opacity(0.08))
                .frame(width: 160)
                .offset(x: 92, y: -110)

            Circle()
                .fill(WidgetDesign.rain.opacity(0.08))
                .frame(width: 180)
                .offset(x: -96, y: 124)
        }
    }
}

struct WidgetWeatherSymbol: View {
    let weatherCode: Int
    let isDay: Bool
    let diameter: CGFloat
    let symbolSize: CGFloat

    private var descriptor: WidgetConditionDescriptor {
        WidgetWeatherConditions.descriptor(for: weatherCode, isDay: isDay)
    }

    private var tint: Color {
        WidgetDesign.tint(for: weatherCode, isDay: isDay)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.20),
                            tint.opacity(0.08),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Circle()
                        .stroke(tint.opacity(0.35), lineWidth: 0.9)
                )

            Image(systemName: descriptor.symbolName)
                .font(.system(size: symbolSize, weight: .medium))
                .foregroundStyle(tint)
        }
        .frame(width: diameter, height: diameter)
    }
}

struct WidgetMetaPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(WidgetDesign.mono(size: 8, weight: .medium))
                .foregroundStyle(WidgetDesign.secondaryText)
                .lineLimit(1)

            Text(value)
                .font(WidgetDesign.mono(size: 10, weight: .medium))
                .foregroundStyle(WidgetDesign.ink)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(WidgetDesign.surface.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(WidgetDesign.border, lineWidth: 0.8)
        )
    }
}
