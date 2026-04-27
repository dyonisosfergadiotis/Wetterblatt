import SwiftUI
import WidgetKit

struct WetterblattTimelineEntry: TimelineEntry {
    let date: Date
    let state: WidgetWeatherDisplayState?
}

struct WetterblattWidgetProvider: TimelineProvider {
    private let source = WidgetSharedDataSource()

    func placeholder(in context: Context) -> WetterblattTimelineEntry {
        WetterblattTimelineEntry(date: .now, state: WidgetPreviewFactory.clearSky)
    }

    func getSnapshot(in context: Context, completion: @escaping (WetterblattTimelineEntry) -> Void) {
        if context.isPreview {
            completion(WetterblattTimelineEntry(date: .now, state: WidgetPreviewFactory.clearSky))
            return
        }

        let selection = source.loadSelection()
        let state = selection.map { source.makeState(selection: $0, now: .now) } ?? WidgetPreviewFactory.clearSky
        completion(WetterblattTimelineEntry(date: .now, state: state))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WetterblattTimelineEntry>) -> Void) {
        let now = Date()
        let dates = stride(from: 0, through: 5, by: 1).compactMap {
            Calendar.current.date(byAdding: .minute, value: $0 * 30, to: now)
        }

        let selection = source.loadSelection()
        let entries = dates.map { date in
            WetterblattTimelineEntry(
                date: date,
                state: selection.map { source.makeState(selection: $0, now: date) }
            )
        }

        let refreshDate = Calendar.current.date(byAdding: .minute, value: 30, to: now) ?? now.addingTimeInterval(1_800)
        completion(Timeline(entries: entries, policy: .after(refreshDate)))
    }
}

private struct CurrentConditionsHomeWidgetView: View {
    let state: WidgetWeatherDisplayState?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let state {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        WidgetEyebrow("AKTUELL")
                        Text(state.placeName)
                            .font(WidgetDesign.serif(size: 21, weight: .bold))
                            .foregroundStyle(WidgetDesign.ink)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    WidgetBadge(text: state.freshness.label.uppercased())
                }

                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(state.temperatureText)
                            .font(WidgetDesign.heroFont(size: 46))
                            .foregroundStyle(WidgetDesign.ink)
                            .contentTransition(.numericText())

                        Text(state.descriptor.title)
                            .font(WidgetDesign.serif(size: 15))
                            .foregroundStyle(WidgetDesign.ink)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)

                    WidgetWeatherSymbol(
                        weatherCode: state.current.weatherCode,
                        isDay: state.current.isDay,
                        diameter: 62,
                        symbolSize: 28
                    )
                }

                HStack(spacing: 8) {
                    WidgetMetricTile(title: "Tag", value: state.highLowText)
                    WidgetMetricTile(title: "Gefühlt", value: state.apparentText)
                    WidgetMetricTile(title: "Regen", value: state.rainChanceText)
                }

                Text(state.stampText)
                    .font(WidgetDesign.mono(size: 9))
                    .foregroundStyle(WidgetDesign.secondaryText)
                    .lineLimit(1)
            } else {
                WidgetEmptyState(
                    title: "Noch kein Wetter",
                    message: "Öffne die App, damit Wetterblatt einen Ort in die Widgets schreiben kann."
                )
            }
        }
        .padding(16)
    }
}

private struct HourlyHomeWidgetView: View {
    let state: WidgetWeatherDisplayState?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let state {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        WidgetEyebrow("STUNDEN")
                        Text(state.placeName)
                            .font(WidgetDesign.serif(size: 24, weight: .bold))
                            .foregroundStyle(WidgetDesign.ink)
                            .lineLimit(1)
                        Text(state.rainLeadText)
                            .font(WidgetDesign.mono(size: 10))
                            .foregroundStyle(WidgetDesign.secondaryText)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(state.temperatureText)
                            .font(WidgetDesign.heroFont(size: 40))
                            .foregroundStyle(WidgetDesign.ink)
                            .contentTransition(.numericText())

                        Text(state.descriptor.title)
                            .font(WidgetDesign.mono(size: 10))
                            .foregroundStyle(WidgetDesign.secondaryText)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 8) {
                    ForEach(Array(state.hourly.prefix(5))) { hour in
                        WidgetHourColumn(hour: hour)
                    }
                }

                HStack(spacing: 8) {
                    WidgetMetricStrip(label: "Spanne", value: state.highLowText)
                    WidgetMetricStrip(label: "Niederschlag", value: state.precipitationAmountText)
                    WidgetMetricStrip(label: "Stand", value: WidgetFormatters.time.string(from: state.fetchedAt, timeZone: state.timeZone))
                }
            } else {
                WidgetEmptyState(
                    title: "Keine Stundenansicht",
                    message: "Sobald ein Ort geladen wurde, erscheinen hier die kommenden Stunden."
                )
            }
        }
        .padding(16)
    }
}

private struct PrecipitationHomeWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let state: WidgetWeatherDisplayState?

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 12 : 14) {
            if let state {
                let highlight = state.nextWetHour ?? state.peakRainHour
                let headlineValue = Int((highlight?.precipitationProbability ?? 0).rounded())

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        WidgetEyebrow("NIEDERSCHLAG")
                        Text(state.placeName)
                            .font(WidgetDesign.serif(size: family == .systemSmall ? 19 : 24, weight: .bold))
                            .foregroundStyle(WidgetDesign.ink)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "drop.fill")
                        .font(.system(size: family == .systemSmall ? 18 : 22, weight: .semibold))
                        .foregroundStyle(WidgetDesign.rain)
                }

                if family == .systemSmall {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(headlineValue) %")
                            .font(WidgetDesign.heroFont(size: 42))
                            .foregroundStyle(WidgetDesign.ink)
                            .contentTransition(.numericText())

                        Text(state.rainLeadText)
                            .font(WidgetDesign.mono(size: 10))
                            .foregroundStyle(WidgetDesign.secondaryText)
                            .lineLimit(2)
                    }

                    HStack(alignment: .bottom, spacing: 7) {
                        ForEach(Array(state.hourly.prefix(4))) { hour in
                            WidgetRainColumn(hour: hour, emphasizeLabel: false)
                        }
                    }
                } else {
                    HStack(alignment: .bottom, spacing: 14) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("\(headlineValue) %")
                                .font(WidgetDesign.heroFont(size: 50))
                                .foregroundStyle(WidgetDesign.ink)
                                .contentTransition(.numericText())

                            Text(state.rainLeadText)
                                .font(WidgetDesign.mono(size: 10))
                                .foregroundStyle(WidgetDesign.secondaryText)
                                .lineLimit(2)

                            HStack(spacing: 8) {
                                WidgetMetricStrip(label: "Menge", value: state.precipitationAmountText)
                                WidgetMetricStrip(label: "Heute", value: state.rainChanceText)
                            }
                        }

                        Spacer(minLength: 0)

                        HStack(alignment: .bottom, spacing: 8) {
                            ForEach(Array(state.hourly.prefix(6))) { hour in
                                WidgetRainColumn(hour: hour, emphasizeLabel: true)
                            }
                        }
                    }
                }
            } else {
                WidgetEmptyState(
                    title: "Kein Regenfenster",
                    message: "Öffne die App, damit das Widget die Niederschlagswerte kennt."
                )
            }
        }
        .padding(16)
    }
}

private struct WeeklyHomeWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let state: WidgetWeatherDisplayState?

    private var visibleDays: Int {
        family == .systemLarge ? 6 : 4
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let state {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        WidgetEyebrow("WOCHE")
                        Text(state.placeName)
                            .font(WidgetDesign.serif(size: family == .systemLarge ? 25 : 22, weight: .bold))
                            .foregroundStyle(WidgetDesign.ink)
                            .lineLimit(1)
                        Text(state.subtitle)
                            .font(WidgetDesign.mono(size: 10))
                            .foregroundStyle(WidgetDesign.secondaryText)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 12)

                    WidgetBadge(text: state.temperatureText)
                }

                VStack(spacing: family == .systemLarge ? 10 : 8) {
                    ForEach(Array(state.daily.prefix(visibleDays))) { day in
                        WidgetWeekRow(day: day, range: state.weeklyTemperatureRange)
                    }
                }
            } else {
                WidgetEmptyState(
                    title: "Keine Wochenansicht",
                    message: "Sobald Vorhersagedaten vorhanden sind, erscheinen hier die nächsten Tage."
                )
            }
        }
        .padding(16)
    }
}

private struct WetterblattWeatherInlineAccessoryView: View {
    let state: WidgetWeatherDisplayState?

    var body: some View {
        if let state {
            Text("\(state.temperatureText) \(state.descriptor.title)")
        } else {
            Text("Wetter")
        }
    }
}

private struct WetterblattWeatherCircularAccessoryView: View {
    let state: WidgetWeatherDisplayState?

    var body: some View {
        if let state {
            VStack(spacing: 2) {
                Image(systemName: state.descriptor.symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(WidgetDesign.tint(for: state.current.weatherCode, isDay: state.current.isDay))
                    .widgetAccentable()

                Text(state.temperatureText)
                    .font(WidgetDesign.serif(size: 15, weight: .bold))
                    .foregroundStyle(.primary)
                    .widgetAccentable()
            }
        } else {
            Image(systemName: "cloud")
        }
    }
}

private struct WetterblattWeatherRectangularAccessoryView: View {
    let state: WidgetWeatherDisplayState?

    var body: some View {
        if let state {
            HStack(spacing: 10) {
                WidgetWeatherSymbol(
                    weatherCode: state.current.weatherCode,
                    isDay: state.current.isDay,
                    diameter: 34,
                    symbolSize: 15
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text("WETTER")
                        .font(WidgetDesign.mono(size: 8, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text(state.descriptor.title)
                        .font(WidgetDesign.serif(size: 14))
                        .lineLimit(1)

                    Text("Spanne \(state.highLowText)")
                        .font(WidgetDesign.mono(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text(state.temperatureText)
                    .font(WidgetDesign.heroFont(size: 28))
                    .foregroundStyle(.primary)
                    .widgetAccentable()
            }
        } else {
            Text("Wetter")
        }
    }
}

private struct WetterblattRainInlineAccessoryView: View {
    let state: WidgetWeatherDisplayState?

    var body: some View {
        if let state, let peak = state.peakRainHour {
            Text("Regen \(Int(peak.precipitationProbability.rounded())) %")
        } else {
            Text("Regen trocken")
        }
    }
}

private struct WetterblattRainCircularAccessoryView: View {
    let state: WidgetWeatherDisplayState?

    var body: some View {
        if let state {
            let peak = Int((state.peakRainHour?.precipitationProbability ?? 0).rounded())

            VStack(spacing: 2) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(WidgetDesign.rain)
                    .widgetAccentable()

                Text("\(peak)%")
                    .font(WidgetDesign.serif(size: 14, weight: .bold))
                    .foregroundStyle(.primary)
                    .widgetAccentable()
            }
        } else {
            Image(systemName: "drop")
        }
    }
}

private struct WetterblattRainRectangularAccessoryView: View {
    let state: WidgetWeatherDisplayState?

    var body: some View {
        if let state {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("REGEN")
                        .font(WidgetDesign.mono(size: 8, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text(state.rainLeadText)
                        .font(WidgetDesign.serif(size: 13))
                        .lineLimit(1)

                    Text("Menge \(state.precipitationAmountText)")
                        .font(WidgetDesign.mono(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(state.hourly.prefix(4))) { hour in
                        WidgetAccessoryRainBar(hour: hour)
                    }
                }
                .frame(width: 54, alignment: .trailing)
            }
        } else {
            Text("Regen")
        }
    }
}

private struct WetterblattWeatherAccessoryEntryView: View {
    @Environment(\.widgetFamily) private var family

    let state: WidgetWeatherDisplayState?

    var body: some View {
        switch family {
        case .accessoryInline:
            WetterblattWeatherInlineAccessoryView(state: state)
        case .accessoryCircular:
            WetterblattWeatherCircularAccessoryView(state: state)
        default:
            WetterblattWeatherRectangularAccessoryView(state: state)
        }
    }
}

private struct WetterblattRainAccessoryEntryView: View {
    @Environment(\.widgetFamily) private var family

    let state: WidgetWeatherDisplayState?

    var body: some View {
        switch family {
        case .accessoryInline:
            WetterblattRainInlineAccessoryView(state: state)
        case .accessoryCircular:
            WetterblattRainCircularAccessoryView(state: state)
        default:
            WetterblattRainRectangularAccessoryView(state: state)
        }
    }
}

private struct WidgetEyebrow: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(WidgetDesign.mono(size: 9, weight: .medium))
            .foregroundStyle(WidgetDesign.secondaryText)
            .lineLimit(1)
    }
}

private struct WidgetBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(WidgetDesign.mono(size: 8, weight: .medium))
            .foregroundStyle(WidgetDesign.secondaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(WidgetDesign.surface.opacity(0.92))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(WidgetDesign.border, lineWidth: 0.8)
            )
    }
}

private struct WidgetMetricTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(WidgetDesign.mono(size: 7, weight: .medium))
                .foregroundStyle(WidgetDesign.secondaryText)
                .lineLimit(1)

            Text(value)
                .font(WidgetDesign.serif(size: 12, weight: .semibold))
                .foregroundStyle(WidgetDesign.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(WidgetDesign.surface.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(WidgetDesign.border, lineWidth: 0.8)
        )
    }
}

private struct WidgetMetricStrip: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(WidgetDesign.mono(size: 7, weight: .medium))
                .foregroundStyle(WidgetDesign.secondaryText)

            Text(value)
                .font(WidgetDesign.mono(size: 10, weight: .medium))
                .foregroundStyle(WidgetDesign.ink)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WidgetHourColumn: View {
    let hour: WidgetResolvedHour

    var body: some View {
        VStack(spacing: 7) {
            Text(hour.shortLabel)
                .font(WidgetDesign.mono(size: 8, weight: hour.isCurrentHour ? .medium : .regular))
                .foregroundStyle(hour.isCurrentHour ? WidgetDesign.ink : WidgetDesign.secondaryText)
                .lineLimit(1)

            Image(systemName: WidgetWeatherConditions.descriptor(for: hour.weatherCode, isDay: hour.isDay).symbolName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(WidgetDesign.tint(for: hour.weatherCode, isDay: hour.isDay))

            Text("\(Int(hour.temperature.rounded()))°")
                .font(WidgetDesign.serif(size: 14))
                .foregroundStyle(WidgetDesign.ink)

            Capsule()
                .fill(WidgetDesign.rain.opacity(max(0.12, hour.precipitationProbability / 100)))
                .frame(
                    width: 18,
                    height: max(CGFloat(3), min(CGFloat(12), CGFloat(hour.precipitationProbability / 8)))
                )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(hour.isCurrentHour ? Color.white.opacity(0.56) : WidgetDesign.surface.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(hour.isCurrentHour ? WidgetDesign.sun.opacity(0.55) : WidgetDesign.border, lineWidth: 0.8)
        )
    }
}

private struct WidgetRainColumn: View {
    let hour: WidgetResolvedHour
    let emphasizeLabel: Bool

    private var barHeight: CGFloat {
        max(CGFloat(16), min(CGFloat(60), CGFloat(16 + (hour.precipitationProbability * 0.44))))
    }

    var body: some View {
        VStack(spacing: 6) {
            if emphasizeLabel {
                Text(hour.shortLabel)
                    .font(WidgetDesign.mono(size: 8))
                    .foregroundStyle(WidgetDesign.secondaryText)
                    .lineLimit(1)
            }

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            WidgetDesign.rain.opacity(0.30),
                            WidgetDesign.rain.opacity(0.82),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: emphasizeLabel ? 18 : 22, height: barHeight)
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(Color.white.opacity(0.40))
                        .frame(width: emphasizeLabel ? 10 : 12, height: 2)
                        .padding(.top, 5)
                }

            Text("\(Int(hour.precipitationProbability.rounded()))")
                .font(WidgetDesign.serif(size: emphasizeLabel ? 11 : 12, weight: .bold))
                .foregroundStyle(WidgetDesign.ink)

            if !emphasizeLabel {
                Text(hour.shortLabel)
                    .font(WidgetDesign.mono(size: 8))
                    .foregroundStyle(WidgetDesign.secondaryText)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .bottom)
    }
}

private struct WidgetWeekRow: View {
    let day: WidgetResolvedDay
    let range: ClosedRange<Double>

    var body: some View {
        HStack(spacing: 10) {
            Text(day.label)
                .font(WidgetDesign.mono(size: 10, weight: day.isToday ? .medium : .regular))
                .foregroundStyle(day.isToday ? WidgetDesign.ink : WidgetDesign.secondaryText)
                .frame(width: 54, alignment: .leading)

            Image(systemName: WidgetWeatherConditions.descriptor(for: day.weatherCode, isDay: true).symbolName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(WidgetDesign.tint(for: day.weatherCode, isDay: true))
                .frame(width: 18)

            WidgetTemperatureRangeTrack(
                minimum: day.temperatureMin,
                maximum: day.temperatureMax,
                range: range
            )
            .frame(maxWidth: .infinity)
            .frame(height: 12)

            Text("\(Int(day.temperatureMin.rounded()))°")
                .font(WidgetDesign.mono(size: 10))
                .foregroundStyle(WidgetDesign.secondaryText)
                .frame(width: 28, alignment: .trailing)

            Text("\(Int(day.temperatureMax.rounded()))°")
                .font(WidgetDesign.serif(size: 13, weight: .bold))
                .foregroundStyle(WidgetDesign.ink)
                .frame(width: 32, alignment: .trailing)

            Text("\(Int(day.precipitationProbabilityMax.rounded()))%")
                .font(WidgetDesign.mono(size: 9))
                .foregroundStyle(WidgetDesign.secondaryText)
                .frame(width: 34, alignment: .trailing)
        }
    }
}

private struct WidgetTemperatureRangeTrack: View {
    let minimum: Double
    let maximum: Double
    let range: ClosedRange<Double>

    var body: some View {
        GeometryReader { proxy in
            let span = max(range.upperBound - range.lowerBound, 1)
            let start = CGFloat((minimum - range.lowerBound) / span) * proxy.size.width
            let width = max(12, CGFloat((maximum - minimum) / span) * proxy.size.width)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(WidgetDesign.surface.opacity(0.95))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                WidgetDesign.sun.opacity(0.55),
                                WidgetDesign.sun,
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(CGFloat(12), min(proxy.size.width - start, width)))
                    .offset(x: start)
            }
            .overlay(
                Capsule()
                    .stroke(WidgetDesign.border, lineWidth: 0.8)
            )
        }
    }
}

private struct WidgetAccessoryRainBar: View {
    let hour: WidgetResolvedHour

    var body: some View {
        Capsule()
            .fill(WidgetDesign.rain.opacity(max(0.18, hour.precipitationProbability / 100)))
            .frame(
                width: 9,
                height: max(CGFloat(10), min(CGFloat(26), CGFloat(8 + hour.precipitationProbability / 5)))
            )
    }
}

private struct WidgetEmptyState: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetEyebrow("WETTERBLATT")

            Spacer(minLength: 0)

            Text(title)
                .font(WidgetDesign.serif(size: 18, weight: .bold))
                .foregroundStyle(WidgetDesign.ink)

            Text(message)
                .font(WidgetDesign.mono(size: 10))
                .foregroundStyle(WidgetDesign.secondaryText)
                .lineSpacing(2)

            Spacer(minLength: 0)
        }
    }
}

struct WetterblattCurrentWidget: Widget {
    let kind = "WetterblattCurrentWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WetterblattWidgetProvider()) { entry in
            CurrentConditionsHomeWidgetView(state: entry.state)
                .containerBackground(for: .widget) {
                    WidgetPaperBackground()
                }
        }
        .configurationDisplayName("Wetter aktuell")
        .description("Kompakte aktuelle Lage mit Temperatur, Spanne und Regenwahrscheinlichkeit.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

struct WetterblattHourlyWidget: Widget {
    let kind = "WetterblattHourlyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WetterblattWidgetProvider()) { entry in
            HourlyHomeWidgetView(state: entry.state)
                .containerBackground(for: .widget) {
                    WidgetPaperBackground()
                }
        }
        .configurationDisplayName("Wetter Stunden")
        .description("Die nächsten Stunden mit Temperatur, Symbolen und Regenanzeige.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

struct WetterblattPrecipitationWidget: Widget {
    let kind = "WetterblattPrecipitationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WetterblattWidgetProvider()) { entry in
            PrecipitationHomeWidgetView(state: entry.state)
                .containerBackground(for: .widget) {
                    WidgetPaperBackground()
                }
        }
        .configurationDisplayName("Wetter Niederschlag")
        .description("Regenfenster mit Spitzenwahrscheinlichkeit und Verlauf der nächsten Stunden.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct WetterblattWeeklyWidget: Widget {
    let kind = "WetterblattWeeklyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WetterblattWidgetProvider()) { entry in
            WeeklyHomeWidgetView(state: entry.state)
                .containerBackground(for: .widget) {
                    WidgetPaperBackground()
                }
        }
        .configurationDisplayName("Wetter Woche")
        .description("Mehrere Tage im Überblick mit Temperaturbereich und Regenrisiko.")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

struct WetterblattWeatherAccessoryWidget: Widget {
    let kind = "WetterblattWeatherAccessoryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WetterblattWidgetProvider()) { entry in
            WetterblattWeatherAccessoryEntryView(state: entry.state)
        }
        .configurationDisplayName("Wetter Lockscreen")
        .description("Lock-Screen-Widget mit Temperatur und aktueller Wetterlage.")
        .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

struct WetterblattRainAccessoryWidget: Widget {
    let kind = "WetterblattRainAccessoryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WetterblattWidgetProvider()) { entry in
            WetterblattRainAccessoryEntryView(state: entry.state)
        }
        .configurationDisplayName("Regen Lockscreen")
        .description("Lock-Screen-Widget für Regenrisiko und Niederschlagsfenster.")
        .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

struct WidgetPreviewFactory {
    static var clearSky: WidgetWeatherDisplayState {
        let timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
        let now = Date()

        return WidgetWeatherDisplayState(
            placeName: "Berlin",
            subtitle: "Deutschland",
            timeZone: timeZone,
            fetchedAt: now,
            freshness: .fresh,
            current: WidgetResolvedCurrentWeather(
                timestamp: now,
                temperature: 18,
                apparentTemperature: 17,
                relativeHumidity: 52,
                windSpeed: 12,
                weatherCode: 1,
                isDay: true
            ),
            hourly: [
                WidgetResolvedHour(timestamp: now, label: "Jetzt", shortLabel: "Jetzt", temperature: 18, precipitationProbability: 10, precipitation: 0.0, weatherCode: 1, isDay: true, isCurrentHour: true),
                WidgetResolvedHour(timestamp: now.addingTimeInterval(3_600), label: "14:00", shortLabel: "14", temperature: 19, precipitationProbability: 15, precipitation: 0.0, weatherCode: 1, isDay: true, isCurrentHour: false),
                WidgetResolvedHour(timestamp: now.addingTimeInterval(7_200), label: "15:00", shortLabel: "15", temperature: 20, precipitationProbability: 18, precipitation: 0.0, weatherCode: 2, isDay: true, isCurrentHour: false),
                WidgetResolvedHour(timestamp: now.addingTimeInterval(10_800), label: "16:00", shortLabel: "16", temperature: 19, precipitationProbability: 22, precipitation: 0.2, weatherCode: 3, isDay: true, isCurrentHour: false),
                WidgetResolvedHour(timestamp: now.addingTimeInterval(14_400), label: "17:00", shortLabel: "17", temperature: 18, precipitationProbability: 26, precipitation: 0.4, weatherCode: 3, isDay: true, isCurrentHour: false),
                WidgetResolvedHour(timestamp: now.addingTimeInterval(18_000), label: "18:00", shortLabel: "18", temperature: 16, precipitationProbability: 20, precipitation: 0.1, weatherCode: 2, isDay: true, isCurrentHour: false),
            ],
            daily: [
                WidgetResolvedDay(date: now, label: "Heute", shortLabel: "Heu", temperatureMin: 10, temperatureMax: 21, weatherCode: 1, precipitationProbabilityMax: 18, isToday: true),
                WidgetResolvedDay(date: now.addingTimeInterval(86_400), label: "Morgen", shortLabel: "Mor", temperatureMin: 11, temperatureMax: 22, weatherCode: 2, precipitationProbabilityMax: 22, isToday: false),
                WidgetResolvedDay(date: now.addingTimeInterval(172_800), label: "So", shortLabel: "So", temperatureMin: 9, temperatureMax: 19, weatherCode: 61, precipitationProbabilityMax: 60, isToday: false),
                WidgetResolvedDay(date: now.addingTimeInterval(259_200), label: "Mo", shortLabel: "Mo", temperatureMin: 8, temperatureMax: 17, weatherCode: 3, precipitationProbabilityMax: 35, isToday: false),
                WidgetResolvedDay(date: now.addingTimeInterval(345_600), label: "Di", shortLabel: "Di", temperatureMin: 7, temperatureMax: 16, weatherCode: 63, precipitationProbabilityMax: 72, isToday: false),
                WidgetResolvedDay(date: now.addingTimeInterval(432_000), label: "Mi", shortLabel: "Mi", temperatureMin: 9, temperatureMax: 18, weatherCode: 2, precipitationProbabilityMax: 24, isToday: false),
            ],
            today: WidgetDailyForecastEntry(
                date: now,
                temperatureMin: 10,
                temperatureMax: 21,
                sunrise: now.addingTimeInterval(-18_000),
                sunset: now.addingTimeInterval(18_000),
                weatherCode: 1,
                precipitationProbabilityMax: 18
            ),
            nextSunEvent: WidgetResolvedSunEvent(
                kind: .sunset,
                date: now.addingTimeInterval(18_000),
                label: "Untergang"
            )
        )
    }

    static var rainFront: WidgetWeatherDisplayState {
        let timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
        let now = Date()

        return WidgetWeatherDisplayState(
            placeName: "Hamburg",
            subtitle: "Deutschland",
            timeZone: timeZone,
            fetchedAt: now,
            freshness: .fresh,
            current: WidgetResolvedCurrentWeather(
                timestamp: now,
                temperature: 12,
                apparentTemperature: 10,
                relativeHumidity: 78,
                windSpeed: 24,
                weatherCode: 61,
                isDay: true
            ),
            hourly: [
                WidgetResolvedHour(timestamp: now, label: "Jetzt", shortLabel: "Jetzt", temperature: 12, precipitationProbability: 55, precipitation: 0.6, weatherCode: 61, isDay: true, isCurrentHour: true),
                WidgetResolvedHour(timestamp: now.addingTimeInterval(3_600), label: "14:00", shortLabel: "14", temperature: 12, precipitationProbability: 70, precipitation: 1.2, weatherCode: 63, isDay: true, isCurrentHour: false),
                WidgetResolvedHour(timestamp: now.addingTimeInterval(7_200), label: "15:00", shortLabel: "15", temperature: 11, precipitationProbability: 82, precipitation: 2.1, weatherCode: 63, isDay: true, isCurrentHour: false),
                WidgetResolvedHour(timestamp: now.addingTimeInterval(10_800), label: "16:00", shortLabel: "16", temperature: 11, precipitationProbability: 76, precipitation: 1.8, weatherCode: 80, isDay: true, isCurrentHour: false),
                WidgetResolvedHour(timestamp: now.addingTimeInterval(14_400), label: "17:00", shortLabel: "17", temperature: 10, precipitationProbability: 64, precipitation: 1.0, weatherCode: 61, isDay: true, isCurrentHour: false),
                WidgetResolvedHour(timestamp: now.addingTimeInterval(18_000), label: "18:00", shortLabel: "18", temperature: 10, precipitationProbability: 40, precipitation: 0.4, weatherCode: 3, isDay: true, isCurrentHour: false),
            ],
            daily: [
                WidgetResolvedDay(date: now, label: "Heute", shortLabel: "Heu", temperatureMin: 9, temperatureMax: 13, weatherCode: 61, precipitationProbabilityMax: 82, isToday: true),
                WidgetResolvedDay(date: now.addingTimeInterval(86_400), label: "Morgen", shortLabel: "Mor", temperatureMin: 8, temperatureMax: 12, weatherCode: 63, precipitationProbabilityMax: 78, isToday: false),
                WidgetResolvedDay(date: now.addingTimeInterval(172_800), label: "So", shortLabel: "So", temperatureMin: 7, temperatureMax: 11, weatherCode: 80, precipitationProbabilityMax: 66, isToday: false),
                WidgetResolvedDay(date: now.addingTimeInterval(259_200), label: "Mo", shortLabel: "Mo", temperatureMin: 6, temperatureMax: 12, weatherCode: 3, precipitationProbabilityMax: 34, isToday: false),
                WidgetResolvedDay(date: now.addingTimeInterval(345_600), label: "Di", shortLabel: "Di", temperatureMin: 5, temperatureMax: 13, weatherCode: 2, precipitationProbabilityMax: 28, isToday: false),
                WidgetResolvedDay(date: now.addingTimeInterval(432_000), label: "Mi", shortLabel: "Mi", temperatureMin: 6, temperatureMax: 14, weatherCode: 1, precipitationProbabilityMax: 12, isToday: false),
            ],
            today: WidgetDailyForecastEntry(
                date: now,
                temperatureMin: 9,
                temperatureMax: 13,
                sunrise: now.addingTimeInterval(-16_000),
                sunset: now.addingTimeInterval(15_000),
                weatherCode: 61,
                precipitationProbabilityMax: 82
            ),
            nextSunEvent: WidgetResolvedSunEvent(
                kind: .sunset,
                date: now.addingTimeInterval(15_000),
                label: "Untergang"
            )
        )
    }
}

#Preview(as: .systemSmall) {
    WetterblattCurrentWidget()
} timeline: {
    WetterblattTimelineEntry(date: .now, state: WidgetPreviewFactory.clearSky)
}

#Preview(as: .systemMedium) {
    WetterblattHourlyWidget()
} timeline: {
    WetterblattTimelineEntry(date: .now, state: WidgetPreviewFactory.clearSky)
}

#Preview(as: .systemSmall) {
    WetterblattPrecipitationWidget()
} timeline: {
    WetterblattTimelineEntry(date: .now, state: WidgetPreviewFactory.rainFront)
}

#Preview(as: .systemLarge) {
    WetterblattWeeklyWidget()
} timeline: {
    WetterblattTimelineEntry(date: .now, state: WidgetPreviewFactory.clearSky)
}

#Preview(as: .accessoryRectangular) {
    WetterblattWeatherAccessoryWidget()
} timeline: {
    WetterblattTimelineEntry(date: .now, state: WidgetPreviewFactory.clearSky)
}

#Preview(as: .accessoryRectangular) {
    WetterblattRainAccessoryWidget()
} timeline: {
    WetterblattTimelineEntry(date: .now, state: WidgetPreviewFactory.rainFront)
}
