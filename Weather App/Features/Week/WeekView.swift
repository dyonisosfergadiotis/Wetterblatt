import SwiftUI

private enum FutureOutlookMode: Equatable {
    case hourly
    case daily
}

private let precipitationChartDescription = "Balken zeigen die Menge in mm. % ist die Regenwahrscheinlichkeit an deinem Ort, nicht die betroffene Fläche."

struct WeekView: View {
    @Bindable var model: AppModel
    @State private var mode: FutureOutlookMode = .daily
    @State private var selectedDay: ResolvedDailyForecast?
    @State private var selectedDayID: Date?

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.clear)
                .paperBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if let state = model.weatherState {
                        ForecastDayPicker(
                            title: "Tag wählen",
                            days: Array(state.daily.prefix(10)),
                            selectedDayID: selectedDayID
                        ) { day in
                            selectedDayID = day.date
                        }

                        if mode == .hourly {
                            if let day = selectedDay(from: state) {
                                hourlyContent(state, day: day)
                            }
                        } else {
                            dailyContent(state)
                        }
                    } else {
                        Text("Noch keine Zukunftsdaten.")
                            .font(DesignTokens.mono(size: 11))
                            .foregroundStyle(DesignTokens.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .vintageCard()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 36)
            }
        }
        .sheet(item: $selectedDay) { day in
            DayForecastDetailSheet(model: model, day: day)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: mode) { oldValue, newValue in
            guard oldValue != newValue else { return }
            HapticManager.selectionChanged()
        }
        .onAppear {
            if selectedDayID == nil {
                selectedDayID = model.weatherState?.daily.first?.date
            }
        }
        .onChange(of: model.weatherState?.daily.map(\.date) ?? []) { _, newDates in
            guard !newDates.isEmpty else { return }
            if let selectedDayID, newDates.contains(selectedDayID) {
                return
            }

            self.selectedDayID = newDates.first
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ZUKUNFT")
                        .font(DesignTokens.mono(size: 10, weight: .medium))
                        .foregroundStyle(DesignTokens.secondaryText)

                    Text(model.weatherState?.place.name ?? "Zukunft")
                        .font(DesignTokens.serif(size: 30, weight: .bold))
                        .foregroundStyle(DesignTokens.ink)
                }

                Spacer()

            }

            HStack(spacing: 8) {
                Text("Stündlich für den gewählten Tag, täglich für die nächsten Tage.")
                    .font(DesignTokens.mono(size: 11))
                    .foregroundStyle(DesignTokens.tertiaryText)

                Spacer(minLength: 12)

                modeButton("Stündlich", isSelected: mode == .hourly) {
                    mode = .hourly
                }
                modeButton("Täglich", isSelected: mode == .daily) {
                    mode = .daily
                }
            }
        }
    }

    private func hourlyContent(_ state: WeatherScreenState, day: ResolvedDailyForecast) -> some View {
        VStack(spacing: 12) {
            HourlyChartCard(
                entries: temperatureEntries(for: day, in: state, now: model.clock.now),
                metric: .temperature,
                titleOverride: "Temperatur · \(day.displayLabel)",
                accentCurrentEntry: true
            )
            .vintageCard()

            HourlyChartCard(
                entries: precipitationEntries(for: day, in: state, now: model.clock.now),
                metric: .precipitationAmount,
                titleOverride: "Niederschlag · \(day.displayLabel)",
                descriptionText: precipitationChartDescription,
                accentCurrentEntry: true
            )
            .vintageCard()
        }
    }

    private func dailyContent(_ state: WeatherScreenState) -> some View {
        let days = Array(state.daily.prefix(10))
        let range = weeklyRange(from: days)

        return VStack(alignment: .leading, spacing: 10) {
            ForEach(days) { day in
                Button {
                    HapticManager.lightImpact()
                    selectedDayID = day.date
                    selectedDay = day
                } label: {
                    futureDayRow(day: day, range: range, isSelected: selectedDayID == day.date)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func futureDayRow(day: ResolvedDailyForecast, range: ClosedRange<Double>, isSelected: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(day.displayLabel)
                    .font(DesignTokens.mono(size: 11, weight: .medium))
                    .foregroundStyle(DesignTokens.ink)

                Text(dayDateSubtitle(for: day))
                    .font(DesignTokens.mono(size: 9))
                    .foregroundStyle(DesignTokens.secondaryText)
            }
            .frame(width: 62, alignment: .leading)

            WeatherIconView(weatherCode: day.weatherCode, isDay: true, size: .small)

            ForecastTemperatureRangeView(
                min: day.temperatureMin,
                max: day.temperatureMax,
                range: range
            )
            .frame(maxWidth: .infinity)
            .padding(.top, 4)

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(Int(day.precipitationProbabilityMax.rounded())) %")
                    .font(DesignTokens.serif(size: 18))
                    .foregroundStyle(DesignTokens.ink)

                Text("Niederschlag")
                    .font(DesignTokens.mono(size: 9))
                    .foregroundStyle(DesignTokens.secondaryText)
            }
            .frame(width: 74, alignment: .trailing)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DesignTokens.secondaryText)
                .padding(.top, 6)
        }
        .vintageCard()
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? DesignTokens.ink : Color.clear, lineWidth: 1.2)
        )
    }

    private func weeklyRange(from days: [ResolvedDailyForecast]) -> ClosedRange<Double> {
        let minValue = days.map(\.temperatureMin).min() ?? 0
        let maxValue = days.map(\.temperatureMax).max() ?? 1
        return minValue...maxValue
    }

    private func dayDateSubtitle(for day: ResolvedDailyForecast) -> String {
        WeatherDateFormatting.shortDayMonth(
            day.date,
            timeZone: model.weatherState?.snapshot.timeZone ?? .current
        )
    }

    private func selectedDay(from state: WeatherScreenState) -> ResolvedDailyForecast? {
        state.daily.first(where: { $0.date == selectedDayID }) ?? state.daily.first
    }

    private func modeButton(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(DesignTokens.mono(size: 10, weight: .medium))
                .foregroundStyle(isSelected ? DesignTokens.background : DesignTokens.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? DesignTokens.ink : DesignTokens.chromeFill)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? DesignTokens.ink : DesignTokens.border, lineWidth: 0.8)
                )
        }
        .buttonStyle(.plain)
    }
}

struct PrecipitationSheet: View {
    @Bindable var model: AppModel
    @State private var selectedDayID: Date?

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.clear)
                .paperBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    if let state = model.weatherState,
                       let day = selectedDay(from: state) {
                        ForecastDayPicker(
                            title: "Tag wählen",
                            days: Array(state.daily.prefix(7)),
                            selectedDayID: selectedDayID
                        ) { day in
                            selectedDayID = day.date
                        }
                        summaryCard(for: day, state: state)

                        HourlyChartCard(
                            entries: precipitationEntries(for: day, in: state, now: model.clock.now),
                            metric: .precipitationAmount,
                            titleOverride: "Regenmenge",
                            descriptionText: "Menge in mm, darunter Regenwahrscheinlichkeit an deinem Ort.",
                            accentCurrentEntry: true,
                            layoutStyle: .compact
                        )
                        .vintageCard()
                    } else {
                        Text("Noch keine Niederschlagsdaten.")
                            .font(DesignTokens.mono(size: 11))
                            .foregroundStyle(DesignTokens.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .vintageCard()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 36)
            }
        }
        .onAppear {
            if selectedDayID == nil {
                selectedDayID = model.weatherState?.daily.first?.date
            }
        }
        .onChange(of: model.weatherState?.daily.map(\.date) ?? []) { _, newDates in
            guard !newDates.isEmpty else { return }
            if let selectedDayID, newDates.contains(selectedDayID) {
                return
            }

            self.selectedDayID = newDates.first
        }
    }

    private var header: some View {
        WeatherSheetHeader(
            eyebrow: "NIEDERSCHLAG",
            title: model.weatherState?.place.name ?? "Niederschlag",
            subtitle: "Ein ruhiger Blick auf Tagesmenge, Spitzenzeit und Verlauf."
        )
    }

    private func summaryCard(for day: ResolvedDailyForecast, state: WeatherScreenState) -> some View {
        let hours = hourlyEntries(for: day, in: state)
        let totalPrecipitation = hours.reduce(0) { $0 + $1.precipitation }
        let peakHour = hours.max(by: { $0.precipitationProbability < $1.precipitationProbability })

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(day.displayLabel.uppercased())
                        .font(DesignTokens.mono(size: 10, weight: .medium))
                        .foregroundStyle(DesignTokens.secondaryText)

                    Text(precipitationSummary(for: day, total: totalPrecipitation))
                        .font(DesignTokens.serif(size: 17))
                        .foregroundStyle(DesignTokens.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                WeatherSheetMetricBadge(
                    title: "MAX",
                    value: "\(Int(day.precipitationProbabilityMax.rounded())) %"
                )
            }

            if let peakHour {
                WeatherSheetSupportingNote(
                    systemImage: "clock",
                    text: "Höchste Chance um \(hourLabel(for: peakHour.timestamp, relativeTo: model.clock.now, timeZone: state.snapshot.timeZone)): \(Int(peakHour.precipitationProbability.rounded())) %."
                )
            }
        }
        .vintageCard()
    }

    private func selectedDay(from state: WeatherScreenState) -> ResolvedDailyForecast? {
        state.daily.first(where: { $0.date == selectedDayID }) ?? state.daily.first
    }

    private func precipitationSummary(for day: ResolvedDailyForecast, total: Double) -> String {
        if day.precipitationProbabilityMax < 20 {
            return "Sieht nach einem ziemlich trockenen Tag aus. Erwartet werden nur etwa \(formattedPrecipitation(total))."
        }

        if day.precipitationProbabilityMax < 55 {
            return "Ein paar Schauer sind möglich. Insgesamt liegen wir bei ungefähr \(formattedPrecipitation(total))."
        }

        return "Regen ist gut im Spiel. Über den Tag summiert sich das auf rund \(formattedPrecipitation(total))."
    }
}

struct UVSheet: View {
    @Bindable var model: AppModel
    var showsCloseButton = false
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDayID: Date?

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.clear)
                .paperBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    if let state = model.weatherState,
                       let day = selectedDay(from: state) {
                        let chartEntries = uvEntries(for: day, in: state, now: model.clock.now)

                        ForecastDayPicker(
                            title: "Tag wählen",
                            days: Array(state.daily.prefix(7)),
                            selectedDayID: selectedDayID
                        ) { day in
                            selectedDayID = day.date
                        }
                        summaryCard(for: day, state: state)

                        if chartEntries.isEmpty {
                            Text("Für diesen Tag gibt es noch keinen stündlichen UV-Verlauf.")
                                .font(DesignTokens.mono(size: 11))
                                .foregroundStyle(DesignTokens.secondaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .vintageCard()
                        } else {
                            HourlyChartCard(
                                entries: chartEntries,
                                metric: .uvIndex,
                                titleOverride: "UV-Verlauf",
                                accentCurrentEntry: true,
                                layoutStyle: .compact
                            )
                            .vintageCard()
                        }
                    } else {
                        Text("Noch keine UV-Daten.")
                            .font(DesignTokens.mono(size: 11))
                            .foregroundStyle(DesignTokens.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .vintageCard()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
        }
        .onAppear {
            if selectedDayID == nil {
                selectedDayID = model.weatherState?.daily.first?.date
            }
        }
        .onChange(of: model.weatherState?.daily.map(\.date) ?? []) { _, newDates in
            guard !newDates.isEmpty else { return }
            if let selectedDayID, newDates.contains(selectedDayID) {
                return
            }

            self.selectedDayID = newDates.first
        }
    }

    private var header: some View {
        WeatherSheetHeader(
            eyebrow: "UV",
            title: model.weatherState?.place.name ?? "UV",
            subtitle: "Wähle einen Tag und prüfe die Belastung im ruhigen Tagesverlauf."
        ) {
            if showsCloseButton {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DesignTokens.ink)
                        .padding(12)
                        .background(DesignTokens.chromeFill)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(DesignTokens.border, lineWidth: 0.8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func summaryCard(for day: ResolvedDailyForecast, state: WeatherScreenState) -> some View {
        let hours = hourlyEntries(for: day, in: state)
        let hourlyMax = hours.compactMap(\.uvIndex).max()
        let maxUV = day.uvIndexMax ?? hourlyMax

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(day.displayLabel.uppercased())
                        .font(DesignTokens.mono(size: 10, weight: .medium))
                        .foregroundStyle(DesignTokens.secondaryText)

                    Text(uvSummary(for: maxUV))
                        .font(DesignTokens.serif(size: 17))
                        .foregroundStyle(DesignTokens.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                uvMetricBadge(
                    title: "MAX",
                    value: maxUV.map(formattedUVIndex) ?? "—"
                )
            }

            WeatherSheetSupportingNote(
                systemImage: "sun.max",
                text: uvSupportText(for: maxUV)
            )
        }
        .vintageCard()
    }

    private func selectedDay(from state: WeatherScreenState) -> ResolvedDailyForecast? {
        state.daily.first(where: { $0.date == selectedDayID }) ?? state.daily.first
    }

    private func uvSummary(for maxUV: Double?) -> String {
        guard let maxUV else { return "Für diesen Tag liegt noch keine verlässliche UV-Prognose vor." }

        switch maxUV {
        case ..<3:
            return "Kaum Belastung. Normaler Alltag draußen ist meist unkritisch."
        case ..<6:
            return "Mittags etwas aufpassen. Schatten und Sonnenbrille reichen oft schon."
        case ..<8:
            return "Kräftige Sonne. Schutz und kurze Pausen im Schatten sind sinnvoll."
        case ..<11:
            return "Hohe UV-Last. Längere direkte Sonne solltest du besser vermeiden."
        default:
            return "Sehr starke Belastung. Mittags nur kurz raus und konsequent schützen."
        }
    }

    private func uvSupportText(for maxUV: Double?) -> String {
        guard let maxUV else { return "Die Prognose ist noch zu dünn für eine verlässliche Einschätzung." }

        switch maxUV {
        case ..<3:
            return "Die kritischste Phase bleibt voraussichtlich kurz und moderat."
        case ..<6:
            return "Mittags kurz den Schatten mitdenken, davor und danach ist es entspannter."
        case ..<8:
            return "Die stärkste Phase liegt klar in der Tagesmitte und braucht Schutz."
        case ..<11:
            return "Um die Mittagsstunden steigt die Belastung deutlich an."
        default:
            return "Zur Mittagszeit ist die Belastung sehr hoch und kaum verzeihend."
        }
    }

    private func uvMetricBadge(title: String, value: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(title)
                .font(DesignTokens.mono(size: 9, weight: .medium))
                .foregroundStyle(DesignTokens.secondaryText)

            Text(value)
                .font(DesignTokens.serif(size: 28))
                .foregroundStyle(DesignTokens.ink)
        }
        .frame(minWidth: 68, alignment: .trailing)
    }

}

private struct DayForecastDetailSheet: View {
    @Bindable var model: AppModel
    let day: ResolvedDailyForecast
    @State private var selectedDayID: Date?

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.clear)
                .paperBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    if let state = model.weatherState {
                        if let selectedDay = selectedDay(from: state) {
                            header(for: selectedDay)

                            ForecastDayPicker(
                                title: "Tag wählen",
                                days: Array(state.daily.prefix(10)),
                                selectedDayID: selectedDayID
                            ) { day in
                                selectedDayID = day.date
                            }

                            let hours = hourlyEntries(for: selectedDay, in: state)

                            summaryCard(day: selectedDay, state: state, hours: hours)

                            HourlyChartCard(
                                entries: temperatureEntries(for: selectedDay, in: state, now: model.clock.now),
                                metric: .temperature,
                                titleOverride: "Temperatur",
                                accentCurrentEntry: true,
                                layoutStyle: .compact
                            )
                            .vintageCard()

                            HourlyChartCard(
                                entries: precipitationEntries(for: selectedDay, in: state, now: model.clock.now),
                                metric: .precipitationAmount,
                                titleOverride: "Niederschlag",
                                descriptionText: "Menge in mm, darunter Regenwahrscheinlichkeit an deinem Ort.",
                                accentCurrentEntry: true,
                                layoutStyle: .compact
                            )
                            .vintageCard()
                        }
                    } else {
                        Text("Noch keine Tagesdetails.")
                            .font(DesignTokens.mono(size: 11))
                            .foregroundStyle(DesignTokens.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .vintageCard()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 36)
            }
        }
        .onAppear {
            if selectedDayID == nil {
                selectedDayID = day.date
            }
        }
        .onChange(of: model.weatherState?.daily.map(\.date) ?? []) { _, newDates in
            guard !newDates.isEmpty else { return }
            if let selectedDayID, newDates.contains(selectedDayID) {
                return
            }

            self.selectedDayID = newDates.first
        }
    }

    private func header(for day: ResolvedDailyForecast) -> some View {
        WeatherSheetHeader(
            eyebrow: "TAG",
            title: dayTitle(for: day),
            subtitle: "Einheitlicher Überblick über Temperatur und Regen."
        )
    }

    private func dayTitle(for day: ResolvedDailyForecast) -> String {
        WeatherDateFormatting.longDayMonth(
            day.date,
            timeZone: model.weatherState?.snapshot.timeZone ?? .current
        )
    }

    private func summaryCard(day: ResolvedDailyForecast, state: WeatherScreenState, hours: [HourlyForecastEntry]) -> some View {
        let totalPrecipitation = hours.reduce(0) { $0 + $1.precipitation }
        let descriptor = WeatherConditions.descriptor(for: day.weatherCode, isDay: true)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ÜBERBLICK")
                        .font(DesignTokens.mono(size: 10, weight: .medium))
                        .foregroundStyle(DesignTokens.secondaryText)

                    Text(descriptor.title)
                        .font(DesignTokens.serif(size: 18))
                        .foregroundStyle(DesignTokens.ink)

                    Text("\(Int(day.temperatureMax.rounded()))° / \(Int(day.temperatureMin.rounded()))°")
                        .font(DesignTokens.heroFont(size: 34))
                        .foregroundStyle(DesignTokens.ink)
                }

                Spacer(minLength: 8)

                WeatherIconView(weatherCode: day.weatherCode, isDay: true, size: .medium)
            }

            WeatherSheetSupportingNote(
                systemImage: "cloud.rain",
                text: "Maximal \(Int(day.precipitationProbabilityMax.rounded())) % Regenchance und etwa \(formattedPrecipitation(totalPrecipitation)) über den Tag."
            )
        }
        .vintageCard()
    }

    private func selectedDay(from state: WeatherScreenState) -> ResolvedDailyForecast? {
        state.daily.first(where: { $0.date == selectedDayID }) ?? state.daily.first
    }

}

private struct ForecastTemperatureRangeView: View {
    let min: Double
    let max: Double
    let range: ClosedRange<Double>

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { proxy in
                let total = Swift.max(range.upperBound - range.lowerBound, 1)
                let start = (min - range.lowerBound) / total
                let width = (max - min) / total

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(DesignTokens.trackFill)
                        .frame(height: 12)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [DesignTokens.rain.opacity(0.75), DesignTokens.sun.opacity(0.85)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: proxy.size.width * CGFloat(Swift.max(width, 0.08)),
                            height: 12
                        )
                        .offset(x: proxy.size.width * CGFloat(start))
                }
            }
            .frame(height: 12)

            GeometryReader { proxy in
                let total = Swift.max(range.upperBound - range.lowerBound, 1)
                let startPosition = proxy.size.width * CGFloat((min - range.lowerBound) / total)
                let endPosition = proxy.size.width * CGFloat((max - range.lowerBound) / total)
                let labelWidth: CGFloat = 30

                ZStack(alignment: .topLeading) {
                    Text("\(Int(min.rounded()))°")
                        .font(DesignTokens.mono(size: 10))
                        .foregroundStyle(DesignTokens.secondaryText)
                        .frame(width: labelWidth)
                        .offset(x: clampedPosition(startPosition - labelWidth / 2, totalWidth: proxy.size.width, labelWidth: labelWidth))

                    Text("\(Int(max.rounded()))°")
                        .font(DesignTokens.mono(size: 10, weight: .medium))
                        .foregroundStyle(DesignTokens.ink)
                        .frame(width: labelWidth)
                        .offset(x: clampedPosition(endPosition - labelWidth / 2, totalWidth: proxy.size.width, labelWidth: labelWidth))
                }
            }
            .frame(height: 16)
        }
    }

    private func clampedPosition(_ proposed: CGFloat, totalWidth: CGFloat, labelWidth: CGFloat) -> CGFloat {
        Swift.min(Swift.max(proposed, 0), Swift.max(totalWidth - labelWidth, 0))
    }
}

struct ForecastDayPicker: View {
    let title: String
    let days: [ResolvedDailyForecast]
    let selectedDayID: Date?
    let onSelect: (ResolvedDailyForecast) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(DesignTokens.mono(size: 10, weight: .medium))
                .foregroundStyle(DesignTokens.secondaryText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(days) { day in
                        let isSelected = selectedDayID == day.date

                        Button {
                            HapticManager.selectionChanged()
                            onSelect(day)
                        } label: {
                            Text(day.displayLabel)
                                .font(DesignTokens.mono(size: 10, weight: .medium))
                                .foregroundStyle(isSelected ? DesignTokens.background : DesignTokens.ink)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(isSelected ? DesignTokens.ink : DesignTokens.chromeFill)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(isSelected ? DesignTokens.ink : DesignTokens.border, lineWidth: 0.8)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

struct WeatherSheetHeader<Accessory: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    @ViewBuilder let accessory: Accessory

    init(
        eyebrow: String,
        title: String,
        subtitle: String,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(eyebrow)
                    .font(DesignTokens.mono(size: 10, weight: .medium))
                    .foregroundStyle(DesignTokens.secondaryText)

                Text(title)
                    .font(DesignTokens.serif(size: 30, weight: .bold))
                    .foregroundStyle(DesignTokens.ink)

                Text(subtitle)
                    .font(DesignTokens.mono(size: 11))
                    .foregroundStyle(DesignTokens.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            accessory
        }
    }
}

extension WeatherSheetHeader where Accessory == EmptyView {
    init(eyebrow: String, title: String, subtitle: String) {
        self.init(eyebrow: eyebrow, title: title, subtitle: subtitle) {
            EmptyView()
        }
    }
}

struct WeatherSheetMetricBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text(title)
                .font(DesignTokens.mono(size: 9, weight: .medium))
                .foregroundStyle(DesignTokens.secondaryText)

            Text(value)
                .font(DesignTokens.serif(size: 28))
                .foregroundStyle(DesignTokens.ink)
        }
        .frame(minWidth: 68, alignment: .trailing)
    }
}

struct WeatherSheetSupportingNote: View {
    let systemImage: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DesignTokens.secondaryText)
                .frame(width: 14, alignment: .center)

            Text(text)
                .font(DesignTokens.mono(size: 11))
                .foregroundStyle(DesignTokens.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private func hourlyTemperatureChartEntries(from state: WeatherScreenState, now: Date) -> [HourlyChartCard.Entry] {
    let entries = Array(state.hourly.prefix(18))
    let timeZone = state.snapshot.timeZone

    return Array(entries.enumerated()).map { index, hour in
        HourlyChartCard.Entry(
            id: hour.timestamp,
            displayLabel: hourLabel(for: hour.timestamp, relativeTo: now, timeZone: timeZone),
            value: hour.temperature,
            formattedValue: "\(Int(hour.temperature.rounded()))°",
            isCurrent: hour.isCurrentHour,
            isPast: hour.isPast,
            dayDividerLabel: dayDividerLabel(before: index, dates: entries.map(\.timestamp), timeZone: timeZone, now: now)
        )
    }
}

private func hourlyPrecipitationChartEntries(from state: WeatherScreenState, now: Date) -> [HourlyChartCard.Entry] {
    let entries = Array(state.hourly.prefix(18))
    let timeZone = state.snapshot.timeZone

    return Array(entries.enumerated()).map { index, hour in
        let precipitationAmount = max(0, hour.precipitation)

        return HourlyChartCard.Entry(
            id: hour.timestamp,
            displayLabel: hourLabel(for: hour.timestamp, relativeTo: now, timeZone: timeZone),
            value: precipitationAmount,
            formattedValue: formattedPrecipitation(precipitationAmount),
            secondaryFormattedValue: formattedPrecipitationProbability(hour.precipitationProbability),
            isCurrent: hour.isCurrentHour,
            isPast: hour.isPast,
            isRangeHighlighted: precipitationAmount > 0 || hour.precipitationProbability >= 25,
            dayDividerLabel: dayDividerLabel(before: index, dates: entries.map(\.timestamp), timeZone: timeZone, now: now)
        )
    }
}

private func temperatureEntries(for day: ResolvedDailyForecast, in state: WeatherScreenState, now: Date) -> [HourlyChartCard.Entry] {
    let hours = dayTimelineHours(for: day, in: state)
    let timeZone = state.snapshot.timeZone

    return Array(hours.enumerated()).map { index, hour in
        let temperature = hour.entry?.temperature ?? fallbackTemperature(for: hour.hour, day: day, in: state)

        return HourlyChartCard.Entry(
            id: hour.timestamp,
            displayLabel: dayChartHourLabel(for: hour, relativeTo: now, timeZone: timeZone),
            value: temperature,
            formattedValue: "\(Int(temperature.rounded()))°",
            isCurrent: Calendar.weatherCalendar(timeZone: timeZone).isDate(hour.timestamp, equalTo: now, toGranularity: .hour),
            isPast: hour.timestamp < now,
            dayDividerLabel: nil
        )
    }
}

private func precipitationEntries(for day: ResolvedDailyForecast, in state: WeatherScreenState, now: Date) -> [HourlyChartCard.Entry] {
    let hours = dayTimelineHours(for: day, in: state)
    let timeZone = state.snapshot.timeZone

    let wetHours = hours.map { max(0, $0.entry?.precipitation ?? 0) }
    let peakPrecipitation = wetHours.max() ?? 0

    return Array(hours.enumerated()).map { _, hour in
        let precipitationProbability = hour.entry?.precipitationProbability ?? 0
        let precipitationAmount = max(0, hour.entry?.precipitation ?? 0)

        return HourlyChartCard.Entry(
            id: hour.timestamp,
            displayLabel: dayChartHourLabel(for: hour, relativeTo: now, timeZone: timeZone),
            value: precipitationAmount,
            formattedValue: formattedPrecipitation(precipitationAmount),
            secondaryFormattedValue: formattedPrecipitationProbability(precipitationProbability),
            isCurrent: Calendar.weatherCalendar(timeZone: timeZone).isDate(hour.timestamp, equalTo: now, toGranularity: .hour),
            isPast: hour.timestamp < now,
            isRangeHighlighted: precipitationAmount > 0 || precipitationProbability >= 25,
            isPeak: peakPrecipitation > 0 && abs(peakPrecipitation - precipitationAmount) < 0.01,
            dayDividerLabel: nil
        )
    }
}

private func uvEntries(for day: ResolvedDailyForecast, in state: WeatherScreenState, now: Date) -> [HourlyChartCard.Entry] {
    let hours = dayTimelineHours(for: day, in: state)
    let timeZone = state.snapshot.timeZone
    let activeTimestamps = Set(
        hours.compactMap { hour -> Date? in
            guard (hour.entry?.uvIndex ?? 0) >= 1 else { return nil }
            return hour.timestamp
        }
    )
    let peakTimestamp = hours
        .compactMap { hour -> (Date, Double)? in
            guard let uvIndex = hour.entry?.uvIndex else { return nil }
            return (hour.timestamp, uvIndex)
        }
        .max(by: { $0.1 < $1.1 })?
        .0

    return hours.map { hour in
        let uvIndex = hour.entry?.uvIndex ?? 0

        return HourlyChartCard.Entry(
            id: hour.timestamp,
            displayLabel: dayChartHourLabel(for: hour, relativeTo: now, timeZone: timeZone),
            value: uvIndex,
            formattedValue: formattedUVIndex(uvIndex),
            isCurrent: Calendar.weatherCalendar(timeZone: timeZone).isDate(hour.timestamp, equalTo: now, toGranularity: .hour),
            isPast: hour.timestamp < now,
            isRangeHighlighted: activeTimestamps.contains(hour.timestamp),
            isPeak: peakTimestamp == hour.timestamp,
            dayDividerLabel: nil
        )
    }
}

private struct DayTimelineHour {
    let hour: Int
    let timestamp: Date
    let entry: HourlyForecastEntry?
}

private func dayTimelineHours(for day: ResolvedDailyForecast, in state: WeatherScreenState) -> [DayTimelineHour] {
    let calendar = Calendar.weatherCalendar(timeZone: state.snapshot.timeZone)
    let startOfDay = calendar.startOfDay(for: day.date)
    let nextMidnight = calendar.date(byAdding: .day, value: 1, to: startOfDay)
    let entriesByHour = Dictionary(
        uniqueKeysWithValues: state.snapshot.hourly.map { hour in
            (calendar.dateInterval(of: .hour, for: hour.timestamp)?.start ?? hour.timestamp, hour)
        }
    )

    return (0...24).compactMap { hour in
        guard let timestamp = calendar.date(byAdding: .hour, value: hour, to: startOfDay) else { return nil }
        let entry = entriesByHour[timestamp]

        if hour < 24 {
            return DayTimelineHour(hour: hour, timestamp: timestamp, entry: entry)
        }

        return DayTimelineHour(hour: 24, timestamp: nextMidnight ?? timestamp, entry: entry)
    }
}

private func dayChartHourLabel(for hour: DayTimelineHour, relativeTo now: Date, timeZone: TimeZone) -> String {
    if hour.hour == 24 {
        return "24"
    }

    return hourLabel(for: hour.timestamp, relativeTo: now, timeZone: timeZone)
}

private func fallbackTemperature(for hour: Int, day: ResolvedDailyForecast, in state: WeatherScreenState) -> Double {
    let hours = hourlyEntries(for: day, in: state)
    if hour == 24 {
        return hours.last?.temperature ?? day.temperatureMin
    }

    return hours.first(where: {
        Calendar.weatherCalendar(timeZone: state.snapshot.timeZone).component(.hour, from: $0.timestamp) == hour
    })?.temperature ?? day.temperatureMin
}

private func hourlyEntries(for day: ResolvedDailyForecast, in state: WeatherScreenState) -> [HourlyForecastEntry] {
    let calendar = Calendar.weatherCalendar(timeZone: state.snapshot.timeZone)

    return state.snapshot.hourly
        .sorted { $0.timestamp < $1.timestamp }
        .filter { calendar.isDate($0.timestamp, inSameDayAs: day.date) }
}

private func hourLabel(for date: Date, relativeTo now: Date, timeZone: TimeZone) -> String {
    WeatherDateFormatting.hourLabel(for: date, relativeTo: now, timeZone: timeZone)
}

private func dayDividerLabel(before index: Int, dates: [Date], timeZone: TimeZone, now: Date) -> String? {
    guard index > 0, dates.indices.contains(index), dates.indices.contains(index - 1) else { return nil }

    let calendar = Calendar.weatherCalendar(timeZone: timeZone)
    let currentDate = dates[index]
    let previousDate = dates[index - 1]

    guard !calendar.isDate(currentDate, inSameDayAs: previousDate) else { return nil }

    if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
       calendar.isDate(currentDate, inSameDayAs: tomorrow) {
        return "Morgen"
    }

    return WeatherDateFormatting.shortWeekday(currentDate, timeZone: timeZone)
}

private func formattedPrecipitation(_ value: Double) -> String {
    if value >= 10 || abs(value.rounded() - value) < 0.05 {
        return "\(Int(value.rounded())) mm"
    }

    let formatted = String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",")
    return "\(formatted) mm"
}

private func formattedPrecipitationProbability(_ value: Double) -> String {
    "\(Int(value.rounded())) % Chance"
}

private func formattedUVIndex(_ value: Double) -> String {
    if abs(value.rounded() - value) < 0.05 {
        return "\(Int(value.rounded()))"
    }

    return String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",")
}
