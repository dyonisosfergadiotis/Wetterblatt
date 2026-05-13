import SwiftUI
import UIKit

struct TemperatureRangeTrack: View {
    let min: Double
    let max: Double
    let range: ClosedRange<Double>
    var trackHeight: CGFloat = 12
    var labelSpacing: CGFloat = 6
    var labelWidth: CGFloat = 30
    var labelFontSize: CGFloat = 10
    var minimumVisibleFraction: CGFloat = 0.08
    var minLabelColor: Color = DesignTokens.secondaryText
    var maxLabelColor: Color = DesignTokens.ink
    var centersTrackInAvailableHeight: Bool = false
    var valueFormatter: (Double) -> String = { "\(Int($0.rounded()))°" }

    @ViewBuilder
    var body: some View {
        if centersTrackInAvailableHeight {
            ZStack(alignment: .center) {
                trackView

                labelsView
                    .offset(y: trackHeight / 2 + labelSpacing + labelFontSize / 2)
            }
        } else {
            VStack(spacing: labelSpacing) {
                trackView
                labelsView
            }
        }
    }

    private var trackView: some View {
        GeometryReader { proxy in
            let metrics = TemperatureRangeTrackMetrics(
                min: min,
                max: max,
                range: range,
                totalWidth: proxy.size.width,
                minimumVisibleFraction: minimumVisibleFraction
            )

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(DesignTokens.trackFill)
                    .frame(height: trackHeight)

                TemperatureGradientPalette.gradient(for: range)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .mask(alignment: .leading) {
                        Capsule()
                            .frame(width: metrics.visibleWidth, height: trackHeight)
                            .offset(x: metrics.visibleStartX)
                    }
            }
        }
        .frame(height: trackHeight)
    }

    private var labelsView: some View {
        GeometryReader { proxy in
            let metrics = TemperatureRangeTrackMetrics(
                min: min,
                max: max,
                range: range,
                totalWidth: proxy.size.width,
                minimumVisibleFraction: minimumVisibleFraction
            )

            ZStack(alignment: .topLeading) {
                Text(valueFormatter(min))
                    .font(DesignTokens.mono(size: labelFontSize))
                    .foregroundStyle(minLabelColor)
                    .frame(width: labelWidth)
                    .offset(
                        x: clampedLabelPosition(
                            metrics.startX - labelWidth / 2,
                            totalWidth: proxy.size.width
                        )
                    )

                Text(valueFormatter(max))
                    .font(DesignTokens.mono(size: labelFontSize, weight: .medium))
                    .foregroundStyle(maxLabelColor)
                    .frame(width: labelWidth)
                    .offset(
                        x: clampedLabelPosition(
                            metrics.endX - labelWidth / 2,
                            totalWidth: proxy.size.width
                        )
                    )
            }
        }
        .frame(height: centersTrackInAvailableHeight ? labelFontSize + 2 : labelFontSize + 6)
    }

    private func clampedLabelPosition(_ proposed: CGFloat, totalWidth: CGFloat) -> CGFloat {
        Swift.min(
            Swift.max(proposed, 0),
            Swift.max(totalWidth - labelWidth, 0)
        )
    }
}

private struct TemperatureRangeTrackMetrics {
    let startX: CGFloat
    let endX: CGFloat
    let visibleStartX: CGFloat
    let visibleWidth: CGFloat

    init(
        min: Double,
        max: Double,
        range: ClosedRange<Double>,
        totalWidth: CGFloat,
        minimumVisibleFraction: CGFloat
    ) {
        let totalRange = Swift.max(range.upperBound - range.lowerBound, 1)
        let lowerValue = Swift.min(min, max)
        let upperValue = Swift.max(min, max)
        let startRatio = CGFloat((lowerValue - range.lowerBound) / totalRange)
        let endRatio = CGFloat((upperValue - range.lowerBound) / totalRange)
        let rawWidthRatio = CGFloat((upperValue - lowerValue) / totalRange)
        let safeWidthRatio = Swift.min(Swift.max(rawWidthRatio, minimumVisibleFraction), 1)
        let safeStartRatio = Swift.min(Swift.max(startRatio, 0), Swift.max(1 - safeWidthRatio, 0))

        startX = totalWidth * Swift.min(Swift.max(startRatio, 0), 1)
        endX = totalWidth * Swift.min(Swift.max(endRatio, 0), 1)
        visibleStartX = totalWidth * safeStartRatio
        visibleWidth = totalWidth * safeWidthRatio
    }
}

enum TemperatureGradientPalette {
    enum Axis {
        case horizontal
        case vertical
    }

    private struct Stop {
        let temperature: Double
        let color: UIColor
    }

    private static let cold = UIColor(DesignTokens.frost)
    private static let rain = UIColor(DesignTokens.rain)
    private static let sun = UIColor(DesignTokens.sun)
    private static let hazySun = UIColor(DesignTokens.hazySun)

    private static let stops: [Stop] = [
        .init(temperature: -10, color: cold),
        .init(temperature: 0, color: cold),
        .init(temperature: 10, color: rain),
        .init(temperature: 15, color: blend(rain, sun, amount: 0.45)),
        .init(temperature: 20, color: sun),
        .init(temperature: 28, color: blend(hazySun, .white, amount: 0.28)),
        .init(temperature: 35, color: blend(hazySun, .white, amount: 0.55)),
    ]

    static func gradient(for range: ClosedRange<Double>, axis: Axis = .horizontal) -> LinearGradient {
        let gradientPoints: (UnitPoint, UnitPoint) = switch axis {
        case .horizontal:
            (.leading, .trailing)
        case .vertical:
            (.bottom, .top)
        }

        return LinearGradient(
            stops: gradientStops(for: range),
            startPoint: gradientPoints.0,
            endPoint: gradientPoints.1
        )
    }

    private static func gradientStops(for range: ClosedRange<Double>) -> [Gradient.Stop] {
        let lower = range.lowerBound
        let upper = Swift.max(range.upperBound, lower + 1)
        let total = upper - lower

        let relevantTemperatures = [lower]
            + stops.map(\.temperature).filter { $0 > lower && $0 < upper }
            + [upper]

        return relevantTemperatures.map { temperature in
            Gradient.Stop(
                color: Color(uiColor: color(at: temperature)),
                location: (temperature - lower) / total
            )
        }
    }

    private static func color(at temperature: Double) -> UIColor {
        guard let first = stops.first, let last = stops.last else {
            return .white
        }

        if temperature <= first.temperature {
            return first.color
        }

        if temperature >= last.temperature {
            return last.color
        }

        for (lowerStop, upperStop) in zip(stops, stops.dropFirst()) {
            guard temperature <= upperStop.temperature else { continue }
            let span = Swift.max(upperStop.temperature - lowerStop.temperature, 0.001)
            let progress = CGFloat((temperature - lowerStop.temperature) / span)
            return blend(lowerStop.color, upperStop.color, amount: progress)
        }

        return last.color
    }

    private static func blend(_ from: UIColor, _ to: UIColor, amount: CGFloat) -> UIColor {
        let start = rgbaComponents(for: from)
        let end = rgbaComponents(for: to)
        let progress = Swift.min(Swift.max(amount, 0), 1)

        return UIColor(
            red: start.red + (end.red - start.red) * progress,
            green: start.green + (end.green - start.green) * progress,
            blue: start.blue + (end.blue - start.blue) * progress,
            alpha: start.alpha + (end.alpha - start.alpha) * progress
        )
    }

    private static func rgbaComponents(for color: UIColor) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        let resolved = color.resolvedColor(with: UITraitCollection.current)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        if resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return (red, green, blue, alpha)
        }

        var white: CGFloat = 0
        if resolved.getWhite(&white, alpha: &alpha) {
            return (white, white, white, alpha)
        }

        return (0, 0, 0, 1)
    }
}
