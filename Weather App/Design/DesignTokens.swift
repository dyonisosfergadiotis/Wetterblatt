import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum DesignTokens {
    static let background = dynamicColor(
        light: rgb(0.96, 0.94, 0.91),
        dark: rgb(0.08, 0.07, 0.06)
    )
    static let surface = dynamicColor(
        light: rgb(0.93, 0.91, 0.86),
        dark: rgb(0.13, 0.11, 0.10)
    )
    static let muted = dynamicColor(
        light: rgb(0.87, 0.84, 0.77),
        dark: rgb(0.19, 0.17, 0.15)
    )
    static let border = dynamicColor(
        light: rgb(0.78, 0.75, 0.67),
        dark: rgb(0.31, 0.27, 0.23)
    )
    static let secondaryText = dynamicColor(
        light: rgb(0.60, 0.56, 0.49),
        dark: rgb(0.74, 0.69, 0.61)
    )
    static let tertiaryText = dynamicColor(
        light: rgb(0.42, 0.38, 0.31),
        dark: rgb(0.62, 0.57, 0.49)
    )
    static let ink = dynamicColor(
        light: rgb(0.16, 0.13, 0.08),
        dark: rgb(0.95, 0.92, 0.86)
    )
    static let rain = dynamicColor(
        light: rgb(0.28, 0.48, 0.73),
        dark: rgb(0.47, 0.68, 0.90)
    )
    static let drizzle = dynamicColor(
        light: rgb(0.42, 0.56, 0.71),
        dark: rgb(0.58, 0.72, 0.86)
    )
    static let sun = dynamicColor(
        light: rgb(0.78, 0.58, 0.35),
        dark: rgb(0.90, 0.73, 0.44)
    )
    static let hazySun = dynamicColor(
        light: rgb(0.71, 0.60, 0.42),
        dark: rgb(0.84, 0.73, 0.52)
    )
    static let moon = dynamicColor(
        light: rgb(0.52, 0.58, 0.71),
        dark: rgb(0.70, 0.76, 0.88)
    )
    static let cloud = dynamicColor(
        light: rgb(0.97, 0.95, 0.91),
        dark: rgb(0.31, 0.29, 0.28)
    )
    static let mist = dynamicColor(
        light: rgba(1.0, 1.0, 1.0, 0.66),
        dark: rgba(0.84, 0.84, 0.86, 0.26)
    )
    static let frost = dynamicColor(
        light: rgb(0.77, 0.85, 0.92),
        dark: rgb(0.73, 0.82, 0.91)
    )
    static let storm = dynamicColor(
        light: rgb(0.40, 0.45, 0.52),
        dark: rgb(0.57, 0.62, 0.69)
    )
    static let darkAccent = dynamicColor(
        light: rgb(0.24, 0.18, 0.10),
        dark: rgb(0.84, 0.73, 0.58)
    )
    static let chromeFill = dynamicColor(
        light: rgba(0.98, 0.99, 1.0, 0.58),
        dark: rgba(0.12, 0.15, 0.20, 0.82)
    )
    static let chromeWash = dynamicColor(
        light: rgba(1.0, 1.0, 1.0, 0.24),
        dark: rgba(0.96, 0.98, 1.0, 0.05)
    )
    static let trackFill = dynamicColor(
        light: rgba(1.0, 1.0, 1.0, 0.40),
        dark: rgba(0.27, 0.24, 0.20, 0.92)
    )

    static let paperGradient = LinearGradient(
        colors: [
            dynamicColor(
                light: rgb(0.98, 0.94, 0.88),
                dark: rgb(0.15, 0.11, 0.14)
            ),
            dynamicColor(
                light: rgb(0.86, 0.92, 0.97),
                dark: rgb(0.09, 0.16, 0.24)
            ),
            dynamicColor(
                light: rgb(0.97, 0.86, 0.75),
                dark: rgb(0.20, 0.14, 0.19)
            ),
            dynamicColor(
                light: rgb(0.71, 0.82, 0.90),
                dark: rgb(0.06, 0.10, 0.17)
            ),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let shadow = dynamicColor(
        light: rgba(0.0, 0.0, 0.0, 0.05),
        dark: rgba(0.0, 0.0, 0.0, 0.28)
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

    #if canImport(UIKit)
    private static func dynamicColor(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    private static func rgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: 1)
    }

    private static func rgba(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat) -> UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    #endif
}

extension View {
    func vintageCard() -> some View {
        self
            .padding(14)
            .background(DesignTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(DesignTokens.border, lineWidth: 0.8)
            )
            .shadow(color: DesignTokens.shadow, radius: 18, y: 6)
    }

    func paperBackground() -> some View {
        self.background(WeatherBackdrop())
    }
}

private struct WeatherBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            DesignTokens.paperGradient

            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            DesignTokens.sun.opacity(colorScheme == .dark ? 0.46 : 0.30),
                            DesignTokens.sun.opacity(colorScheme == .dark ? 0.18 : 0.10),
                            .clear,
                        ],
                        center: .center,
                        startRadius: 16,
                        endRadius: 220
                    )
                )
                .frame(width: 390, height: 280)
                .offset(x: 176, y: -250)
                .blur(radius: 22)

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            DesignTokens.drizzle.opacity(colorScheme == .dark ? 0.34 : 0.20),
                            DesignTokens.rain.opacity(colorScheme == .dark ? 0.28 : 0.17),
                            .clear,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 470, height: 340)
                .rotationEffect(.degrees(-18))
                .offset(x: -178, y: 186)
                .blur(radius: 28)

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            DesignTokens.background.opacity(colorScheme == .dark ? 0.60 : 0.72),
                            DesignTokens.background.opacity(colorScheme == .dark ? 0.18 : 0.08),
                            .clear,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 540, height: 180)
                .rotationEffect(.degrees(8))
                .offset(x: -112, y: -88)
                .blur(radius: 18)

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            DesignTokens.surface.opacity(colorScheme == .dark ? 0.22 : 0.26),
                            .clear,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 560, height: 240)
                .offset(x: 58, y: 322)
                .blur(radius: 30)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.06 : 0.20),
                            .clear,
                            DesignTokens.darkAccent.opacity(colorScheme == .dark ? 0.16 : 0.06),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            VStack(spacing: 0) {
                Spacer()

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignTokens.background.opacity(colorScheme == .dark ? 0.08 : 0.00),
                                DesignTokens.background.opacity(colorScheme == .dark ? 0.20 : 0.12),
                                DesignTokens.surface.opacity(colorScheme == .dark ? 0.34 : 0.28),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 240)
                    .blur(radius: 10)
                    .offset(y: 96)
            }
        }
    }
}
