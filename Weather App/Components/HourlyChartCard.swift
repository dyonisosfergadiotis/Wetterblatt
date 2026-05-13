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
        case airQualityIndex
        case particulateMatter
        case pollen

        var title: String {
            switch self {
            case .temperature: return "Temperatur"
            case .precipitationAmount: return "Niederschlag"
            case .uvIndex: return "UV"
            case .wind: return "Wind"
            case .airQualityIndex: return "AQI"
            case .particulateMatter: return "Feinstaub"
            case .pollen: return "Pollen"
            }
        }

        var tint: Color {
            gradientHighTint
        }

        var gradientLowTint: Color {
            switch self {
            case .temperature: return DesignTokens.moon
            case .precipitationAmount: return DesignTokens.drizzle
            case .uvIndex: return DesignTokens.hazySun
            case .wind: return DesignTokens.windLow
            case .airQualityIndex: return DesignTokens.airQualityGood
            case .particulateMatter: return DesignTokens.airQualityModerate
            case .pollen: return DesignTokens.airQualityGood
            }
        }

        var gradientHighTint: Color {
            switch self {
            case .temperature: return DesignTokens.sun
            case .precipitationAmount: return DesignTokens.rain
            case .uvIndex: return DesignTokens.uv
            case .wind: return DesignTokens.wind
            case .airQualityIndex: return DesignTokens.airQualityPoor
            case .particulateMatter: return DesignTokens.airQualityVeryPoor
            case .pollen: return DesignTokens.airQualityPoor
            }
        }

        var axisLabel: String {
            switch self {
            case .temperature: return "°C"
            case .precipitationAmount: return "mm"
            case .uvIndex: return "UV"
            case .wind: return "km/h"
            case .airQualityIndex: return "AQI"
            case .particulateMatter: return "μg/m³"
            case .pollen: return "Wert"
            }
        }

        var usesTemperaturePalette: Bool {
            switch self {
            case .temperature:
                return true
            case .precipitationAmount, .uvIndex, .wind, .airQualityIndex, .particulateMatter, .pollen:
                return false
            }
        }

        var lowerBoundOverride: Double? {
            switch self {
            case .temperature:
                return nil
            case .precipitationAmount, .uvIndex, .wind, .airQualityIndex, .particulateMatter, .pollen:
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
            case .uvIndex, .wind, .airQualityIndex, .pollen:
                return "\(Int(value.rounded()))"
            case .particulateMatter:
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
    var valueDomain: ClosedRange<Double>?
    var showsHeader = true
    var axisLabelOverride: String?
    var axisValueFormatter: ((Double) -> String)?
    var headerAccessory: AnyView? = nil

    @State private var activeIndex = 0
    @State private var isInteracting = false

    var body: some View {
        VStack(alignment: .leading, spacing: showsHeader ? (layoutStyle == .compact ? 10 : 14) : 0) {
            if showsHeader {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: headerDescriptionText == nil ? 0 : 4) {
                        Text((titleOverride ?? metric.title).uppercased())
                            .font(DesignTokens.mono(size: 10, weight: .medium))
                            .foregroundStyle(metric.tint)

                        if let headerDescriptionText {
                            Text(headerDescriptionText)
                                .font(DesignTokens.mono(size: layoutStyle == .compact ? 9 : 10))
                                .foregroundStyle(DesignTokens.tertiaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if let headerAccessory {
                        headerAccessory
                    }
                }
            }

            GeometryReader { proxy in
                let width = proxy.size.width
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
        PlotMetrics(entries: entries, metric: metric, valueDomain: valueDomain)
    }

    private var headerDescriptionText: String? {
        guard let descriptionText else { return nil }
        let normalizedDescription = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedAxisLabel = axisLabel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalizedDescription == normalizedAxisLabel ? nil : descriptionText
    }

    private var axisLabel: String {
        axisLabelOverride ?? metric.axisLabel
    }

    private func axisValueLabel(for value: Double) -> String {
        axisValueFormatter?(value) ?? metric.axisValueLabel(for: value)
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
                .fill(
                    LinearGradient(
                        colors: [
                            DesignTokens.chromeFill.opacity(0.30),
                            DesignTokens.chromeWash.opacity(0.40),
                            DesignTokens.surface.opacity(0.18),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(metric.tint.opacity(layoutStyle == .compact ? 0.10 : 0.13))
                .frame(width: layoutStyle == .compact ? 86 : 110, height: layoutStyle == .compact ? 86 : 110)
                .blur(radius: layoutStyle == .compact ? 16 : 20)
                .offset(x: width - (layoutStyle == .compact ? 36 : 46), y: layoutStyle == .compact ? 8 : 10)

            gridOverlay(contentWidth: contentWidth, segmentWidth: segmentWidth)

            HStack(alignment: .bottom, spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    VStack(spacing: xLabelSpacing) {
                        ZStack(alignment: .bottom) {
                            if entry.isRangeHighlighted {
                                RoundedRectangle(cornerRadius: layoutStyle == .compact ? 8 : 10, style: .continuous)
                                    .fill(rangeHighlightColor(for: entry))
                                    .frame(
                                        width: highlightWidth(for: segmentWidth),
                                        height: highlightHeight(for: entry)
                                    )
                            }

                            barView(for: index, entry: entry, segmentWidth: segmentWidth)
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

            Text(axisLabel)
                .font(DesignTokens.mono(size: layoutStyle == .compact ? 8 : 9, weight: .medium))
                .foregroundStyle(metric.tint)
                .frame(width: yAxisWidth - axisLabelTrailingInset, alignment: .trailing)

            ForEach(Array(plotMetrics.ticks.enumerated()), id: \.offset) { _, tick in
                Text(axisValueLabel(for: tick))
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

    @ViewBuilder
    private func barView(for index: Int, entry: Entry, segmentWidth: CGFloat) -> some View {
        let width = barWidth(for: segmentWidth)
        let height = barHeight(for: entry.value)

        if metric.usesTemperaturePalette && !isHistorical(entry) {
            TemperatureGradientPalette.gradient(for: plotMetrics.range, axis: .vertical)
                .frame(width: width, height: barPlotHeight)
                .mask(alignment: .bottom) {
                    Capsule()
                        .frame(width: width, height: height)
                }
                .opacity(temperatureBarOpacity(for: index, entry: entry))
        } else {
            Capsule()
                .fill(barColor(for: index, entry: entry))
                .frame(width: width)
                .frame(height: height)
        }
    }

    private func barColor(for index: Int, entry: Entry) -> LinearGradient {
        let normalizedValue = plotMetrics.normalized(entry.value)
        let interactionBoost = index == activeIndex ? 0.14 : 0
        let currentBoost = accentCurrentEntry && entry.isCurrent ? 0.10 : 0
        let historical = isHistorical(entry)

        let topOpacity: Double
        if historical {
            topOpacity = min(
                (entry.isRangeHighlighted ? 0.44 : 0.34) + normalizedValue * 0.18 + interactionBoost * 0.7,
                0.74
            )
        } else if entry.isRangeHighlighted {
            topOpacity = min(0.7 + normalizedValue * 0.24 + interactionBoost + currentBoost, 1.0)
        } else {
            topOpacity = min(0.54 + normalizedValue * 0.28 + interactionBoost + currentBoost, 1.0)
        }

        let bottomOpacity = historical ? 0.18 : 0.28
        let highTint = historical ? DesignTokens.secondaryText : metric.gradientHighTint
        let lowTint = historical ? DesignTokens.border : metric.gradientLowTint

        return LinearGradient(
            colors: [
                highTint.opacity(topOpacity),
                lowTint.opacity(bottomOpacity),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func temperatureBarOpacity(for index: Int, entry: Entry) -> Double {
        let normalizedValue = plotMetrics.normalized(entry.value)
        let interactionBoost = index == activeIndex ? 0.14 : 0
        let currentBoost = accentCurrentEntry && entry.isCurrent ? 0.10 : 0
        let historical = isHistorical(entry)

        if entry.isRangeHighlighted {
            return min(0.76 + normalizedValue * 0.18 + interactionBoost + currentBoost, 1.0)
        }

        return min((historical ? 0.54 : 0.74) + normalizedValue * 0.20 + interactionBoost + currentBoost, 1.0)
    }

    private func rangeHighlightColor(for entry: Entry) -> Color {
        let opacity = layoutStyle == .compact ? 0.16 : 0.11
        let tint = isHistorical(entry) ? DesignTokens.secondaryText : metric.tint
        return tint.opacity(opacity)
    }

    private func isHistorical(_ entry: Entry) -> Bool {
        entry.isPast && !entry.isCurrent
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

    private func highlightWidth(for segmentWidth: CGFloat) -> CGFloat {
        let extraWidth: CGFloat = layoutStyle == .compact ? 6 : 8
        let maximumWidth = max(segmentWidth - 4, barWidth(for: segmentWidth))
        return min(barWidth(for: segmentWidth) + extraWidth, maximumWidth)
    }

    private func highlightHeight(for entry: Entry) -> CGFloat {
        let extraHeight: CGFloat = layoutStyle == .compact ? 10 : 14
        let minimumHeight = minimumVisibleBarHeight + extraHeight
        let baseHeight = max(barHeight(for: entry.value), minimumHeight)
        return min(baseHeight, barPlotHeight)
    }

    private func xAxisLabel(for entry: Entry) -> some View {
        let font = DesignTokens.mono(
            size: entry.isCurrent ? currentLabelFontSize : defaultLabelFontSize,
            weight: entry.isCurrent ? .semibold : .regular
        )
        let horizontalPadding: CGFloat = entry.isCurrent ? (layoutStyle == .compact ? 4 : 6) : 0
        let verticalPadding: CGFloat = entry.isCurrent ? 3 : 0
        let foregroundColor = entry.isCurrent ? DesignTokens.background : DesignTokens.secondaryText
        let currentLabelFill = metric.usesTemperaturePalette ? DesignTokens.ink : metric.tint

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
                        .fill(currentLabelFill)
                }
            }
            .frame(height: xLabelHeight)
    }
    private var chartHeight: CGFloat {
        layoutStyle == .compact ? 198 : 234
    }

    private var yAxisWidth: CGFloat {
        layoutStyle == .compact ? 28 : 36
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
        layoutStyle == .compact ? 4 : 6
    }

    private var chartSpacing: CGFloat {
        layoutStyle == .compact ? 4 : 6
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

struct PrecipitationLineChartCard: View {
    struct Entry: Identifiable, Hashable {
        let id: Date
        let displayLabel: String
        let precipitationAmount: Double
        let precipitationProbability: Double
        let isCurrent: Bool
        let isPast: Bool
    }

    let entries: [Entry]
    var titleOverride: String?
    var descriptionText: String?
    var layoutStyle: HourlyChartCard.LayoutStyle = .regular
    var amountDomain: ClosedRange<Double>?
    var amountUnitLabel = "mm"
    var amountValueFormatter: ((Double) -> String)?

    @State private var activeIndex = 0
    @State private var isInteracting = false

    var body: some View {
        VStack(alignment: .leading, spacing: layoutStyle == .compact ? 10 : 14) {
            VStack(alignment: .leading, spacing: headerDescriptionText == nil ? 0 : 4) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text((titleOverride ?? "Regenmenge & Chance").uppercased())
                        .font(DesignTokens.mono(size: 10, weight: .medium))
                        .foregroundStyle(amountLineColor)

                    Spacer(minLength: 8)

                    legendItem(label: amountUnitLabel, color: amountLineColor)
                    legendItem(label: "%", color: probabilityLineColor)
                }

                if let headerDescriptionText {
                    Text(headerDescriptionText)
                        .font(DesignTokens.mono(size: layoutStyle == .compact ? 9 : 10))
                        .foregroundStyle(DesignTokens.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            GeometryReader { proxy in
                let width = proxy.size.width
                let plotWidth = max(width - leadingAxisWidth - trailingAxisWidth - axisSpacing * 2, 0)

                HStack(alignment: .bottom, spacing: axisSpacing) {
                    leadingAxis(height: proxy.size.height)
                    plotArea(width: plotWidth, height: proxy.size.height)
                    trailingAxis(height: proxy.size.height)
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

    private var amountMetrics: PlotMetrics {
        PlotMetrics(
            values: entries.map(\.precipitationAmount),
            lowerBoundOverride: 0,
            valueDomain: amountDomain
        )
    }

    private var probabilityMetrics: PlotMetrics {
        PlotMetrics(
            values: entries.map(\.precipitationProbability),
            lowerBoundOverride: 0,
            valueDomain: 0...100,
            addsPadding: false
        )
    }

    private var headerDescriptionText: String? {
        descriptionText?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var linePlotHeight: CGFloat {
        max(chartHeight - plotTopInset - plotBottomInset - xLabelSpacing - xLabelHeight, 1)
    }

    private func leadingAxis(height: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            Rectangle()
                .fill(DesignTokens.border.opacity(0.9))
                .frame(width: 1, height: linePlotHeight)
                .offset(x: -1, y: plotTopInset)

            Text(amountUnitLabel)
                .font(DesignTokens.mono(size: layoutStyle == .compact ? 8 : 9, weight: .medium))
                .foregroundStyle(amountLineColor)
                .frame(width: leadingAxisWidth - axisLabelInset, alignment: .trailing)

            ForEach(Array(amountMetrics.ticks.enumerated()), id: \.offset) { _, tick in
                Text(formattedAxisAmount(tick))
                    .font(DesignTokens.mono(size: layoutStyle == .compact ? 7 : 8, weight: .medium))
                    .foregroundStyle(DesignTokens.secondaryText)
                    .frame(width: leadingAxisWidth - axisLabelInset, alignment: .trailing)
                    .offset(y: yPosition(for: tick, metrics: amountMetrics) - 7)
            }
        }
        .frame(width: leadingAxisWidth, height: height, alignment: .topTrailing)
    }

    private func trailingAxis(height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(DesignTokens.border.opacity(0.9))
                .frame(width: 1, height: linePlotHeight)
                .offset(y: plotTopInset)

            Text("%")
                .font(DesignTokens.mono(size: layoutStyle == .compact ? 8 : 9, weight: .medium))
                .foregroundStyle(probabilityLineColor)
                .frame(width: trailingAxisWidth - axisLabelInset, alignment: .leading)

            ForEach(Array(probabilityMetrics.ticks.enumerated()), id: \.offset) { _, tick in
                Text("\(Int(tick.rounded()))")
                    .font(DesignTokens.mono(size: layoutStyle == .compact ? 7 : 8, weight: .medium))
                    .foregroundStyle(DesignTokens.secondaryText)
                    .frame(width: trailingAxisWidth - axisLabelInset, alignment: .leading)
                    .offset(y: yPosition(for: tick, metrics: probabilityMetrics) - 7)
            }
        }
        .frame(width: trailingAxisWidth, height: height, alignment: .topLeading)
    }

    private func plotArea(width: CGFloat, height: CGFloat) -> some View {
        let segmentCount = max(entries.count, 1)
        let contentWidth = max(width - plotHorizontalPadding * 2, 1)
        let segmentWidth = contentWidth / CGFloat(segmentCount)

        return ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: plotCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            DesignTokens.chromeFill.opacity(0.30),
                            DesignTokens.chromeWash.opacity(0.40),
                            DesignTokens.surface.opacity(0.18),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(amountLineColor.opacity(layoutStyle == .compact ? 0.08 : 0.11))
                .frame(width: layoutStyle == .compact ? 90 : 116, height: layoutStyle == .compact ? 90 : 116)
                .blur(radius: layoutStyle == .compact ? 18 : 22)
                .offset(x: width - (layoutStyle == .compact ? 34 : 44), y: layoutStyle == .compact ? 10 : 12)

            Circle()
                .fill(probabilityLineColor.opacity(layoutStyle == .compact ? 0.10 : 0.12))
                .frame(width: layoutStyle == .compact ? 82 : 104, height: layoutStyle == .compact ? 82 : 104)
                .blur(radius: layoutStyle == .compact ? 18 : 22)
                .offset(x: width - (layoutStyle == .compact ? 68 : 82), y: layoutStyle == .compact ? 24 : 28)

            gridOverlay(contentWidth: contentWidth, segmentWidth: segmentWidth)

            amountLinePath(segmentWidth: segmentWidth)
                .stroke(
                    LinearGradient(
                        colors: [amountLineColor.opacity(0.78), amountLineColor],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(
                        lineWidth: layoutStyle == .compact ? 1.8 : 2.1,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )

            probabilityLinePath(segmentWidth: segmentWidth)
                .stroke(
                    LinearGradient(
                        colors: [probabilityLineColor.opacity(0.80), probabilityLineColor],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(
                        lineWidth: layoutStyle == .compact ? 1.7 : 2.0,
                        lineCap: .round,
                        lineJoin: .round,
                        dash: layoutStyle == .compact ? [4, 3] : [5, 4]
                    )
                )

            xAxisLabels(segmentWidth: segmentWidth)

            if let activeEntry {
                activeMarkers(for: activeEntry, segmentWidth: segmentWidth)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: plotCornerRadius, style: .continuous))
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

    private func gridOverlay(contentWidth: CGFloat, segmentWidth: CGFloat) -> some View {
        let segmentCount = max(entries.count, 1)

        return ZStack(alignment: .topLeading) {
            ForEach(Array(amountMetrics.ticks.dropFirst().dropLast().enumerated()), id: \.offset) { _, tick in
                Rectangle()
                    .fill(DesignTokens.border.opacity(0.24))
                    .frame(height: 1)
                    .offset(y: yPosition(for: tick, metrics: amountMetrics))
            }

            ForEach(1..<segmentCount, id: \.self) { index in
                Rectangle()
                    .fill(DesignTokens.border.opacity(0.18))
                    .frame(width: 1, height: linePlotHeight)
                    .offset(
                        x: plotHorizontalPadding + CGFloat(index) * segmentWidth,
                        y: plotTopInset
                    )
            }
        }
    }

    private func amountLinePath(segmentWidth: CGFloat) -> Path {
        linePath(
            values: entries.map(\.precipitationAmount),
            metrics: amountMetrics,
            segmentWidth: segmentWidth
        )
    }

    private func probabilityLinePath(segmentWidth: CGFloat) -> Path {
        linePath(
            values: entries.map(\.precipitationProbability),
            metrics: probabilityMetrics,
            segmentWidth: segmentWidth
        )
    }

    private func linePath(values: [Double], metrics: PlotMetrics, segmentWidth: CGFloat) -> Path {
        Path { path in
            guard !values.isEmpty else { return }

            for index in values.indices {
                let point = CGPoint(
                    x: xPosition(for: index, segmentWidth: segmentWidth),
                    y: yPosition(for: values[index], metrics: metrics)
                )

                if index == values.startIndex {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
        }
    }

    private func activeMarkers(for entry: Entry, segmentWidth: CGFloat) -> some View {
        let amountY = yPosition(for: entry.precipitationAmount, metrics: amountMetrics)
        let probabilityY = yPosition(for: entry.precipitationProbability, metrics: probabilityMetrics)
        let markerX = xPosition(for: activeIndex, segmentWidth: segmentWidth)

        return ZStack {
            Rectangle()
                .fill(DesignTokens.ink.opacity(0.18))
                .frame(width: 1, height: linePlotHeight)
                .position(x: markerX, y: plotTopInset + linePlotHeight / 2)

            Circle()
                .fill(amountLineColor)
                .frame(width: layoutStyle == .compact ? 8 : 10, height: layoutStyle == .compact ? 8 : 10)
                .overlay(
                    Circle()
                        .stroke(DesignTokens.background, lineWidth: 1.2)
                )
                .position(x: markerX, y: amountY)

            Circle()
                .fill(probabilityLineColor)
                .frame(width: layoutStyle == .compact ? 8 : 10, height: layoutStyle == .compact ? 8 : 10)
                .overlay(
                    Circle()
                        .stroke(DesignTokens.background, lineWidth: 1.2)
                )
                .position(x: markerX, y: probabilityY)

            if isInteracting {
                activeValueBubble(for: entry)
                    .position(
                        x: markerX,
                        y: max(min(amountY, probabilityY) - activeBubbleOffset, activeBubbleTopPadding)
                    )
            }
        }
    }

    private func activeValueBubble(for entry: Entry) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            bubbleRow(color: amountLineColor.opacity(0.72), text: "ca. \(formattedAmount(expectedAmount(for: entry)))")
            bubbleRow(color: amountLineColor, text: formattedAmount(entry.precipitationAmount))
            bubbleRow(color: probabilityLineColor, text: formattedProbability(entry.precipitationProbability))
        }
        .foregroundStyle(DesignTokens.background)
        .padding(.horizontal, layoutStyle == .compact ? 7 : 8)
        .padding(.vertical, layoutStyle == .compact ? 5 : 6)
        .background(DesignTokens.ink)
        .clipShape(Capsule())
    }

    private func bubbleRow(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text(text)
                .font(DesignTokens.mono(size: layoutStyle == .compact ? 8 : 9, weight: .semibold))
        }
    }

    private func xAxisLabels(segmentWidth: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { _, entry in
                VStack(spacing: xLabelSpacing) {
                    Spacer(minLength: 0)
                    xAxisLabel(for: entry)
                }
                .frame(width: segmentWidth)
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .padding(.top, plotTopInset)
        .padding(.bottom, plotBottomInset)
        .padding(.horizontal, plotHorizontalPadding)
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

    private func legendItem(label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text(label)
                .font(DesignTokens.mono(size: 8, weight: .medium))
                .foregroundStyle(DesignTokens.secondaryText)
        }
    }

    private func xPosition(for index: Int, segmentWidth: CGFloat) -> CGFloat {
        plotHorizontalPadding + segmentWidth * (CGFloat(index) + 0.5)
    }

    private func yPosition(for value: Double, metrics: PlotMetrics) -> CGFloat {
        plotTopInset + (1 - CGFloat(metrics.normalized(value))) * linePlotHeight
    }

    private func formattedAmount(_ value: Double) -> String {
        if let amountValueFormatter {
            return amountValueFormatter(value)
        }

        if value >= 10 || abs(value.rounded() - value) < 0.05 {
            return "\(Int(value.rounded())) mm"
        }

        return String(format: "%.1f mm", value).replacingOccurrences(of: ".", with: ",")
    }

    private func formattedAxisAmount(_ value: Double) -> String {
        formattedAmount(value)
            .replacingOccurrences(of: " mm", with: "")
            .replacingOccurrences(of: " in", with: "")
    }

    private func formattedProbability(_ value: Double) -> String {
        "\(Int(value.rounded())) %"
    }

    private func expectedAmount(for entry: Entry) -> Double {
        PrecipitationExpectation.weightedAmount(
            precipitation: entry.precipitationAmount,
            probability: entry.precipitationProbability
        )
    }

    private var amountLineColor: Color {
        DesignTokens.rain
    }

    private var probabilityLineColor: Color {
        DesignTokens.drizzle
    }

    private var chartHeight: CGFloat {
        layoutStyle == .compact ? 144 : 168
    }

    private var leadingAxisWidth: CGFloat {
        layoutStyle == .compact ? 28 : 36
    }

    private var trailingAxisWidth: CGFloat {
        layoutStyle == .compact ? 28 : 36
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

    private var plotHorizontalPadding: CGFloat {
        layoutStyle == .compact ? 8 : 10
    }

    private var plotCornerRadius: CGFloat {
        layoutStyle == .compact ? 12 : 14
    }

    private var axisLabelInset: CGFloat {
        layoutStyle == .compact ? 4 : 6
    }

    private var axisSpacing: CGFloat {
        layoutStyle == .compact ? 4 : 6
    }

    private var defaultLabelFontSize: CGFloat {
        layoutStyle == .compact ? 8 : 9
    }

    private var currentLabelFontSize: CGFloat {
        layoutStyle == .compact ? 7 : 8
    }

    private var activeBubbleOffset: CGFloat {
        layoutStyle == .compact ? 14 : 18
    }

    private var activeBubbleTopPadding: CGFloat {
        layoutStyle == .compact ? 12 : 14
    }
}

extension HourlyChartCard {
    static func valueDomain(for entries: [Entry]) -> ClosedRange<Double>? {
        guard let minValue = entries.map(\.value).min(),
              let maxValue = entries.map(\.value).max() else {
            return nil
        }

        return minValue...maxValue
    }

    static func valueDomain(for entryGroups: [[Entry]]) -> ClosedRange<Double>? {
        valueDomain(for: entryGroups.flatMap { $0 })
    }
}

extension PrecipitationLineChartCard {
    static func amountDomain(for entries: [Entry]) -> ClosedRange<Double>? {
        guard let minValue = entries.map(\.precipitationAmount).min(),
              let maxValue = entries.map(\.precipitationAmount).max() else {
            return nil
        }

        return minValue...maxValue
    }

    static func amountDomain(for entryGroups: [[Entry]]) -> ClosedRange<Double>? {
        amountDomain(for: entryGroups.flatMap { $0 })
    }
}

private struct PlotMetrics {
    let range: ClosedRange<Double>
    let ticks: [Double]

    init(
        entries: [HourlyChartCard.Entry],
        metric: HourlyChartCard.MetricKind,
        valueDomain: ClosedRange<Double>? = nil
    ) {
        self.init(
            values: entries.map(\.value),
            lowerBoundOverride: metric.lowerBoundOverride,
            valueDomain: valueDomain
        )
    }

    init(
        values: [Double],
        lowerBoundOverride: Double? = nil,
        valueDomain: ClosedRange<Double>? = nil,
        addsPadding: Bool = true
    ) {
        let rawMin = valueDomain?.lowerBound ?? values.min() ?? 0
        let rawMax = valueDomain?.upperBound ?? values.max() ?? 1
        let paddedMin = lowerBoundOverride ?? (rawMin - max((rawMax - rawMin) * 0.16, 1))
        let paddedMax = rawMax + max((rawMax - rawMin) * 0.16, 1)
        let minimumUpperBound = (lowerBoundOverride ?? rawMin) + 1
        let rangeSource = addsPadding
            ? Self.niceRange(min: paddedMin, max: max(paddedMax, paddedMin + 1)).range
            : Self.niceRange(min: lowerBoundOverride ?? rawMin, max: max(rawMax, minimumUpperBound)).range

        range = rangeSource
        ticks = stride(from: rangeSource.lowerBound, through: rangeSource.upperBound, by: Self.step(for: rangeSource))
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

    private static func step(for range: ClosedRange<Double>) -> Double {
        let span = Swift.max(range.upperBound - range.lowerBound, 1)
        return niceStep(for: span / 4)
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
