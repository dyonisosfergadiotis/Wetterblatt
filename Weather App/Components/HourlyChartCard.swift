import SwiftUI

struct HourlyChartCard: View {
    struct Entry: Identifiable, Hashable {
        let id: Date
        let displayLabel: String
        let value: Double
        let formattedValue: String
        let secondaryFormattedValue: String?
        let isCurrent: Bool
        let isPast: Bool
        let isRangeHighlighted: Bool
        let isPeak: Bool
        var dayDividerLabel: String?

        init(
            id: Date,
            displayLabel: String,
            value: Double,
            formattedValue: String,
            secondaryFormattedValue: String? = nil,
            isCurrent: Bool,
            isPast: Bool,
            isRangeHighlighted: Bool = false,
            isPeak: Bool = false,
            dayDividerLabel: String? = nil
        ) {
            self.id = id
            self.displayLabel = displayLabel
            self.value = value
            self.formattedValue = formattedValue
            self.secondaryFormattedValue = secondaryFormattedValue
            self.isCurrent = isCurrent
            self.isPast = isPast
            self.isRangeHighlighted = isRangeHighlighted
            self.isPeak = isPeak
            self.dayDividerLabel = dayDividerLabel
        }
    }

    enum MetricKind {
        case temperature
        case precipitationAmount
        case uvIndex
        case wind

        var title: String {
            switch self {
            case .temperature: return "Temperatur"
            case .precipitationAmount: return "Niederschlag"
            case .uvIndex: return "UV"
            case .wind: return "Wind"
            }
        }

        var tint: Color {
            switch self {
            case .temperature: return DesignTokens.sun
            case .precipitationAmount: return DesignTokens.rain
            case .uvIndex: return DesignTokens.sun
            case .wind: return DesignTokens.ink
            }
        }

        var axisLabel: String {
            switch self {
            case .temperature: return "°C"
            case .precipitationAmount: return "mm"
            case .uvIndex: return "UV"
            case .wind: return "km/h"
            }
        }

        var lowerBoundOverride: Double? {
            switch self {
            case .temperature:
                return nil
            case .precipitationAmount, .uvIndex, .wind:
                return 0
            }
        }

        func axisValueLabel(for value: Double) -> String {
            switch self {
            case .temperature:
                return "\(Int(value.rounded()))°"
            case .precipitationAmount:
                if value >= 10 || abs(value.rounded() - value) < 0.05 {
                    return "\(Int(value.rounded()))"
                }

                return String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",")
            case .uvIndex:
                return "\(Int(value.rounded()))"
            case .wind:
                return "\(Int(value.rounded()))"
            }
        }
    }

    enum LayoutStyle {
        case regular
        case compact
    }

    let entries: [Entry]
    let metric: MetricKind
    var titleOverride: String?
    var descriptionText: String?
    var accentCurrentEntry = false
    var layoutStyle: LayoutStyle = .regular

    @State private var activeIndex = 0
    @State private var isInteracting = false

    var body: some View {
        VStack(alignment: .leading, spacing: layoutStyle == .compact ? 10 : 14) {
            VStack(alignment: .leading, spacing: descriptionText == nil ? 0 : 4) {
                Text((titleOverride ?? metric.title).uppercased())
                    .font(DesignTokens.mono(size: 10, weight: .medium))
                    .foregroundStyle(DesignTokens.secondaryText)

                if let descriptionText {
                    Text(descriptionText)
                        .font(DesignTokens.mono(size: layoutStyle == .compact ? 9 : 10))
                        .foregroundStyle(DesignTokens.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            GeometryReader { proxy in
                let width = proxy.size.width
                let chartSpacing: CGFloat = layoutStyle == .compact ? 8 : 10
                let plotWidth = max(width - yAxisWidth - chartSpacing, 0)

                HStack(alignment: .bottom, spacing: chartSpacing) {
                    yAxis(height: proxy.size.height)
                    plotArea(width: plotWidth, height: proxy.size.height)
                }
                .frame(width: width, height: proxy.size.height, alignment: .bottomLeading)
            }
            .frame(height: chartHeight)
        }
        .onAppear {
            activeIndex = initialIndex
        }
        .onChange(of: entries.map(\.id)) { _, _ in
            activeIndex = initialIndex
        }
    }

    private var activeEntry: Entry? {
        guard entries.indices.contains(activeIndex) else { return nil }
        return entries[activeIndex]
    }

    private var initialIndex: Int {
        entries.firstIndex(where: \.isCurrent) ?? 0
    }

    private var plotMetrics: PlotMetrics {
        PlotMetrics(entries: entries, metric: metric)
    }

    private var barPlotHeight: CGFloat {
        max(chartHeight - plotTopInset - plotBottomInset - xLabelSpacing - xLabelHeight, 1)
    }

    private func plotArea(width: CGFloat, height: CGFloat) -> some View {
        let segmentCount = max(entries.count, 1)
        let contentWidth = max(width - plotHorizontalPadding * 2, 1)
        let segmentWidth = contentWidth / CGFloat(segmentCount)

        return ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: plotCornerRadius, style: .continuous)
                .fill(DesignTokens.chromeWash.opacity(0.35))

            gridOverlay(contentWidth: contentWidth, segmentWidth: segmentWidth)

            HStack(alignment: .bottom, spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    VStack(spacing: xLabelSpacing) {
                        ZStack(alignment: .bottom) {
                            if entry.isRangeHighlighted {
                                RoundedRectangle(cornerRadius: layoutStyle == .compact ? 10 : 12, style: .continuous)
                                    .fill(metric.tint.opacity(layoutStyle == .compact ? 0.12 : 0.08))
                                    .frame(width: max(segmentWidth - 4, barWidth(for: segmentWidth) + 6), height: barPlotHeight)
                            }

                            Capsule()
                                .fill(barColor(for: index, entry: entry))
                                .frame(width: barWidth(for: segmentWidth))
                                .frame(height: barHeight(for: entry.value))
                                .overlay(alignment: .top) {
                                    if entry.isPeak {
                                        peakMarker
                                            .offset(y: -10)
                                    }
                                }
                        }
                        .frame(height: barPlotHeight, alignment: .bottom)

                        xAxisLabel(for: entry)
                    }
                    .frame(width: segmentWidth)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .overlay(alignment: .leading) {
                        if let dayDividerLabel = entry.dayDividerLabel {
                            dayDivider(label: dayDividerLabel)
                        }
                    }
                }
            }
            .padding(.top, plotTopInset)
            .padding(.bottom, plotBottomInset)
            .padding(.horizontal, plotHorizontalPadding)

            if isInteracting, let activeEntry {
                activeValueBubble(for: activeEntry)
                    .position(
                        x: plotHorizontalPadding + segmentWidth * (CGFloat(activeIndex) + 0.5),
                        y: activeBubbleY(for: activeEntry.value)
                    )
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: plotCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: plotCornerRadius, style: .continuous)
                .stroke(DesignTokens.border.opacity(0.7), lineWidth: 0.8)
        )
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard !entries.isEmpty else { return }
                    isInteracting = true
                    let plotX = value.location.x - plotHorizontalPadding
                    let clampedX = min(max(plotX, 0), max(contentWidth - 1, 0))
                    let nextIndex = min(Int(clampedX / max(segmentWidth, 1)), entries.count - 1)
                    guard nextIndex != activeIndex else { return }
                    activeIndex = nextIndex
                    HapticManager.selectionChanged()
                }
                .onEnded { _ in
                    isInteracting = false
                }
        )
    }

    private func yAxis(height: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            Rectangle()
                .fill(DesignTokens.border.opacity(0.9))
                .frame(width: 1, height: barPlotHeight)
                .offset(x: -1, y: plotTopInset)

            Text(metric.axisLabel)
                .font(DesignTokens.mono(size: layoutStyle == .compact ? 8 : 9, weight: .medium))
                .foregroundStyle(DesignTokens.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(Array(plotMetrics.ticks.enumerated()), id: \.offset) { _, tick in
                Text(metric.axisValueLabel(for: tick))
                    .font(DesignTokens.mono(size: layoutStyle == .compact ? 7 : 8, weight: .medium))
                    .foregroundStyle(DesignTokens.secondaryText)
                    .frame(width: yAxisWidth - axisLabelTrailingInset, alignment: .trailing)
                    .offset(y: yPosition(for: tick) - 7)
            }
        }
        .frame(width: yAxisWidth, height: height, alignment: .topTrailing)
    }

    private func gridOverlay(contentWidth: CGFloat, segmentWidth: CGFloat) -> some View {
        let segmentCount = max(entries.count, 1)

        return ZStack(alignment: .topLeading) {
            Rectangle()
                .stroke(DesignTokens.border.opacity(0.32), lineWidth: 0.8)
                .frame(width: contentWidth, height: barPlotHeight)
                .offset(x: plotHorizontalPadding, y: plotTopInset)

            ForEach(Array(plotMetrics.ticks.dropFirst().dropLast().enumerated()), id: \.offset) { _, tick in
                Rectangle()
                    .fill(DesignTokens.border.opacity(0.24))
                    .frame(height: 1)
                    .offset(y: yPosition(for: tick))
            }

            ForEach(1..<segmentCount, id: \.self) { index in
                Rectangle()
                    .fill(DesignTokens.border.opacity(0.18))
                    .frame(width: 1, height: barPlotHeight)
                    .offset(
                        x: plotHorizontalPadding + CGFloat(index) * segmentWidth,
                        y: plotTopInset
                    )
            }
        }
    }

    private func barColor(for index: Int, entry: Entry) -> LinearGradient {
        let base = metric.tint
        let tint: Color
        if entry.isPeak {
            tint = DesignTokens.sun
        } else if accentCurrentEntry && entry.isCurrent {
            tint = DesignTokens.sun
        } else {
            tint = base
        }

        let opacity: Double
        if index == activeIndex || entry.isPeak {
            opacity = 1.0
        } else if entry.isRangeHighlighted {
            opacity = entry.isPast ? 0.54 : 0.8
        } else {
            opacity = entry.isPast ? 0.35 : 0.62
        }

        return LinearGradient(
            colors: [
                tint.opacity(opacity),
                tint.opacity(opacity * 0.55),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func barHeight(for value: Double) -> CGFloat {
        let normalizedHeight = CGFloat(plotMetrics.normalized(value)) * barPlotHeight
        guard value > plotMetrics.range.lowerBound else { return normalizedHeight }
        return max(normalizedHeight, minimumVisibleBarHeight)
    }

    private func yPosition(for value: Double) -> CGFloat {
        plotTopInset + (1 - CGFloat(plotMetrics.normalized(value))) * barPlotHeight
    }

    private func dayDivider(label: String) -> some View {
        VStack(spacing: 6) {
            Text(label.uppercased())
                .font(DesignTokens.mono(size: layoutStyle == .compact ? 7 : 8, weight: .medium))
                .foregroundStyle(DesignTokens.secondaryText)

            Rectangle()
                .fill(DesignTokens.border.opacity(0.8))
                .frame(width: 1, height: dayDividerHeight)
        }
        .padding(.top, plotTopInset + 2)
        .offset(x: -5)
    }

    private func activeValueBubble(for entry: Entry) -> some View {
        VStack(alignment: .leading, spacing: entry.secondaryFormattedValue == nil ? 0 : 2) {
            Text(entry.formattedValue)
                .font(DesignTokens.mono(size: layoutStyle == .compact ? 8 : 9, weight: .semibold))

            if let secondaryFormattedValue = entry.secondaryFormattedValue {
                Text(secondaryFormattedValue)
                    .font(DesignTokens.mono(size: layoutStyle == .compact ? 7 : 8))
                    .foregroundStyle(DesignTokens.background.opacity(0.82))
            }
        }
        .foregroundStyle(DesignTokens.background)
        .padding(.horizontal, layoutStyle == .compact ? 7 : 8)
        .padding(.vertical, layoutStyle == .compact ? 4 : 5)
        .background(DesignTokens.ink)
        .clipShape(Capsule())
    }

    private func activeBubbleY(for value: Double) -> CGFloat {
        max(yPosition(for: value) - activeBubbleOffset, activeBubbleTopPadding)
    }

    private func barWidth(for segmentWidth: CGFloat) -> CGFloat {
        min(max(segmentWidth - (layoutStyle == .compact ? 4 : 5), minimumBarWidth), maximumBarWidth)
    }

    private func xAxisLabel(for entry: Entry) -> some View {
        let font = DesignTokens.mono(
            size: entry.isCurrent ? currentLabelFontSize : defaultLabelFontSize,
            weight: entry.isCurrent ? .semibold : .regular
        )
        let horizontalPadding: CGFloat = entry.isCurrent ? (layoutStyle == .compact ? 4 : 6) : 0
        let verticalPadding: CGFloat = entry.isCurrent ? 3 : 0
        let foregroundColor = entry.isCurrent ? DesignTokens.background : DesignTokens.secondaryText

        return Text(entry.displayLabel)
            .font(font)
            .foregroundStyle(foregroundColor)
            .lineLimit(1)
            .minimumScaleFactor(entry.isCurrent ? 0.68 : 1)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background {
                if entry.isCurrent {
                    Capsule()
                        .fill(DesignTokens.ink)
                }
            }
            .frame(height: xLabelHeight)
    }

    private var peakMarker: some View {
        Circle()
            .fill(DesignTokens.background)
            .frame(width: layoutStyle == .compact ? 6 : 7, height: layoutStyle == .compact ? 6 : 7)
            .overlay {
                Circle()
                    .stroke(DesignTokens.sun, lineWidth: 2)
            }
    }

    private var chartHeight: CGFloat {
        layoutStyle == .compact ? 132 : 156
    }

    private var yAxisWidth: CGFloat {
        layoutStyle == .compact ? 34 : 42
    }

    private var plotTopInset: CGFloat {
        layoutStyle == .compact ? 22 : 28
    }

    private var plotBottomInset: CGFloat {
        layoutStyle == .compact ? 6 : 8
    }

    private var xLabelSpacing: CGFloat {
        layoutStyle == .compact ? 4 : 6
    }

    private var xLabelHeight: CGFloat {
        layoutStyle == .compact ? 12 : 18
    }

    private var minimumVisibleBarHeight: CGFloat {
        layoutStyle == .compact ? 4 : 6
    }

    private var plotHorizontalPadding: CGFloat {
        layoutStyle == .compact ? 8 : 10
    }

    private var plotCornerRadius: CGFloat {
        layoutStyle == .compact ? 12 : 14
    }

    private var axisLabelTrailingInset: CGFloat {
        layoutStyle == .compact ? 8 : 10
    }

    private var defaultLabelFontSize: CGFloat {
        layoutStyle == .compact ? 8 : 9
    }

    private var currentLabelFontSize: CGFloat {
        layoutStyle == .compact ? 7 : 8
    }

    private var activeBubbleOffset: CGFloat {
        layoutStyle == .compact ? 12 : 16
    }

    private var activeBubbleTopPadding: CGFloat {
        layoutStyle == .compact ? 10 : 14
    }

    private var dayDividerHeight: CGFloat {
        barPlotHeight * (layoutStyle == .compact ? 0.4 : 0.56)
    }

    private var minimumBarWidth: CGFloat {
        layoutStyle == .compact ? 5 : 7
    }

    private var maximumBarWidth: CGFloat {
        layoutStyle == .compact ? 12 : 14
    }
}

private struct PlotMetrics {
    let range: ClosedRange<Double>
    let ticks: [Double]

    init(entries: [HourlyChartCard.Entry], metric: HourlyChartCard.MetricKind) {
        let values = entries.map(\.value)
        let rawMin = values.min() ?? 0
        let rawMax = values.max() ?? 1

        let paddedMin = metric.lowerBoundOverride ?? (rawMin - max((rawMax - rawMin) * 0.16, 1))
        let paddedMax = rawMax + max((rawMax - rawMin) * 0.16, 1)
        let niceRange = Self.niceRange(min: paddedMin, max: max(paddedMax, paddedMin + 1))

        range = niceRange.range
        ticks = stride(from: niceRange.range.lowerBound, through: niceRange.range.upperBound, by: niceRange.step)
            .map { value in
                let rounded = (value * 100).rounded() / 100
                return rounded == -0 ? 0 : rounded
            }
    }

    func normalized(_ value: Double) -> Double {
        let span = max(range.upperBound - range.lowerBound, 1)
        let normalized = (value - range.lowerBound) / span
        return min(max(normalized, 0), 1)
    }

    private static func niceRange(min: Double, max: Double) -> (range: ClosedRange<Double>, step: Double) {
        let span = Swift.max(max - min, 1)
        let step = niceStep(for: span / 4)
        let lower = floor(min / step) * step
        let upper = ceil(max / step) * step
        return (lower...upper, step)
    }

    private static func niceStep(for roughStep: Double) -> Double {
        let exponent = floor(log10(max(roughStep, 0.0001)))
        let magnitude = pow(10.0, exponent)
        let residual = roughStep / magnitude

        let multiplier: Double
        switch residual {
        case ..<1.5:
            multiplier = 1
        case ..<3:
            multiplier = 2
        case ..<7:
            multiplier = 5
        default:
            multiplier = 10
        }

        return multiplier * magnitude
    }
}
