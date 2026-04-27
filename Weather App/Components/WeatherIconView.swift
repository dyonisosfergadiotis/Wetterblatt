import SwiftUI

struct WeatherIconView: View {
    enum Size: Equatable {
        case small
        case medium
        case hero
        case large

        var frame: CGFloat {
            switch self {
            case .small: return 42
            case .medium: return 70
            case .hero: return 88
            case .large: return 108
            }
        }

        var symbol: CGFloat {
            switch self {
            case .small: return 16
            case .medium: return 28
            case .hero: return 36
            case .large: return 46
            }
        }

        var statusRingFrame: CGFloat {
            frame + ringInset * 2
        }

        private var ringInset: CGFloat {
            switch self {
            case .small: return 0
            case .medium: return 16
            case .hero: return 18
            case .large: return 20
            }
        }

        var statusRingFontSize: CGFloat {
            switch self {
            case .small: return 0
            case .medium: return 8
            case .hero: return 9
            case .large: return 10
            }
        }

        var statusRingLineWidth: CGFloat {
            switch self {
            case .small: return 0.8
            case .medium: return 1.0
            case .hero: return 1.1
            case .large: return 1.2
            }
        }
    }

    let weatherCode: Int
    let isDay: Bool
    var size: Size = .large
    var showsStatusRing: Bool = false

    @State private var breathe = false

    private var descriptor: WeatherConditionDescriptor {
        WeatherConditions.descriptor(for: weatherCode, isDay: isDay)
    }

    var body: some View {
        ZStack {
            if showsStatusRing, size != .small {
                statusRing
            }

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
                .font(.system(size: size.symbol, weight: .medium))
                .foregroundStyle(tint)
                .scaleEffect(breathe ? 1.04 : 0.95)
                .shadow(color: tint.opacity(0.12), radius: 8, y: 4)
        }
        .frame(
            width: showsStatusRing && size != .small ? size.statusRingFrame : size.frame,
            height: showsStatusRing && size != .small ? size.statusRingFrame : size.frame
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
        .onTapGesture {
            HapticManager.softImpact()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                breathe.toggle()
            }
        }
    }

    private var tint: Color {
        switch weatherCode {
        case 0:
            return isDay ? DesignTokens.sun : DesignTokens.moon
        case 1, 2:
            return isDay ? DesignTokens.hazySun : DesignTokens.moon
        case 51...57:
            return DesignTokens.drizzle
        case 61...67, 80...82:
            return DesignTokens.rain
        case 71...77, 85...86:
            return Color(red: 0.44, green: 0.58, blue: 0.75)
        case 95...99:
            return DesignTokens.darkAccent
        default:
            return DesignTokens.ink
        }
    }

    private var statusRing: some View {
        ZStack {
            Circle()
                .stroke(
                    DesignTokens.border.opacity(0.45),
                    style: StrokeStyle(lineWidth: size.statusRingLineWidth)
                )

            Circle()
                .trim(from: 0.06, to: 0.94)
                .stroke(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.22),
                            tint.opacity(0.58),
                            tint.opacity(0.22),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(
                        lineWidth: size.statusRingLineWidth + 0.2,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))

            ConditionStatusRingText(
                text: descriptor.title,
                color: tint,
                diameter: size.statusRingFrame,
                fontSize: size.statusRingFontSize
            )
        }
        .frame(width: size.statusRingFrame, height: size.statusRingFrame)
    }
}

private struct ConditionStatusRingText: View {
    let text: String
    let color: Color
    let diameter: CGFloat
    let fontSize: CGFloat

    private var characters: [String] {
        Array(" \(text.uppercased()) ").map(String.init)
    }

    private let startAngle: Double = 198
    private let endAngle: Double = -18

    var body: some View {
        ZStack {
            ForEach(Array(characters.enumerated()), id: \.offset) { index, character in
                let progress = characters.count <= 1 ? 0.5 : Double(index) / Double(characters.count - 1)
                let angle = startAngle + (endAngle - startAngle) * progress
                let radians = Angle.degrees(angle).radians
                let radius = diameter / 2 - fontSize * 1.15
                let center = diameter / 2

                Text(character)
                    .font(DesignTokens.mono(size: fontSize, weight: .semibold))
                    .foregroundStyle(color.opacity(character == " " ? 0 : 0.82))
                    .rotationEffect(.degrees(angle - 90))
                    .position(
                        x: center + cos(radians) * radius,
                        y: center + sin(radians) * radius
                    )
            }
        }
        .frame(width: diameter, height: diameter)
    }
}
