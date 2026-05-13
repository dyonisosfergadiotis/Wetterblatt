import SwiftUI

struct MetricCard: View {
    struct TimelineSample: Identifiable, Hashable {
        let id: Date
        let value: Double
        let isCurrent: Bool
        let isPast: Bool
    }

    let title: String
    let value: String
    let detail: String
    var secondaryDetail: String?
    var valueLineLimit = 1
    var detailLineLimit = 2
    var secondaryLineLimit = 2
    var contentHeight: CGFloat = 122
    var timeline: [TimelineSample] = []
    var timelineAccent: Color = DesignTokens.ink
    var timelineLowAccent: Color?
    var timelineBaseline: Double?
    var timelineCaption: String?
    var accent: Color?
    var showsDisclosureIndicator = false
    var headerAccessory: AnyView?

    var body: some View {
        let hasTimeline = !timeline.isEmpty
        let effectiveCardHeight = max(82, contentHeight)
        let cardVerticalInset: CGFloat = hasTimeline
            ? (effectiveCardHeight < 112 ? 22 : 26)
            : (effectiveCardHeight < 112 ? 20 : 24)
        let resolvedContentHeight = max(72, effectiveCardHeight - cardVerticalInset)
        let isCompact = effectiveCardHeight < 118
        let timelineCompact = hasTimeline && effectiveCardHeight < 146
        let timelineUltraCompact = hasTimeline && effectiveCardHeight < 134
        let stackSpacing: CGFloat = timelineUltraCompact ? 3 : (timelineCompact || isCompact ? 5 : 7)
        let valueFontSize: CGFloat = timelineUltraCompact ? 18 : (timelineCompact || isCompact ? 21 : 24)
        let bodyFontSize: CGFloat = timelineUltraCompact ? 8.7 : (timelineCompact ? 9.1 : (isCompact ? 9.7 : 10.4))
        let bodyLineSpacing: CGFloat = timelineUltraCompact ? -1.6 : (timelineCompact ? -1.4 : -1.1)
        let timelineHeight: CGFloat = timelineUltraCompact ? 24 : (timelineCompact ? 28 : (isCompact ? 30 : 34))

        VStack(alignment: .leading, spacing: stackSpacing) {
            HStack(alignment: .top, spacing: 10) {
                Text(title.uppercased())
                    .font(DesignTokens.mono(size: timelineUltraCompact ? 9 : 10, weight: .medium))
                    .foregroundStyle(accent ?? DesignTokens.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 0)

                if let headerAccessory {
                    headerAccessory
                } else if showsDisclosureIndicator {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(accent?.opacity(0.88) ?? DesignTokens.secondaryText)
                }
            }

            Text(value)
                .font(DesignTokens.serif(size: valueFontSize))
                .foregroundStyle(accent ?? DesignTokens.ink)
                .lineLimit(valueLineLimit)
                .minimumScaleFactor(0.75)

            Text(detail)
                .font(DesignTokens.mono(size: bodyFontSize))
                .foregroundStyle(DesignTokens.tertiaryText)
                .lineSpacing(bodyLineSpacing)
                .lineLimit(detailLineLimit)
                .multilineTextAlignment(.leading)

            if let secondaryDetail {
                Text(secondaryDetail)
                    .font(DesignTokens.mono(size: bodyFontSize))
                    .foregroundStyle(DesignTokens.tertiaryText)
                    .lineSpacing(bodyLineSpacing)
                    .lineLimit(secondaryLineLimit)
                    .multilineTextAlignment(.leading)
            }

            if hasTimeline {
                Spacer(minLength: timelineCompact ? 2 : 4)

                MetricCardTimeline(
                    samples: timeline,
                    accent: timelineAccent,
                    lowAccent: timelineLowAccent,
                    baseline: timelineBaseline
                )
                    .frame(height: timelineHeight)

                if let timelineCaption {
                    Text(timelineCaption)
                        .font(DesignTokens.mono(size: 9))
                        .foregroundStyle(DesignTokens.secondaryText)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: resolvedContentHeight, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
        .vintageCard()
        .overlay(alignment: .topLeading) {
            if let accent {
                Capsule()
                    .fill(accent.opacity(0.78))
                    .frame(width: 42, height: 3)
                    .padding(.top, 10)
                    .padding(.leading, 16)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct MetricCardTimeline: View {
    let samples: [MetricCard.TimelineSample]
    let accent: Color
    let lowAccent: Color?
    let baseline: Double?

    private var lowTint: Color {
        lowAccent ?? accent.opacity(0.26)
    }

    var body: some View {
        GeometryReader { proxy in
            let metrics = MetricCardTimelineMetrics(
                samples: samples,
                size: proxy.size,
                baseline: baseline
            )

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignTokens.chromeFill.opacity(0.34),
                                DesignTokens.chromeWash.opacity(0.58),
                                DesignTokens.surface.opacity(0.22),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .fill(accent.opacity(0.12))
                    .frame(width: 72, height: 72)
                    .blur(radius: 14)
                    .offset(x: metrics.contentRect.maxX - 42, y: metrics.contentRect.minY - 18)

                ForEach(metrics.horizontalGuideYs, id: \.self) { y in
                    Rectangle()
                        .fill(DesignTokens.border.opacity(0.16))
                        .frame(width: metrics.contentRect.width, height: 1)
                        .offset(x: metrics.contentRect.minX, y: y)
                }

                ForEach(Array(metrics.verticalGuideXs.enumerated()), id: \.offset) { _, x in
                    Rectangle()
                        .fill(DesignTokens.border.opacity(0.12))
                        .frame(width: 1, height: metrics.contentRect.height)
                        .offset(x: x, y: metrics.contentRect.minY)
                }

                Path { path in
                    guard let first = metrics.points.first else { return }
                    path.move(to: CGPoint(x: first.x, y: metrics.contentRect.maxY))
                    for point in metrics.points {
                        path.addLine(to: point)
                    }
                    if let last = metrics.points.last {
                        path.addLine(to: CGPoint(x: last.x, y: metrics.contentRect.maxY))
                    }
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [
                            accent.opacity(0.34),
                            lowTint,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                Path { path in
                    guard let first = metrics.points.first else { return }
                    path.move(to: first)
                    for point in metrics.points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [
                            accent.opacity(0.98),
                            lowTint.opacity(0.88),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)
                )

                if let firstPoint = metrics.points.first {
                    Circle()
                        .fill(accent.opacity(0.35))
                        .frame(width: 4.5, height: 4.5)
                        .offset(x: firstPoint.x - 2.25, y: firstPoint.y - 2.25)
                }

                if let lastPoint = metrics.points.last {
                    Circle()
                        .fill(accent.opacity(0.55))
                        .frame(width: 5.5, height: 5.5)
                        .offset(x: lastPoint.x - 2.75, y: lastPoint.y - 2.75)
                }

                if let currentPoint = metrics.currentPoint {
                    Rectangle()
                        .fill(accent.opacity(0.22))
                        .frame(width: 1, height: metrics.contentRect.height)
                        .offset(x: currentPoint.x, y: metrics.contentRect.minY)

                    Circle()
                        .fill(DesignTokens.background)
                        .frame(width: 11, height: 11)
                        .overlay {
                            Circle()
                                .stroke(accent, lineWidth: 2.2)
                        }
                        .offset(x: currentPoint.x - 5.5, y: currentPoint.y - 5.5)
                }
            }
        }
    }
}

private struct MetricCardTimelineMetrics {
    let contentRect: CGRect
    let points: [CGPoint]
    let currentPoint: CGPoint?
    let horizontalGuideYs: [CGFloat]
    let verticalGuideXs: [CGFloat]

    init(samples: [MetricCard.TimelineSample], size: CGSize, baseline: Double? = nil) {
        let horizontalPadding: CGFloat = 7
        let verticalPadding: CGFloat = 6
        let contentRect = CGRect(
            x: horizontalPadding,
            y: verticalPadding,
            width: max(size.width - horizontalPadding * 2, 1),
            height: max(size.height - verticalPadding * 2, 1)
        )
        self.contentRect = contentRect
        self.horizontalGuideYs = [0.25, 0.5, 0.75].map {
            contentRect.minY + contentRect.height * CGFloat($0)
        }

        let values = samples.map(\.value)
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? minValue + 1
        let lowerBound = baseline.map { min($0, minValue) } ?? minValue
        let upperBound: Double
        if let baseline {
            let headroomBase = max(maxValue - min(baseline, minValue), 1)
            upperBound = max(maxValue, lowerBound + headroomBase * 1.12)
        } else {
            upperBound = maxValue
        }
        let span = max(upperBound - lowerBound, 0.5)
        let isFlat = baseline == nil && abs(maxValue - minValue) < 0.01
        let stepX = samples.count > 1 ? contentRect.width / CGFloat(samples.count - 1) : 0
        let guideDivisions = max(min(samples.count - 1, 4), 1)
        if guideDivisions <= 1 {
            self.verticalGuideXs = [contentRect.midX]
        } else {
            self.verticalGuideXs = (1..<guideDivisions).map { index in
                contentRect.minX + contentRect.width * (CGFloat(index) / CGFloat(guideDivisions))
            }
        }

        let points = samples.enumerated().map { index, sample in
            let normalized = isFlat ? 0.5 : max(0, min((sample.value - lowerBound) / span, 1))
            return CGPoint(
                x: contentRect.minX + CGFloat(index) * stepX,
                y: contentRect.maxY - CGFloat(normalized) * contentRect.height
            )
        }
        self.points = points

        if let currentIndex = samples.firstIndex(where: \.isCurrent), points.indices.contains(currentIndex) {
            self.currentPoint = points[currentIndex]
        } else {
            self.currentPoint = nil
        }
    }
}
