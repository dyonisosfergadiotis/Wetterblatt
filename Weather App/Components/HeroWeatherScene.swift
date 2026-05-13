import Foundation
import SwiftUI

struct HeroWeatherScene: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Density: Equatable {
        case compact
        case regular

        var cornerRadius: CGFloat {
            switch self {
            case .compact: return 24
            case .regular: return 28
            }
        }

        var orbScale: CGFloat {
            switch self {
            case .compact: return 0.42
            case .regular: return 0.40
            }
        }
    }

    private enum SceneKind {
        case clear
        case partlyCloudy
        case overcast
        case fog
        case drizzle
        case rain
        case snow
        case storm

        var usesPrecipitation: Bool {
            switch self {
            case .drizzle, .rain, .storm:
                return true
            case .clear, .partlyCloudy, .overcast, .fog, .snow:
                return false
            }
        }
    }

    let weatherCode: Int
    let isDay: Bool
    var moonPhaseKind: MoonPhaseKind? = nil
    var density: Density = .regular
    var isAnimated = true
    var compositionYOffset: CGFloat = 0
    var effectContentMinY: CGFloat = 0
    var effectContentMaxY: CGFloat = 1
    var interactionOffset: CGSize = .zero
    var cornerRadius: CGFloat? = nil
    var rainIntensity: Double = 0

    @State private var motionPhase: CGFloat = 0
    @State private var precipitationPhase: CGFloat = 0

    private var usesReducedEffects: Bool {
        density == .compact
    }

    private var resolvedCornerRadius: CGFloat {
        cornerRadius ?? density.cornerRadius
    }

    private var allowsAmbientAnimation: Bool {
        isAnimated
        && !reduceMotion
        && !ProcessInfo.processInfo.isLowPowerModeEnabled
        && density == .regular
    }

    private var allowsPrecipitationAnimation: Bool {
        isAnimated
        && !reduceMotion
        && !ProcessInfo.processInfo.isLowPowerModeEnabled
        && kind.usesPrecipitation
    }

    private var kind: SceneKind {
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

    private var resolvedMoonPhaseKind: MoonPhaseKind {
        moonPhaseKind ?? MoonPhaseResolver.info(for: Date(), timeZone: .current).kind
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let motion = normalizedInteraction(for: size)
            let cornerRadius = resolvedCornerRadius

            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(stageGradient)

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(stageWash)

                Group {
                    backgroundAura(in: size, motion: motion)
                    horizonGlow(in: size, motion: motion)
                    sunSideOrb(in: size, motion: motion)
                    cloudField(in: size, motion: motion)
                    weatherField(in: size, motion: motion)
                    glossSweep(in: size, motion: motion)
                }
                .offset(y: compositionYOffset)
                .mask {
                    effectContentMask(in: size)
                }
            }
            .overlay {
                if cornerRadius > 0 {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(DesignTokens.border.opacity(isDay ? 0.20 : 0.30), lineWidth: 0.8)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .onAppear {
            updateAmbientAnimation(isEnabled: allowsAmbientAnimation)
            updatePrecipitationAnimation(isEnabled: allowsPrecipitationAnimation)
        }
        .onChange(of: allowsAmbientAnimation) { _, newValue in
            updateAmbientAnimation(isEnabled: newValue)
        }
        .onChange(of: allowsPrecipitationAnimation) { _, newValue in
            updatePrecipitationAnimation(isEnabled: newValue)
        }
        .onDisappear {
            motionPhase = 0
            precipitationPhase = 0
        }
    }

    private func updateAmbientAnimation(isEnabled: Bool) {
        guard isEnabled else {
            motionPhase = 0
            return
        }

        guard motionPhase == 0 else { return }
        withAnimation(.easeInOut(duration: 4.8).repeatForever(autoreverses: true)) {
            motionPhase = 1
        }
    }

    private func updatePrecipitationAnimation(isEnabled: Bool) {
        guard isEnabled else {
            precipitationPhase = 0
            return
        }

        guard precipitationPhase == 0 else { return }
        withAnimation(.linear(duration: rainAnimationDuration).repeatForever(autoreverses: false)) {
            precipitationPhase = 1
        }
    }

    private var stageGradient: LinearGradient {
        let trailing = DesignTokens.surface.opacity(isDay ? 0.95 : 0.88)
        let rainIntensity = visualRainIntensity

        switch kind {
        case .clear:
            return LinearGradient(
                colors: [accent.opacity(isDay ? 0.44 : 0.34), DesignTokens.chromeFill.opacity(0.28), trailing],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .partlyCloudy:
            return LinearGradient(
                colors: [accent.opacity(isDay ? 0.34 : 0.24), DesignTokens.chromeFill.opacity(0.24), trailing],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .overcast, .fog:
            return LinearGradient(
                colors: [DesignTokens.cloud.opacity(0.24), DesignTokens.chromeFill.opacity(0.22), trailing],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .drizzle, .rain:
            return LinearGradient(
                colors: [
                    rainySkyTop.opacity(0.34 + rainIntensity * 0.28),
                    rainySkyMid.opacity(0.26 + rainIntensity * 0.24),
                    trailing.opacity(0.90 - rainIntensity * 0.08),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .snow:
            return LinearGradient(
                colors: [DesignTokens.frost.opacity(0.28), DesignTokens.chromeFill.opacity(0.24), trailing],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .storm:
            return LinearGradient(
                colors: [
                    rainySkyTop.opacity(0.52 + rainIntensity * 0.22),
                    DesignTokens.storm.opacity(0.28 + rainIntensity * 0.20),
                    trailing.opacity(0.82),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var stageWash: LinearGradient {
        let rainDarkening = kind.usesPrecipitation ? visualRainIntensity : 0

        return LinearGradient(
            colors: [
                Color.white.opacity(max(0, (isDay ? 0.18 : 0.05) - rainDarkening * 0.08)),
                .clear,
                DesignTokens.background.opacity((isDay ? 0.04 : 0.14) + rainDarkening * 0.10),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var accent: Color {
        switch kind {
        case .clear:
            return isDay ? DesignTokens.sun : DesignTokens.moon
        case .partlyCloudy:
            return isDay ? DesignTokens.hazySun : DesignTokens.moon
        case .overcast, .fog:
            return DesignTokens.secondaryText
        case .drizzle:
            return DesignTokens.drizzle
        case .rain:
            return DesignTokens.rain
        case .snow:
            return DesignTokens.frost
        case .storm:
            return DesignTokens.sun
        }
    }

    private var glowTint: Color {
        switch kind {
        case .storm:
            return DesignTokens.storm
        case .snow:
            return DesignTokens.frost
        default:
            return accent
        }
    }

    private var cloudTint: Color {
        switch kind {
        case .storm:
            return DesignTokens.storm.opacity(isDay ? 0.96 : 0.88)
        case .overcast, .fog:
            return DesignTokens.ink.opacity(isDay ? 0.78 : 0.72)
        default:
            return DesignTokens.ink.opacity(isDay ? 0.58 : 0.52)
        }
    }

    private var cloudLevel: Int {
        switch weatherCode {
        case 1:
            return 1
        case 2:
            return 2
        case 3:
            return 3
        default:
            return 0
        }
    }

    private var visualRainIntensity: Double {
        let supplied = min(max(rainIntensity, 0), 1)
        let fallback: Double

        switch weatherCode {
        case 51:
            fallback = 0.18
        case 53, 56:
            fallback = 0.28
        case 55, 57:
            fallback = 0.38
        case 61, 80:
            fallback = 0.42
        case 63, 66, 81:
            fallback = 0.62
        case 65, 67, 82:
            fallback = 0.86
        case 95:
            fallback = 0.78
        case 96, 99:
            fallback = 0.95
        default:
            fallback = 0
        }

        return max(supplied, fallback)
    }

    private var rainAnimationDuration: TimeInterval {
        max(1.55, 2.85 - TimeInterval(visualRainIntensity) * 0.80)
    }

    private var rainySkyTop: Color {
        isDay
            ? Color(red: 0.48, green: 0.52, blue: 0.54)
            : Color(red: 0.19, green: 0.22, blue: 0.24)
    }

    private var rainySkyMid: Color {
        isDay
            ? Color(red: 0.58, green: 0.61, blue: 0.62)
            : Color(red: 0.28, green: 0.31, blue: 0.32)
    }

    private func normalizedInteraction(for size: CGSize) -> CGSize {
        let divisorX = max(size.width * 0.15, 1)
        let divisorY = max(size.height * 0.15, 1)

        return CGSize(
            width: min(max(interactionOffset.width / divisorX, -1), 1),
            height: min(max(interactionOffset.height / divisorY, -1), 1)
        )
    }

    private func effectContentMask(in size: CGSize) -> some View {
        let maxY = min(max(effectContentMaxY, 0), 1)
        let minY = min(max(effectContentMinY, 0), maxY)
        let visibleHeight = max(size.height * (maxY - minY), 0)
        let topFadeHeight = minY > 0 ? min(size.height * 0.05, visibleHeight) : 0
        let bottomFadeHeight = maxY < 1 ? min(size.height * 0.08, max(visibleHeight - topFadeHeight, 0)) : 0
        let solidHeight = max(visibleHeight - topFadeHeight - bottomFadeHeight, 0)

        return VStack(spacing: 0) {
            Spacer(minLength: 0)
                .frame(height: size.height * minY)

            if topFadeHeight > 0 {
                LinearGradient(
                    colors: [.clear, Color.white],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: topFadeHeight)
            }

            if solidHeight > 0 {
                Rectangle()
                    .fill(Color.white)
                    .frame(height: solidHeight)
            }

            if bottomFadeHeight > 0 {
                LinearGradient(
                    colors: [Color.white, .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: bottomFadeHeight)
            }

            Spacer(minLength: 0)
        }
        .frame(width: size.width, height: size.height, alignment: .top)
    }

    @ViewBuilder
    private func backgroundAura(in size: CGSize, motion: CGSize) -> some View {
        if kind == .clear || kind == .partlyCloudy {
            Ellipse()
                .fill(glowTint.opacity(isDay ? 0.12 : 0.18))
                .frame(width: size.width * 0.60, height: size.height * 0.32)
                .blur(radius: density == .compact ? 20 : 30)
                .offset(
                    x: size.width * 0.22 - motion.width * 10,
                    y: -size.height * 0.22 - motion.height * 6
                )
        } else {
            Circle()
                .fill(glowTint.opacity(isDay ? 0.18 : 0.24))
                .frame(width: size.width * 0.66, height: size.width * 0.66)
                .blur(radius: density == .compact ? 16 : 26)
                .offset(
                    x: size.width * 0.20 - motion.width * 12,
                    y: -size.height * 0.20 - motion.height * 8
                )
        }

        Ellipse()
            .fill(DesignTokens.chromeFill.opacity(isDay ? 0.30 : 0.12))
            .frame(width: size.width * 0.86, height: size.height * 0.62)
            .blur(radius: density == .compact ? 14 : 24)
            .offset(
                x: -size.width * 0.08 + motion.width * 10,
                y: size.height * 0.02 + motionPhase * 8
            )
    }

    @ViewBuilder
    private func horizonGlow(in size: CGSize, motion: CGSize) -> some View {
        Capsule()
            .fill(DesignTokens.ink.opacity(isDay ? 0.08 : 0.16))
            .frame(width: size.width * 0.72, height: density == .compact ? 16 : 18)
            .blur(radius: 1.8)
            .offset(y: size.height * 0.34 + motion.height * 4)

        Ellipse()
            .fill(Color.white.opacity(isDay ? 0.12 : 0.04))
            .frame(width: size.width * 0.54, height: density == .compact ? 24 : 28)
            .blur(radius: 10)
            .offset(
                x: motion.width * 10,
                y: size.height * 0.27 + motion.height * 2
            )
    }

    @ViewBuilder
    private func sunSideOrb(in size: CGSize, motion: CGSize) -> some View {
        if kind == .clear || kind == .partlyCloudy {
            let orbSize = min(size.width, size.height) * density.orbScale
            let haloSize = orbSize * (density == .compact ? 1.46 : 1.24)
            let compactX = size.width * 0.24
            let compactY = -size.height * 0.18

            ZStack {
                Circle()
                    .fill(accent.opacity(isDay ? 0.24 : 0.14))
                    .frame(width: haloSize, height: haloSize)
                    .blur(radius: density == .compact ? 16 : 14)

                if isDay {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.34),
                                    accent.opacity(0.98),
                                    accent.opacity(0.68),
                                ],
                                center: .topLeading,
                                startRadius: 4,
                                endRadius: orbSize * 0.78
                            )
                        )
                        .overlay(
                            Circle()
                                .stroke(accent.opacity(0.30), lineWidth: density == .compact ? 1.2 : 0.9)
                        )
                } else {
                    moonPhaseOrb(size: orbSize)
                }
            }
            .frame(width: orbSize, height: orbSize)
            .shadow(color: accent.opacity(isDay ? 0.28 : 0.24), radius: density == .compact ? 18 : 12, y: 5)
            .offset(
                x: density == .compact ? compactX : size.width * 0.30,
                y: density == .compact ? compactY : -size.height * 0.24
            )
        }
    }

    private func moonPhaseOrb(size: CGFloat) -> some View {
        MoonPhaseIconView(
            kind: resolvedMoonPhaseKind,
            moonLight: Color(red: 0.96, green: 0.92, blue: 0.74),
            moonShadow: DesignTokens.darkAccent.opacity(0.84),
            borderColor: accent.opacity(0.24),
            borderLineWidth: density == .compact ? 1.2 : 0.9
        )
        .frame(width: size, height: size)
        .overlay(alignment: .topLeading) {
            Circle()
                .fill(Color.white.opacity(0.14))
                .frame(width: size * 0.24, height: size * 0.24)
                .blur(radius: size * 0.04)
                .offset(x: size * 0.14, y: size * 0.12)
        }
    }

    @ViewBuilder
    private func cloudField(in size: CGSize, motion: CGSize) -> some View {
        switch kind {
        case .clear:
            EmptyView()

        case .partlyCloudy:
            WeatherCloudSymbol(
                tint: cloudTint.opacity(usesReducedEffects ? 0.88 : 1),
                width: size.width * (usesReducedEffects ? 0.30 : 0.32)
            )
                .offset(
                    x: -size.width * 0.18 + motion.width * 8 - motionPhase * 8,
                    y: size.height * 0.16 + motion.height * 4
                )

            if cloudLevel >= 2 {
                WeatherCloudSymbol(
                    tint: cloudTint.opacity(usesReducedEffects ? 0.58 : 0.70),
                    width: size.width * (usesReducedEffects ? 0.20 : 0.22)
                )
                    .offset(
                        x: size.width * 0.12 - motion.width * 6 + motionPhase * 6,
                        y: -size.height * 0.02 - motion.height * 4
                    )
            }

        case .overcast:
            WeatherCloudSymbol(
                tint: cloudTint.opacity(0.94),
                width: size.width * 0.42
            )
                .offset(
                    x: -size.width * 0.16 + motion.width * 8 - motionPhase * 8,
                    y: size.height * 0.02 - motion.height * 4
                )

            WeatherCloudSymbol(
                tint: cloudTint.opacity(0.82),
                width: size.width * 0.34
            )
                .offset(
                    x: size.width * 0.18 - motion.width * 7 + motionPhase * 7,
                    y: size.height * 0.16 + motion.height * 3
                )

            WeatherCloudSymbol(
                tint: cloudTint.opacity(0.68),
                width: size.width * 0.26
            )
            .offset(
                x: -size.width * 0.28 + motion.width * 5 + motionPhase * 5,
                y: size.height * 0.24 + motion.height * 3
            )

        case .drizzle, .rain, .storm:
            RainCloudDeck(
                tint: rainySkyMid,
                undersideTint: DesignTokens.cloud,
                intensity: visualRainIntensity,
                compact: density == .compact,
                phase: motionPhase
            )
            .frame(width: size.width * 1.34, height: size.height * (density == .compact ? 0.31 : 0.34))
            .offset(
                x: -size.width * 0.18 + motion.width * 5,
                y: -size.height * (density == .compact ? 0.28 : 0.30) - motion.height * 3
            )

        case .fog, .snow:
            EmptyView()
        }
    }

    @ViewBuilder
    private func weatherField(in size: CGSize, motion: CGSize) -> some View {
        switch kind {
        case .fog:
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(DesignTokens.cloud.opacity(isDay ? 0.18 : 0.28))
                .frame(width: size.width * 0.82, height: size.height * 0.52)
                .blur(radius: density == .compact ? 16 : 22)
                .offset(
                    x: motion.width * 6,
                    y: size.height * 0.04 + motion.height * 3
                )

            FogBands(
                tint: DesignTokens.mist,
                compact: density == .compact,
                phase: motionPhase
            )
            .frame(width: size.width * 0.86, height: size.height * 0.38)
            .offset(
                x: motion.width * 8,
                y: size.height * 0.14 + motion.height * 4
            )

        case .drizzle:
            RainDropField(
                tint: DesignTokens.drizzle,
                intensity: max(0.18, visualRainIntensity * 0.70),
                compact: density == .compact,
                phase: precipitationPhase
            )
            .frame(width: size.width * 0.76, height: size.height * 0.52)
            .offset(
                x: -size.width * 0.06 + motion.width * 8,
                y: -size.height * 0.06 + motion.height * 4
            )

        case .rain:
            RainDropField(
                tint: DesignTokens.rain,
                intensity: visualRainIntensity,
                compact: density == .compact,
                phase: precipitationPhase
            )
            .frame(width: size.width * 0.82, height: size.height * 0.58)
            .offset(
                x: -size.width * 0.07 + motion.width * 8,
                y: -size.height * 0.04 + motion.height * 4
            )

        case .snow:
            SnowSwarm(
                tint: DesignTokens.frost,
                count: density == .compact ? 9 : 12,
                phase: motionPhase
            )
            .frame(width: size.width * 0.88, height: size.height * 0.54)
            .offset(
                x: motion.width * 8,
                y: -size.height * 0.02 + motion.height * 5
            )

        case .storm:
            RainDropField(
                tint: DesignTokens.rain.opacity(0.96),
                intensity: min(1, visualRainIntensity + 0.16),
                compact: density == .compact,
                phase: precipitationPhase
            )
            .frame(width: size.width * 0.88, height: size.height * 0.60)
            .offset(
                x: -size.width * 0.07 + motion.width * 8,
                y: -size.height * 0.04 + motion.height * 4
            )

            Image(systemName: "bolt.fill")
                .font(.system(size: min(size.width, size.height) * 0.14, weight: .bold))
                .foregroundStyle(DesignTokens.sun.opacity(0.94))
                .shadow(color: DesignTokens.sun.opacity(0.22), radius: 10, y: 4)
                .offset(
                    x: size.width * 0.20 - motion.width * 8,
                    y: size.height * 0.02 - motion.height * 4 + motionPhase * 3
                )

        case .clear, .partlyCloudy, .overcast:
            EmptyView()
        }
    }

    @ViewBuilder
    private func glossSweep(in size: CGSize, motion: CGSize) -> some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(isDay ? 0.14 : 0.05),
                        Color.white.opacity(isDay ? 0.03 : 0.01),
                        .clear,
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: size.width * 0.82, height: size.height * 0.16)
            .blur(radius: density == .compact ? 10 : 14)
            .rotationEffect(.degrees(-14))
            .offset(
                x: -size.width * 0.06 + motion.width * 10,
                y: -size.height * 0.28 + motion.height * 4
            )
    }
}

private struct WeatherCloudSymbol: View {
    let tint: Color
    let width: CGFloat

    var body: some View {
        Image(systemName: "cloud.fill")
            .symbolRenderingMode(.hierarchical)
            .font(.system(size: width * 0.68, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: width, height: width * 0.54)
            .shadow(color: tint.opacity(0.12), radius: 6, y: 3)
            .shadow(color: DesignTokens.shadow.opacity(0.16), radius: 10, y: 6)
    }
}

private struct RainCloudDeck: View {
    let tint: Color
    let undersideTint: Color
    let intensity: Double
    let compact: Bool
    let phase: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let normalizedIntensity = CGFloat(min(max(intensity, 0), 1))
            let drift = CGFloat(sin(Double(phase) * .pi * 2)) * (compact ? 4 : 7)

            ZStack(alignment: .top) {
                RainCloudShelfShape(intensity: normalizedIntensity, phase: phase)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.08),
                                tint.opacity(0.50 + intensity * 0.12),
                                undersideTint.opacity(0.44 + intensity * 0.17),
                                DesignTokens.shadow.opacity(0.18 + intensity * 0.14),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: width * 1.03, height: height * (0.58 + normalizedIntensity * 0.06))
                    .blur(radius: compact ? 0.5 : 0.8)
                    .offset(x: drift, y: height * 0.04)
                    .shadow(color: DesignTokens.shadow.opacity(0.22 + intensity * 0.08), radius: compact ? 12 : 18, y: height * 0.05)

                RainCloudShelfShape(intensity: normalizedIntensity * 0.82, phase: 1 - phase)
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(0.22 + intensity * 0.08),
                                undersideTint.opacity(0.32 + intensity * 0.16),
                                .clear,
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: width * 0.92, height: height * (0.36 + normalizedIntensity * 0.05))
                    .blur(radius: compact ? 7 : 11)
                    .offset(x: -drift * 0.45, y: height * (0.28 + normalizedIntensity * 0.03))

                ForEach(0..<8, id: \.self) { index in
                    let progress = CGFloat(index) / 7
                    let wave = CGFloat(sin(Double(progress * .pi * 2 + phase * 0.45)))
                    let puffWidth = width * (0.16 + CGFloat(index % 4) * 0.026 + normalizedIntensity * 0.018)
                    let puffHeight = height * (0.24 + CGFloat((index + 1) % 3) * 0.035 + normalizedIntensity * 0.025)
                    let x = width * (-0.43 + progress * 0.86) + drift * CGFloat(index.isMultiple(of: 2) ? -0.7 : 0.7)
                    let y = height * (0.02 + CGFloat(index % 3) * 0.025) + wave * (compact ? 1.4 : 2.2)

                    Ellipse()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.07),
                                    tint.opacity(0.40 + intensity * 0.13),
                                    undersideTint.opacity(0.34 + intensity * 0.16),
                                    DesignTokens.shadow.opacity(0.08 + intensity * 0.06),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: puffWidth, height: puffHeight)
                        .blur(radius: compact ? 1.8 : 2.6)
                        .offset(x: x, y: y)
                }

                RainCloudUndersideShape(intensity: normalizedIntensity, phase: phase)
                    .fill(
                        LinearGradient(
                            colors: [
                                undersideTint.opacity(0.50 + intensity * 0.18),
                                DesignTokens.shadow.opacity(0.18 + intensity * 0.15),
                                .clear,
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: width * (0.84 + normalizedIntensity * 0.08), height: height * 0.22)
                    .blur(radius: compact ? 2.8 : 4.0)
                    .offset(x: drift * 0.25, y: height * (0.39 + normalizedIntensity * 0.035))

                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(DesignTokens.shadow.opacity((0.09 + intensity * 0.045) * (index == 0 ? 1 : 0.72)))
                        .frame(width: width * (0.74 - CGFloat(index) * 0.12), height: compact ? 4 : 5)
                        .blur(radius: compact ? 5 : 7)
                        .offset(
                            x: drift * CGFloat(index == 1 ? -0.4 : 0.4),
                            y: height * (0.52 + CGFloat(index) * 0.045)
                        )
                }
            }
            .frame(width: width, height: height, alignment: .top)
        }
    }
}

private struct RainCloudShelfShape: Shape {
    var intensity: CGFloat
    var phase: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(intensity, phase) }
        set {
            intensity = newValue.first
            phase = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        let wave = height * (0.075 + intensity * 0.035)
        let shift = CGFloat(sin(Double(phase) * .pi * 2)) * width * 0.018
        let top = rect.minY + height * 0.12
        let bottom = rect.minY + height * (0.64 + intensity * 0.06)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX - width * 0.04, y: top + wave * 0.30))
        path.addCurve(
            to: CGPoint(x: rect.maxX + width * 0.04, y: top + wave * 0.05),
            control1: CGPoint(x: rect.minX + width * 0.24 + shift, y: rect.minY - wave * 0.15),
            control2: CGPoint(x: rect.minX + width * 0.68 - shift, y: rect.minY + wave * 0.55)
        )
        path.addLine(to: CGPoint(x: rect.maxX + width * 0.04, y: bottom - wave * 0.20))
        path.addCurve(
            to: CGPoint(x: rect.minX + width * 0.78, y: bottom + wave * 0.30),
            control1: CGPoint(x: rect.maxX - width * 0.06, y: bottom + wave * 0.90),
            control2: CGPoint(x: rect.minX + width * 0.91 + shift, y: bottom - wave * 0.95)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + width * 0.52, y: bottom - wave * 0.18),
            control1: CGPoint(x: rect.minX + width * 0.68 - shift, y: bottom + wave * 1.05),
            control2: CGPoint(x: rect.minX + width * 0.62, y: bottom - wave * 1.00)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + width * 0.25, y: bottom + wave * 0.22),
            control1: CGPoint(x: rect.minX + width * 0.42 + shift, y: bottom + wave * 0.70),
            control2: CGPoint(x: rect.minX + width * 0.34 - shift, y: bottom - wave * 0.62)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX - width * 0.04, y: bottom - wave * 0.16),
            control1: CGPoint(x: rect.minX + width * 0.14 + shift, y: bottom + wave * 0.82),
            control2: CGPoint(x: rect.minX + width * 0.05, y: bottom - wave * 0.48)
        )
        path.closeSubpath()
        return path
    }
}

private struct RainCloudUndersideShape: Shape {
    var intensity: CGFloat
    var phase: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(intensity, phase) }
        set {
            intensity = newValue.first
            phase = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        let wave = height * (0.10 + intensity * 0.05)
        let shift = CGFloat(cos(Double(phase) * .pi * 2)) * width * 0.014
        let top = rect.minY + height * 0.18
        let bottom = rect.minY + height * 0.64

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: top))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: top + wave * 0.10),
            control1: CGPoint(x: rect.minX + width * 0.28 + shift, y: top - wave * 0.42),
            control2: CGPoint(x: rect.minX + width * 0.70 - shift, y: top + wave * 0.46)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX, y: bottom),
            control1: CGPoint(x: rect.maxX - width * 0.14, y: bottom + wave * 0.66),
            control2: CGPoint(x: rect.minX + width * 0.24 + shift, y: bottom - wave * 0.74)
        )
        path.closeSubpath()
        return path
    }
}

private struct RainDropField: View {
    let tint: Color
    let intensity: Double
    let compact: Bool
    let phase: CGFloat

    private var backgroundStreakCount: Int {
        compact
            ? Int((7 + intensity * 7).rounded())
            : Int((12 + intensity * 14).rounded())
    }

    private var foregroundStreakCount: Int {
        compact
            ? Int((3 + intensity * 4).rounded())
            : Int((5 + intensity * 7).rounded())
    }

    private var rippleCount: Int {
        intensity < 0.48 ? 0 : (compact ? 2 : Int((3 + intensity * 4).rounded()))
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack(alignment: .topLeading) {
                RainCurtainLayer(
                    tint: tint,
                    size: size,
                    count: compact ? 3 : 5,
                    intensity: intensity,
                    compact: compact,
                    phase: phase
                )

                RainStreakLayer(
                    tint: tint,
                    size: size,
                    count: backgroundStreakCount,
                    intensity: intensity,
                    compact: compact,
                    phase: phase,
                    foreground: false
                )

                RainStreakLayer(
                    tint: tint,
                    size: size,
                    count: foregroundStreakCount,
                    intensity: intensity,
                    compact: compact,
                    phase: (phase + 0.34).truncatingRemainder(dividingBy: 1),
                    foreground: true
                )

                RainMistLayer(
                    tint: tint,
                    size: size,
                    intensity: intensity,
                    compact: compact,
                    phase: phase
                )

                RainSurfaceRippleLayer(
                    tint: tint,
                    size: size,
                    count: rippleCount,
                    intensity: intensity,
                    compact: compact,
                    phase: phase
                )
            }
            .compositingGroup()
            .mask {
                LinearGradient(
                    colors: [
                        .clear,
                        Color.white.opacity(0.92),
                        Color.white,
                        Color.white.opacity(0.74),
                        .clear,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .blur(radius: compact ? 0.02 : 0.08)
        }
    }
}

private struct RainCurtainLayer: View {
    let tint: Color
    let size: CGSize
    let count: Int
    let intensity: Double
    let compact: Bool
    let phase: CGFloat

    var body: some View {
        let width = size.width
        let height = size.height
        let normalizedIntensity = CGFloat(min(max(intensity, 0), 1))
        let drift = CGFloat(sin(Double(phase) * .pi * 2)) * width * (compact ? 0.010 : 0.016)

        ZStack(alignment: .topLeading) {
            ForEach(0..<count, id: \.self) { index in
                let progress = CGFloat(index) / CGFloat(max(count - 1, 1))
                let curtainWidth = width * (0.10 + normalizedIntensity * 0.035 + CGFloat(index % 2) * 0.018)
                let opacity = 0.050 + intensity * 0.055

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                tint.opacity(opacity * 0.55),
                                tint.opacity(opacity),
                                tint.opacity(opacity * 0.30),
                                .clear,
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: curtainWidth, height: height * (0.88 + normalizedIntensity * 0.10))
                    .blur(radius: compact ? 5 : 8)
                    .rotationEffect(.degrees(8 + Double(normalizedIntensity) * 3))
                    .offset(
                        x: width * (-0.02 + progress * 0.90) - drift * CGFloat(index + 1),
                        y: height * (-0.08 + CGFloat(index % 3) * 0.035)
                    )
            }
        }
    }
}

private struct RainStreakLayer: View {
    let tint: Color
    let size: CGSize
    let count: Int
    let intensity: Double
    let compact: Bool
    let phase: CGFloat
    let foreground: Bool

    var body: some View {
        let width = size.width
        let height = size.height
        let normalizedIntensity = CGFloat(min(max(intensity, 0), 1))
        let lineWidth = foreground
            ? (compact ? 1.15 : 1.28) + normalizedIntensity * 0.32
            : (compact ? 0.72 : 0.86) + normalizedIntensity * 0.22
        let baseOpacity = foreground
            ? min(0.52, 0.16 + intensity * 0.22)
            : min(0.34, 0.10 + intensity * 0.16)

        ZStack(alignment: .topLeading) {
            ForEach(0..<count, id: \.self) { index in
                let progress = CGFloat(index) / CGFloat(max(count - 1, 1))
                let seed = CGFloat((index * (foreground ? 31 : 43)) % 100) / 100
                let jitter = CGFloat(((index * 17) % 15) - 7) / 100
                let fall = (phase + seed).truncatingRemainder(dividingBy: 1)
                let lengthNoise = CGFloat((index * 11) % 5) * 0.012
                let length = max(
                    compact ? 10 : 14,
                    height * ((foreground ? 0.085 : 0.060) + normalizedIntensity * (foreground ? 0.030 : 0.026) + lengthNoise)
                )
                let opacityNoise = 0.86 + Double((index * 7) % 5) * 0.035
                let opacity = baseOpacity * opacityNoise
                let diagonalDrift = fall * width * (0.048 + normalizedIntensity * 0.030)
                let x = width * (0.06 + progress * 0.88 + jitter) - diagonalDrift
                let y = -height * 0.24 + fall * height * 1.34 + CGFloat(index % 4) * (compact ? 1.5 : 2.4)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(opacity * 0.36),
                                tint.opacity(opacity),
                                tint.opacity(opacity * 0.18),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: lineWidth, height: length)
                    .rotationEffect(.degrees(10 + Double(normalizedIntensity) * 4))
                    .shadow(color: tint.opacity(foreground ? 0.08 : 0.04), radius: foreground ? 2.2 : 1.2, y: 1)
                    .offset(x: x, y: y)
            }
        }
    }
}

private struct RainMistLayer: View {
    let tint: Color
    let size: CGSize
    let intensity: Double
    let compact: Bool
    let phase: CGFloat

    var body: some View {
        let width = size.width
        let height = size.height
        let normalizedIntensity = CGFloat(min(max(intensity, 0), 1))
        let drift = CGFloat(sin(Double(phase) * .pi * 2)) * (compact ? 3 : 5)

        ZStack(alignment: .bottomLeading) {
            Ellipse()
                .fill(tint.opacity(0.055 + intensity * 0.070))
                .frame(width: width * (0.86 + normalizedIntensity * 0.12), height: height * 0.18)
                .blur(radius: compact ? 7 : 10)
                .offset(x: width * 0.06 + drift, y: -height * 0.01)

            ForEach(0..<2, id: \.self) { index in
                Capsule()
                    .fill(tint.opacity((0.06 + intensity * 0.055) * (index == 0 ? 1 : 0.72)))
                    .frame(width: width * (index == 0 ? 0.76 : 0.58), height: compact ? 2.2 : 3.0)
                    .blur(radius: compact ? 2.8 : 3.6)
                    .offset(
                        x: width * (index == 0 ? 0.12 : 0.25) - drift * CGFloat(index == 0 ? 1 : -1),
                        y: -height * (index == 0 ? 0.18 : 0.10)
                    )
            }
        }
    }
}

private struct RainSurfaceRippleLayer: View {
    let tint: Color
    let size: CGSize
    let count: Int
    let intensity: Double
    let compact: Bool
    let phase: CGFloat

    var body: some View {
        let width = size.width
        let height = size.height
        let normalizedIntensity = CGFloat(min(max(intensity, 0), 1))

        ZStack(alignment: .topLeading) {
            ForEach(0..<count, id: \.self) { index in
                let progress = CGFloat(index) / CGFloat(max(count - 1, 1))
                let seed = CGFloat((index * 29) % 100) / 100
                let pulse = (phase + seed).truncatingRemainder(dividingBy: 1)
                let rippleWidth = (compact ? 5.5 : 7.5) + normalizedIntensity * 5
                let opacity = (0.08 + intensity * 0.09) * Double(1 - pulse * 0.70)

                Capsule()
                    .fill(tint.opacity(opacity))
                    .frame(width: rippleWidth, height: compact ? 1.1 : 1.4)
                    .scaleEffect(x: 0.72 + pulse * 0.74, y: 1, anchor: .center)
                    .offset(
                        x: width * (0.12 + progress * 0.76),
                        y: height * (0.75 + CGFloat(index % 3) * 0.045)
                    )
            }
        }
    }
}

private struct SnowSwarm: View {
    let tint: Color
    let count: Int
    let phase: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack(alignment: .topLeading) {
                ForEach(0..<count, id: \.self) { index in
                    let progress = CGFloat(index) / CGFloat(max(count - 1, 1))
                    let size = CGFloat(index.isMultiple(of: 3) ? 5.6 : 4.0)
                    let verticalWave = phase * CGFloat(10 + (index % 4) * 3)

                    Circle()
                        .fill(tint.opacity(index.isMultiple(of: 2) ? 0.96 : 0.74))
                        .frame(width: size, height: size)
                        .overlay {
                            Circle()
                                .fill(Color.white.opacity(0.18))
                                .scaleEffect(0.46)
                                .blur(radius: 0.2)
                        }
                        .shadow(color: tint.opacity(0.16), radius: 3, y: 1.5)
                        .offset(
                            x: width * (0.06 + progress * 0.86) + CGFloat(index.isMultiple(of: 2) ? -4 : 4),
                            y: height * (0.06 + progress * 0.42) + verticalWave
                        )
                }
            }
        }
    }
}

private struct FogBands: View {
    let tint: Color
    let compact: Bool
    let phase: CGFloat

    var body: some View {
        VStack(spacing: compact ? 6 : 7) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(tint.opacity(index == 1 ? 0.76 : 0.50))
                    .frame(width: compact ? 132 - CGFloat(index * 20) : 164 - CGFloat(index * 22), height: compact ? 6 : 7)
                    .offset(x: (index.isMultiple(of: 2) ? -10 : 8) + phase * CGFloat(index.isMultiple(of: 2) ? 14 : -10))
            }
        }
        .blur(radius: 0.3)
    }
}
