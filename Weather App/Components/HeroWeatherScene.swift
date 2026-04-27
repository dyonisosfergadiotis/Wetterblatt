import SwiftUI

struct HeroWeatherScene: View {
    enum Density: Equatable {
        case compact
        case regular

        var cornerRadius: CGFloat {
            switch self {
            case .compact: return 24
            case .regular: return 30
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
    }

    let weatherCode: Int
    let isDay: Bool
    var density: Density = .regular

    @State private var animateScene = false

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

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                RoundedRectangle(cornerRadius: density.cornerRadius, style: .continuous)
                    .fill(stageGradient)
                    .overlay {
                        RoundedRectangle(cornerRadius: density.cornerRadius, style: .continuous)
                            .stroke(accent.opacity(isDay ? 0.18 : 0.24), lineWidth: 0.8)
                    }

                Circle()
                    .fill(accent.opacity(isDay ? 0.18 : 0.26))
                    .frame(width: size.width * 0.58, height: size.width * 0.58)
                    .blur(radius: density == .compact ? 8 : 12)
                    .offset(
                        x: size.width * 0.16 + (animateScene ? 6 : -4),
                        y: -size.height * 0.14
                    )

                Circle()
                    .fill(DesignTokens.chromeFill.opacity(isDay ? 0.7 : 0.2))
                    .frame(width: size.width * 0.88, height: size.height * 0.84)
                    .blur(radius: density == .compact ? 18 : 24)
                    .offset(
                        x: -size.width * 0.08,
                        y: size.height * 0.08 + (animateScene ? 4 : -4)
                    )

                orb(in: size)
                atmosphere(in: size)
                horizon(in: size)
            }
            .clipShape(RoundedRectangle(cornerRadius: density.cornerRadius, style: .continuous))
        }
        .compositingGroup()
        .onAppear {
            guard !animateScene else { return }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                animateScene = true
            }
        }
    }

    private var accent: Color {
        switch kind {
        case .clear:
            return isDay ? DesignTokens.sun : DesignTokens.moon
        case .partlyCloudy:
            return isDay ? DesignTokens.hazySun : DesignTokens.moon
        case .overcast, .fog:
            return DesignTokens.secondaryText
        case .drizzle, .rain:
            return DesignTokens.rain
        case .snow:
            return DesignTokens.frost
        case .storm:
            return DesignTokens.storm
        }
    }

    private var stageGradient: LinearGradient {
        let middle = DesignTokens.chromeFill.opacity(isDay ? 0.78 : 0.22)
        let trailing = DesignTokens.surface.opacity(isDay ? 0.94 : 0.86)

        switch kind {
        case .clear:
            return LinearGradient(
                colors: [accent.opacity(0.32), middle, trailing],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .partlyCloudy:
            return LinearGradient(
                colors: [accent.opacity(0.22), middle, trailing],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .overcast, .fog:
            return LinearGradient(
                colors: [DesignTokens.cloud.opacity(0.18), middle, trailing],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .drizzle, .rain:
            return LinearGradient(
                colors: [DesignTokens.rain.opacity(0.2), middle, trailing],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .snow:
            return LinearGradient(
                colors: [DesignTokens.frost.opacity(0.24), middle, trailing],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .storm:
            return LinearGradient(
                colors: [
                    DesignTokens.storm.opacity(0.28),
                    DesignTokens.darkAccent.opacity(0.22),
                    trailing,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    @ViewBuilder
    private func orb(in size: CGSize) -> some View {
        if kind != .overcast, kind != .fog, kind != .storm {
            let orbSize = min(size.width, size.height) * (density == .compact ? 0.34 : 0.38)

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(isDay ? 1.0 : 0.92),
                                accent.opacity(isDay ? 0.72 : 0.55),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Circle()
                            .stroke(DesignTokens.chromeFill.opacity(isDay ? 0.55 : 0.3), lineWidth: 0.8)
                    )

                if !isDay {
                    Circle()
                        .fill(DesignTokens.surface.opacity(0.92))
                        .frame(width: orbSize * 0.72, height: orbSize * 0.72)
                        .offset(x: orbSize * 0.18, y: -orbSize * 0.1)
                }
            }
            .frame(width: orbSize, height: orbSize)
            .shadow(color: accent.opacity(isDay ? 0.16 : 0.22), radius: 10, y: 4)
            .offset(
                x: size.width * 0.22 + (animateScene ? 4 : -2),
                y: size.height * 0.06 + (animateScene ? -5 : 2)
            )
        }
    }

    @ViewBuilder
    private func atmosphere(in size: CGSize) -> some View {
        switch kind {
        case .clear:
            CloudCluster(
                fill: DesignTokens.cloud.opacity(0.78),
                width: size.width * 0.34
            )
            .offset(
                x: size.width * 0.08 + (animateScene ? -6 : 4),
                y: size.height * 0.28
            )

        case .partlyCloudy:
            CloudCluster(
                fill: DesignTokens.cloud.opacity(0.92),
                width: size.width * 0.5
            )
            .offset(
                x: size.width * 0.04 + (animateScene ? -5 : 4),
                y: size.height * 0.22
            )

            CloudCluster(
                fill: DesignTokens.cloud.opacity(0.6),
                width: size.width * 0.28
            )
            .offset(
                x: size.width * 0.44 + (animateScene ? 4 : -4),
                y: size.height * 0.12
            )

        case .overcast:
            CloudCluster(
                fill: DesignTokens.cloud.opacity(0.96),
                width: size.width * 0.64
            )
            .offset(
                x: size.width * 0.02 + (animateScene ? -4 : 2),
                y: size.height * 0.17
            )

            CloudCluster(
                fill: DesignTokens.cloud.opacity(0.78),
                width: size.width * 0.4
            )
            .offset(
                x: size.width * 0.42 + (animateScene ? 3 : -3),
                y: size.height * 0.08
            )

        case .fog:
            CloudCluster(
                fill: DesignTokens.cloud.opacity(0.9),
                width: size.width * 0.56
            )
            .offset(
                x: size.width * 0.08 + (animateScene ? -4 : 2),
                y: size.height * 0.18
            )

            FogBands(
                tint: DesignTokens.mist,
                width: size.width * 0.72
            )
            .offset(y: size.height * 0.22)

        case .drizzle:
            CloudCluster(
                fill: DesignTokens.cloud.opacity(0.94),
                width: size.width * 0.58
            )
            .offset(
                x: size.width * 0.06 + (animateScene ? -3 : 3),
                y: size.height * 0.18
            )

            RainCurtain(
                tint: DesignTokens.drizzle,
                count: 5,
                length: density == .compact ? 12 : 14
            )
            .offset(x: size.width * 0.1, y: size.height * 0.4)

        case .rain:
            CloudCluster(
                fill: DesignTokens.cloud.opacity(0.92),
                width: size.width * 0.62
            )
            .offset(
                x: size.width * 0.04 + (animateScene ? -3 : 3),
                y: size.height * 0.16
            )

            RainCurtain(
                tint: DesignTokens.rain,
                count: 6,
                length: density == .compact ? 16 : 18
            )
            .offset(x: size.width * 0.08, y: size.height * 0.4)

        case .snow:
            CloudCluster(
                fill: DesignTokens.cloud.opacity(0.94),
                width: size.width * 0.58
            )
            .offset(
                x: size.width * 0.08 + (animateScene ? -3 : 3),
                y: size.height * 0.18
            )

            SnowBurst(
                tint: DesignTokens.frost,
                rows: density == .compact ? 2 : 3
            )
            .offset(x: size.width * 0.14, y: size.height * 0.42)

        case .storm:
            CloudCluster(
                fill: DesignTokens.storm.opacity(0.96),
                width: size.width * 0.68
            )
            .offset(
                x: size.width * 0.04 + (animateScene ? -4 : 3),
                y: size.height * 0.14
            )

            RainCurtain(
                tint: DesignTokens.rain.opacity(0.92),
                count: 5,
                length: density == .compact ? 15 : 18
            )
            .offset(x: size.width * 0.1, y: size.height * 0.38)

            Image(systemName: "bolt.fill")
                .font(.system(size: density == .compact ? 20 : 24, weight: .bold))
                .foregroundStyle(DesignTokens.sun.opacity(0.92))
                .shadow(color: DesignTokens.sun.opacity(0.24), radius: 8, y: 2)
                .offset(
                    x: size.width * 0.26 + (animateScene ? 2 : -2),
                    y: size.height * 0.34
                )
        }
    }

    private func horizon(in size: CGSize) -> some View {
        ZStack {
            Capsule()
                .fill(DesignTokens.ink.opacity(isDay ? 0.08 : 0.16))
                .frame(width: size.width * 0.74, height: density == .compact ? 10 : 12)
                .blur(radius: 1.4)

            Capsule()
                .fill(DesignTokens.chromeFill.opacity(isDay ? 0.48 : 0.16))
                .frame(width: size.width * 0.64, height: density == .compact ? 22 : 26)
                .overlay(
                    Capsule()
                        .stroke(DesignTokens.border.opacity(0.18), lineWidth: 0.8)
                )
        }
        .offset(y: size.height * 0.35)
    }
}

private struct CloudCluster: View {
    let fill: Color
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Capsule()
                .fill(fill)
                .frame(width: width * 0.78, height: width * 0.24)
                .offset(x: width * 0.1, y: width * 0.22)

            Circle()
                .fill(fill)
                .frame(width: width * 0.3, height: width * 0.3)
                .offset(x: width * 0.04, y: width * 0.18)

            Circle()
                .fill(fill)
                .frame(width: width * 0.42, height: width * 0.42)
                .offset(x: width * 0.22, y: width * 0.02)

            Circle()
                .fill(fill)
                .frame(width: width * 0.28, height: width * 0.28)
                .offset(x: width * 0.56, y: width * 0.16)
        }
        .frame(width: width, height: width * 0.58, alignment: .bottomLeading)
        .shadow(color: DesignTokens.shadow.opacity(0.25), radius: 10, y: 5)
    }
}

private struct RainCurtain: View {
    let tint: Color
    let count: Int
    let length: CGFloat

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.2, style: .continuous)
                    .fill(tint.opacity(index.isMultiple(of: 2) ? 0.95 : 0.72))
                    .frame(width: 2.4, height: length - CGFloat(index % 3) * 3)
                    .rotationEffect(.degrees(14))
                    .offset(y: CGFloat(index % 2) * 4)
            }
        }
    }
}

private struct SnowBurst: View {
    let tint: Color
    let rows: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(0..<4, id: \.self) { column in
                        Circle()
                            .fill(tint.opacity(column.isMultiple(of: 2) ? 0.95 : 0.72))
                            .frame(
                                width: row == 0 && column == 1 ? 5.5 : 4,
                                height: row == 0 && column == 1 ? 5.5 : 4
                            )
                            .offset(y: CGFloat((row + column) % 2) * 3)
                    }
                }
                .padding(.leading, CGFloat(row * 6))
            }
        }
    }
}

private struct FogBands: View {
    let tint: Color
    let width: CGFloat

    var body: some View {
        VStack(spacing: 7) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(tint.opacity(index == 1 ? 0.7 : 0.48))
                    .frame(width: width - CGFloat(index * 20), height: 7)
            }
        }
    }
}
