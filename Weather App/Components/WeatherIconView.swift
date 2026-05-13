import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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

    private var allowsAmbientAnimation: Bool {
        guard !UIAccessibility.isReduceMotionEnabled else { return false }
        guard !ProcessInfo.processInfo.isLowPowerModeEnabled else { return false }
        return size == .hero || size == .large
    }

    private var usesSubtleFinish: Bool {
        size == .small || size == .medium
    }

    private var descriptor: WeatherConditionDescriptor {
        WeatherConditions.descriptor(for: weatherCode, isDay: isDay)
    }

    var body: some View {
        ZStack {
            if showsStatusRing, size != .small {
                statusRing
            }

            Circle()
                .fill(tint.opacity(glowOpacity))
                .frame(width: size.frame * 0.94, height: size.frame * 0.94)
                .blur(radius: glowBlurRadius)

            Circle()
                .fill(plateGradient)
                .overlay(
                    Circle()
                        .stroke(tint.opacity(plateStrokeOpacity), lineWidth: 0.9)
                )
                .overlay(alignment: .topLeading) {
                    if showsPlateHighlight {
                        Circle()
                            .fill(Color.white.opacity(isDay ? 0.20 : 0.08))
                            .frame(width: size.frame * 0.28, height: size.frame * 0.28)
                            .blur(radius: 5)
                            .offset(x: size.frame * 0.02, y: size.frame * 0.01)
                    }
                }
                .shadow(
                    color: DesignTokens.shadow.opacity(plateShadowOpacity),
                    radius: plateShadowRadius,
                    y: plateShadowYOffset
                )

            Image(systemName: descriptor.symbolName)
                .symbolRenderingMode(.palette)
                .font(.system(size: size.symbol, weight: .semibold))
                .foregroundStyle(symbolPrimaryTint, symbolSecondaryTint, symbolTertiaryTint)
                .scaleEffect(allowsAmbientAnimation ? (breathe ? 1.05 : 0.96) : 1)
                .rotationEffect(.degrees(allowsAmbientAnimation ? (breathe ? -2.5 : 1.2) : 0))
                .shadow(
                    color: tint.opacity(symbolShadowOpacity),
                    radius: symbolShadowRadius,
                    y: symbolShadowYOffset
                )
                .overlay {
                    if showsSymbolHighlight {
                        Image(systemName: descriptor.symbolName)
                            .symbolRenderingMode(.hierarchical)
                            .font(.system(size: size.symbol, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(isDay ? 0.18 : 0.10))
                            .blur(radius: 0.4)
                            .mask(
                                LinearGradient(
                                    colors: [Color.white, .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
        }
        .frame(
            width: showsStatusRing && size != .small ? size.statusRingFrame : size.frame,
            height: showsStatusRing && size != .small ? size.statusRingFrame : size.frame
        )
        .onAppear {
            guard allowsAmbientAnimation else {
                breathe = false
                return
            }

            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
        .onDisappear {
            breathe = false
        }
        .onTapGesture {
            guard allowsAmbientAnimation else { return }
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

    private var symbolPrimaryTint: Color {
        switch weatherCode {
        case 1, 2:
            return isDay ? DesignTokens.cloud.opacity(0.94) : DesignTokens.cloud.opacity(0.90)
        case 51...57, 61...67, 80...82:
            return DesignTokens.cloud.opacity(isDay ? 0.94 : 0.90)
        case 95...99:
            return DesignTokens.cloud.opacity(isDay ? 0.92 : 0.86)
        default:
            return tint.opacity(0.94)
        }
    }

    private var symbolSecondaryTint: Color {
        switch weatherCode {
        case 1, 2:
            return isDay ? DesignTokens.sun.opacity(0.94) : DesignTokens.moon.opacity(0.86)
        case 51...57:
            return DesignTokens.drizzle.opacity(0.96)
        case 61...67, 80...82:
            return DesignTokens.rain.opacity(0.96)
        case 95...99:
            return DesignTokens.sun.opacity(0.88)
        default:
            return symbolHighlightTint
        }
    }

    private var symbolTertiaryTint: Color {
        switch weatherCode {
        case 95...99:
            return DesignTokens.rain.opacity(0.96)
        default:
            return symbolHighlightTint
        }
    }

    private var symbolHighlightTint: Color {
        switch weatherCode {
        case 95...99:
            return DesignTokens.sun.opacity(0.86)
        case 71...77, 85...86:
            return Color.white.opacity(usesSubtleFinish ? 0.68 : 0.82)
        default:
            return Color.white.opacity(
                isDay
                    ? (usesSubtleFinish ? 0.68 : 0.82)
                    : (usesSubtleFinish ? 0.44 : 0.56)
            )
        }
    }

    private var plateGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(plateHighlightOpacity),
                tint.opacity(plateTintOpacity),
                DesignTokens.surface.opacity(surfaceOpacity),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var glowOpacity: Double {
        switch size {
        case .small:
            return 0.04
        case .medium:
            return 0.06
        case .hero, .large:
            return 0.16
        }
    }

    private var glowBlurRadius: CGFloat {
        switch size {
        case .small:
            return 1.6
        case .medium:
            return 3.5
        case .hero, .large:
            return 10
        }
    }

    private var plateStrokeOpacity: Double {
        switch size {
        case .small:
            return 0.12
        case .medium:
            return 0.16
        case .hero, .large:
            return 0.26
        }
    }

    private var plateShadowOpacity: Double {
        switch size {
        case .small:
            return 0.03
        case .medium:
            return 0.05
        case .hero, .large:
            return 0.18
        }
    }

    private var plateShadowRadius: CGFloat {
        switch size {
        case .small:
            return 2
        case .medium:
            return 4
        case .hero, .large:
            return 10
        }
    }

    private var plateShadowYOffset: CGFloat {
        switch size {
        case .small:
            return 1
        case .medium:
            return 2
        case .hero, .large:
            return 6
        }
    }

    private var symbolShadowOpacity: Double {
        switch size {
        case .small:
            return 0.02
        case .medium:
            return 0.04
        case .hero, .large:
            return 0.16
        }
    }

    private var symbolShadowRadius: CGFloat {
        switch size {
        case .small:
            return 1
        case .medium:
            return 2
        case .hero, .large:
            return 8
        }
    }

    private var symbolShadowYOffset: CGFloat {
        switch size {
        case .small:
            return 0.5
        case .medium:
            return 1
        case .hero, .large:
            return 4
        }
    }

    private var plateHighlightOpacity: Double {
        switch size {
        case .small:
            return isDay ? 0.08 : 0.02
        case .medium:
            return isDay ? 0.12 : 0.03
        case .hero, .large:
            return isDay ? 0.24 : 0.06
        }
    }

    private var plateTintOpacity: Double {
        switch size {
        case .small:
            return 0.08
        case .medium:
            return 0.12
        case .hero, .large:
            return 0.22
        }
    }

    private var surfaceOpacity: Double {
        isDay
            ? (usesSubtleFinish ? 0.97 : 0.94)
            : (usesSubtleFinish ? 0.93 : 0.90)
    }

    private var showsPlateHighlight: Bool {
        !usesSubtleFinish
    }

    private var showsSymbolHighlight: Bool {
        !usesSubtleFinish
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

struct MoonPhaseIconView: View {
    let kind: MoonPhaseKind
    var moonLight = Color(red: 0.95, green: 0.91, blue: 0.78)
    var moonShadow = DesignTokens.darkAccent.opacity(0.82)
    var borderColor = DesignTokens.border.opacity(0.45)
    var borderLineWidth: CGFloat = 0.8

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)

            ZStack {
                switch kind {
                case .newMoon:
                    Circle()
                        .fill(moonShadow)
                case .waxingCrescent:
                    phaseBase {
                        Circle()
                            .fill(moonLight)
                            .overlay {
                                Circle()
                                    .fill(moonShadow)
                                    .offset(x: -size * 0.34)
                            }
                    }
                case .firstQuarter:
                    phaseBase {
                        Circle()
                            .fill(moonShadow)
                            .overlay(alignment: .trailing) {
                                Rectangle()
                                    .fill(moonLight)
                                    .frame(width: size * 0.5)
                            }
                    }
                case .waxingGibbous:
                    phaseBase {
                        Circle()
                            .fill(moonLight)
                            .overlay {
                                Ellipse()
                                    .fill(moonShadow)
                                    .frame(width: size * 0.62, height: size)
                                    .offset(x: -size * 0.26)
                            }
                    }
                case .fullMoon:
                    Circle()
                        .fill(moonLight)
                case .waningGibbous:
                    phaseBase {
                        Circle()
                            .fill(moonLight)
                            .overlay {
                                Ellipse()
                                    .fill(moonShadow)
                                    .frame(width: size * 0.62, height: size)
                                    .offset(x: size * 0.26)
                            }
                    }
                case .lastQuarter:
                    phaseBase {
                        Circle()
                            .fill(moonShadow)
                            .overlay(alignment: .leading) {
                                Rectangle()
                                    .fill(moonLight)
                                    .frame(width: size * 0.5)
                            }
                    }
                case .waningCrescent:
                    phaseBase {
                        Circle()
                            .fill(moonLight)
                            .overlay {
                                Circle()
                                    .fill(moonShadow)
                                    .offset(x: size * 0.34)
                            }
                    }
                }
            }
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(borderColor, lineWidth: borderLineWidth)
            }
        }
    }

    @ViewBuilder
    private func phaseBase<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Circle()
                .fill(moonShadow)

            content()
        }
        .clipShape(Circle())
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
