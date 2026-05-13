import SwiftUI

struct WeekView: View {
    @Bindable var model: AppModel
    @Environment(\.weatherPaperPalette) private var palette
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
                        dailyContent(state)
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
                .weatherSheetChrome(palette)
                .presentationDetents([.fraction(0.75)])
                .presentationDragIndicator(.hidden)
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
            label: "Zukunft",
            headline: "Nächste Tage.",
            contextTitle: model.weatherState?.place.name ?? "Ort",
            summary: ""
        )
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

            TemperatureRangeTrack(
                min: day.temperatureMin,
                max: day.temperatureMax,
                range: range,
                trackHeight: 12,
                labelSpacing: 6,
                labelWidth: 30,
                labelFontSize: 10,
                minimumVisibleFraction: 0.08,
                valueFormatter: { model.formattedTemperature($0) }
            )
            .frame(maxWidth: .infinity)
            .padding(.top, 4)

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(Int(day.precipitationProbabilityMax.rounded())) %")
                    .font(DesignTokens.serif(size: 18))
                    .foregroundStyle(DesignTokens.rain)

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
                    if let state = model.weatherState,
                       let day = selectedDay(from: state) {
                        let comparisonDays = Array(state.daily.prefix(7))
                        let dayHours = hourlyEntries(for: day, in: state)
                        let totalPrecipitation = dayHours.reduce(0) { $0 + max(0, $1.precipitation) }
                        let expectation = PrecipitationExpectation.day(
                            from: dayHours,
                            fallbackAmount: totalPrecipitation,
                            fallbackProbability: day.precipitationProbabilityMax
                        )
                        let precipitationAmountDomain = PrecipitationLineChartCard.amountDomain(
                            for: comparisonDays.map { precipitationLineEntries(for: $0, in: state, now: model.clock.now) }
                        )

                        header(
                            headline: precipitationHeadline(for: expectation),
                            summary: precipitationSummary(for: day, expectation: expectation),
                            metricDetail: "\(model.formattedPrecipitation(expectation.expectedAmount)) \(Int(expectation.probability.rounded())) %"
                        )

                        ForecastDayPicker(
                            days: comparisonDays,
                            selectedDayID: selectedDayID,
                            accent: DesignTokens.rain
                        ) { day in
                            selectedDayID = day.date
                        }

                        PrecipitationExpectationSummaryCard(
                            expectedValue: model.formattedPrecipitation(expectation.expectedAmount),
                            amountValue: model.formattedPrecipitation(expectation.sourceAmount),
                            probabilityValue: "\(Int(expectation.probability.rounded())) %",
                            detail: precipitationShapeText(for: expectation),
                            peakText: peakExpectedHourNote(
                                for: expectation,
                                referenceDate: model.clock.now,
                                timeZone: state.snapshot.timeZone
                            ),
                            accent: DesignTokens.rain
                        )

                        PrecipitationLineChartCard(
                            entries: precipitationLineEntries(for: day, in: state, now: model.clock.now),
                            titleOverride: "Menge & Chance",
                            descriptionText: "Erwartung aus Menge und Chance; Linien zeigen Rohmenge und Wahrscheinlichkeit.",
                            layoutStyle: .compact,
                            amountDomain: precipitationAmountDomain,
                            amountUnitLabel: model.precipitationAxisLabel,
                            amountValueFormatter: model.formattedPrecipitation
                        )
                        .vintageCard()
                    } else {
                        header(
                            headline: "Kein Regen.",
                            summary: "Noch keine Niederschlagsdaten für einen Tagesverlauf verfügbar.",
                            metricDetail: nil
                        )

                        Text("Noch keine Niederschlagsdaten.")
                            .font(DesignTokens.mono(size: 11))
                            .foregroundStyle(DesignTokens.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .vintageCard()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 28)
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

    @ViewBuilder
    private func header(headline: String, summary: String, metricDetail: String?) -> some View {
        if let metricDetail, !metricDetail.isEmpty {
            WeatherNarrativeSheetHeader(
                label: "Niederschlag",
                headline: headline,
                summary: summary,
                accent: DesignTokens.rain,
                headlineTrailing: {
                    WeatherSheetHeadlineValue(value: metricDetail, accent: DesignTokens.rain)
                }
            )
        } else {
            WeatherNarrativeSheetHeader(
                label: "Niederschlag",
                headline: headline,
                summary: summary,
                accent: DesignTokens.rain
            )
        }
    }

    private func selectedDay(from state: WeatherScreenState) -> ResolvedDailyForecast? {
        state.daily.first(where: { $0.date == selectedDayID }) ?? state.daily.first
    }

    private func precipitationSummary(for day: ResolvedDailyForecast, expectation: PrecipitationExpectation) -> String {
        let expected = model.formattedPrecipitation(expectation.expectedAmount)
        let amount = model.formattedPrecipitation(expectation.sourceAmount)
        let probability = Int(expectation.probability.rounded())

        if expectation.category == .trace {
            return "Menge und Chance ergeben nur etwa \(expected). Die Rohmenge liegt bei \(amount), die höchste Chance bei \(probability) %."
        }

        if expectation.hasHighChanceLowAmountShape {
            return "Regen ist wahrscheinlich, aber die Menge bleibt klein. Erwartet werden etwa \(expected) aus \(amount) bei \(probability) %."
        }

        if expectation.hasLowChanceHighAmountShape {
            return "Die Menge kann auffallen, trifft aber nicht sicher ein. Der Erwartungswert liegt bei etwa \(expected)."
        }

        return "\(day.displayLabel) kommt kombiniert auf etwa \(expected). Die Rohmenge liegt bei \(amount), die höchste Chance bei \(probability) %."
    }

    private func precipitationHeadline(for expectation: PrecipitationExpectation) -> String {
        if expectation.hasHighChanceLowAmountShape {
            return "Eher Niesel."
        }

        if expectation.hasLowChanceHighAmountShape {
            return "Schauer möglich."
        }

        switch expectation.category {
        case .trace:
            return "Kaum Regen."
        case .light:
            return "Leichter Regen."
        case .wet:
            return "Nass einplanen."
        case .strong:
            return "Kräftiger Regen."
        }
    }

    private func precipitationShapeText(for expectation: PrecipitationExpectation) -> String {
        if expectation.hasHighChanceLowAmountShape {
            return "Hohe Wahrscheinlichkeit mit niedriger Menge liest sich eher wie Niesel oder feiner Regen."
        }

        if expectation.hasLowChanceHighAmountShape {
            return "Niedrigere Wahrscheinlichkeit mit höherer Menge passt eher zu einem kurzen, kräftigen Schauer."
        }

        switch expectation.category {
        case .trace:
            return "Unter 0,5 mm Erwartungswert bleibt der Tag meist kaum spürbar nass."
        case .light:
            return "Zwischen 0,5 und 2 mm Erwartungswert ist leichter Regen realistisch."
        case .wet:
            return "Über 2 mm Erwartungswert wird es draußen wahrscheinlich nass."
        case .strong:
            return "Über 5 mm Erwartungswert spricht die Kombination klar für kräftigeren Regen."
        }
    }

    private func peakExpectedHourNote(
        for expectation: PrecipitationExpectation,
        referenceDate: Date,
        timeZone: TimeZone
    ) -> String? {
        guard let peakHour = expectation.peakHour else {
            return nil
        }

        let peakExpected = PrecipitationExpectation.weightedAmount(
            precipitation: peakHour.precipitation,
            probability: peakHour.precipitationProbability
        )

        return "Stärkste erwartete Phase um \(hourLabel(for: peakHour.timestamp, relativeTo: referenceDate, timeZone: timeZone)): \(model.formattedPrecipitation(peakExpected)) bei \(Int(peakHour.precipitationProbability.rounded())) %."
    }
}

private struct PrecipitationExpectationSummaryCard: View {
    let expectedValue: String
    let amountValue: String
    let probabilityValue: String
    let detail: String
    let peakText: String?
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("ERWARTETER REGEN")
                    .font(DesignTokens.mono(size: 10, weight: .medium))
                    .foregroundStyle(accent)

                Spacer(minLength: 8)

                Text("mm × %")
                    .font(DesignTokens.mono(size: 9, weight: .medium))
                    .foregroundStyle(DesignTokens.secondaryText)
            }

            Text(detail)
                .font(DesignTokens.mono(size: 11))
                .foregroundStyle(DesignTokens.tertiaryText)
                .lineSpacing(1.4)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 0) {
                metricColumn(title: "Erwartet", value: expectedValue, tint: accent)
                divider
                metricColumn(title: "Menge", value: amountValue, tint: DesignTokens.ink)
                divider
                metricColumn(title: "Chance", value: probabilityValue, tint: DesignTokens.drizzle)
            }

            if let peakText {
                Rectangle()
                    .fill(DesignTokens.border.opacity(0.74))
                    .frame(height: 0.8)

                WeatherSheetSupportingNote(
                    systemImage: "clock",
                    text: peakText
                )
            }
        }
        .vintageCard()
    }

    private var divider: some View {
        Rectangle()
            .fill(DesignTokens.border.opacity(0.72))
            .frame(width: 0.8, height: 38)
    }

    private func metricColumn(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(DesignTokens.mono(size: 8, weight: .medium))
                .foregroundStyle(DesignTokens.secondaryText)

            Text(value)
                .font(DesignTokens.serif(size: 19, weight: .bold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
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
                    if let state = model.weatherState,
                       let day = selectedDay(from: state) {
                        let hours = hourlyEntries(for: day, in: state)
                        let hourlyMax = hours.compactMap(\.uvIndex).max()
                        let maxUV = day.uvIndexMax ?? hourlyMax
                        let chartEntries = uvEntries(for: day, in: state, now: model.clock.now)
                        let comparisonDays = Array(state.daily.prefix(7))
                        let uvDomain = HourlyChartCard.valueDomain(
                            for: comparisonDays.map { uvEntries(for: $0, in: state, now: model.clock.now) }
                        )

                        header(
                            headline: uvHeadline(for: maxUV),
                            summary: uvSummary(for: maxUV),
                            metricValue: maxUV.map(formattedUVIndex) ?? "—"
                        )

                        ForecastDayPicker(
                            days: comparisonDays,
                            selectedDayID: selectedDayID,
                            accent: DesignTokens.uv
                        ) { day in
                            selectedDayID = day.date
                        }
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
                                layoutStyle: .compact,
                                valueDomain: uvDomain
                            )
                            .vintageCard()
                        }
                    } else {
                        header(
                            headline: "UV noch offen.",
                            summary: "Noch keine UV-Daten für eine verlässliche Tageseinschätzung.",
                            metricValue: nil
                        )

                        Text("Noch keine UV-Daten.")
                            .font(DesignTokens.mono(size: 11))
                            .foregroundStyle(DesignTokens.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .vintageCard()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 28)
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

    @ViewBuilder
    private func header(headline: String, summary: String, metricValue: String?) -> some View {
        if let metricValue, !metricValue.isEmpty {
            WeatherNarrativeSheetHeader(
                label: "UV",
                headline: headline,
                summary: summary,
                accent: DesignTokens.uv,
                headlineTrailing: {
                    WeatherSheetHeadlineValue(value: metricValue, accent: DesignTokens.uv)
                },
                accessory: {
                    closeButtonAccessory
                }
            )
        } else {
            WeatherNarrativeSheetHeader(
                label: "UV",
                headline: headline,
                summary: summary,
                accent: DesignTokens.uv,
                accessory: {
                    closeButtonAccessory
                }
            )
        }
    }

    private func selectedDay(from state: WeatherScreenState) -> ResolvedDailyForecast? {
        state.daily.first(where: { $0.date == selectedDayID }) ?? state.daily.first
    }

    @ViewBuilder
    private var closeButtonAccessory: some View {
        if showsCloseButton {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DesignTokens.ink)
                    .padding(12)
                    .background(DesignTokens.chromeFill)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(DesignTokens.border, lineWidth: 0.8)
                    )
            }
            .buttonStyle(.plain)
        }
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

    private func uvHeadline(for maxUV: Double?) -> String {
        guard let maxUV else { return "UV noch offen." }

        switch maxUV {
        case ..<3:
            return "Milde Sonne."
        case ..<6:
            return "Mässige Last."
        case ..<8:
            return "Starke Mitte."
        case ..<11:
            return "Hohe Last."
        default:
            return "Scharfe Sonne."
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

    private func maxUVDetailText(for maxUV: Double?) -> String {
        guard let maxUV else { return "Maximaler Index noch offen" }
        return "Tagesmaximum \(formattedUVIndex(maxUV))"
    }

}

struct DayForecastDetailSheet: View {
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
                            let comparisonDays = Array(state.daily.prefix(10))
                            let temperatureDomain = HourlyChartCard.valueDomain(
                                for: comparisonDays.map { temperatureEntries(for: $0, in: state, now: model.clock.now) }
                            )
                            let precipitationAmountDomain = HourlyChartCard.valueDomain(
                                for: comparisonDays.map { precipitationAmountEntries(for: $0, in: state, now: model.clock.now) }
                            )

                            header(for: selectedDay)

                            ForecastDayPicker(
                                days: comparisonDays,
                                selectedDayID: selectedDayID
                            ) { day in
                                selectedDayID = day.date
                            }

                            HourlyChartCard(
                                entries: temperatureEntries(
                                    for: selectedDay,
                                    in: state,
                                    now: model.clock.now,
                                    temperatureFormatter: { model.formattedTemperature($0) }
                                ),
                                metric: .temperature,
                                titleOverride: "Temperatur",
                                accentCurrentEntry: true,
                                layoutStyle: .compact,
                                valueDomain: temperatureDomain,
                                axisLabelOverride: model.temperatureAxisLabel,
                                axisValueFormatter: { model.formattedTemperature($0) }
                            )
                            .vintageCard()

                            HourlyChartCard(
                                entries: precipitationAmountEntries(
                                    for: selectedDay,
                                    in: state,
                                    now: model.clock.now,
                                    precipitationFormatter: model.formattedPrecipitation
                                ),
                                metric: .precipitationAmount,
                                titleOverride: "Niederschlag",
                                descriptionText: "\(model.precipitationAxisLabel) je Stunde",
                                accentCurrentEntry: true,
                                layoutStyle: .compact,
                                valueDomain: precipitationAmountDomain,
                                axisLabelOverride: model.precipitationAxisLabel,
                                axisValueFormatter: { value in
                                    model.formattedPrecipitation(value)
                                        .replacingOccurrences(of: " mm", with: "")
                                        .replacingOccurrences(of: " in", with: "")
                                }
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
            label: "Tag",
            headline: dayTitle(for: day),
            contextTitle: model.weatherState?.place.name ?? "Ort",
            summary: ""
        )
    }

    private func dayTitle(for day: ResolvedDailyForecast) -> String {
        WeatherDateFormatting.longDayMonth(
            day.date,
            timeZone: model.weatherState?.snapshot.timeZone ?? .current
        )
    }

    private func selectedDay(from state: WeatherScreenState) -> ResolvedDailyForecast? {
        state.daily.first(where: { $0.date == selectedDayID }) ?? state.daily.first
    }

}

struct ForecastDayPicker: View {
    let days: [ResolvedDailyForecast]
    let selectedDayID: Date?
    var accent: Color = DesignTokens.sun
    let onSelect: (ResolvedDailyForecast) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                                .foregroundStyle(isSelected ? DesignTokens.ink : DesignTokens.secondaryText)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(isSelected ? accent.opacity(0.16) : DesignTokens.chromeFill)
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .stroke(isSelected ? accent.opacity(0.82) : DesignTokens.border, lineWidth: 0.8)
                                )
                        }
                        .buttonStyle(.plain)
                        .contentShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                }
                .padding(.horizontal, 1)
                .padding(.vertical, 2)
            }
            .contentShape(Rectangle())
            .zIndex(1)
        }
    }
}

struct WeatherNarrativeSheetHeader: View {
    let label: String
    let headline: String
    let summary: String
    var accent: Color = DesignTokens.sun
    let headlineTrailing: AnyView?
    let accessory: AnyView?

    init(title: String, summary: String) {
        self.label = title
        self.headline = title
        self.summary = summary
        self.accent = DesignTokens.sun
        self.headlineTrailing = nil
        self.accessory = nil
    }

    init(label: String, headline: String, summary: String, accent: Color = DesignTokens.sun) {
        self.label = label
        self.headline = headline
        self.summary = summary
        self.accent = accent
        self.headlineTrailing = nil
        self.accessory = nil
    }

    init<HeadlineTrailing: View>(
        label: String,
        headline: String,
        summary: String,
        accent: Color = DesignTokens.sun,
        @ViewBuilder headlineTrailing: () -> HeadlineTrailing
    ) {
        self.label = label
        self.headline = headline
        self.summary = summary
        self.accent = accent
        self.headlineTrailing = AnyView(headlineTrailing())
        self.accessory = nil
    }

    init<Accessory: View>(
        title: String,
        summary: String,
        accent: Color = DesignTokens.sun,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.label = title
        self.headline = title
        self.summary = summary
        self.accent = accent
        self.headlineTrailing = nil
        self.accessory = AnyView(accessory())
    }

    init<Accessory: View>(
        label: String,
        headline: String,
        summary: String,
        accent: Color = DesignTokens.sun,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.label = label
        self.headline = headline
        self.summary = summary
        self.accent = accent
        self.headlineTrailing = nil
        self.accessory = AnyView(accessory())
    }

    init<HeadlineTrailing: View, Accessory: View>(
        label: String,
        headline: String,
        summary: String,
        accent: Color = DesignTokens.sun,
        @ViewBuilder headlineTrailing: () -> HeadlineTrailing,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.label = label
        self.headline = headline
        self.summary = summary
        self.accent = accent
        self.headlineTrailing = AnyView(headlineTrailing())
        self.accessory = AnyView(accessory())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Spacer(minLength: 0)
                Rectangle()
                    .fill(accent.opacity(0.82))
                    .frame(width: 34, height: 1.3)
                Spacer(minLength: 0)
            }
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(label.uppercased())
                        .font(DesignTokens.mono(size: 10, weight: .medium))
                        .foregroundStyle(accent)
                        .tracking(2.2)

                    HStack(alignment: .top, spacing: 16) {
                        Text(headline)
                            .font(DesignTokens.serifItalic(size: 32, weight: .bold))
                            .foregroundStyle(DesignTokens.ink)
                            .lineSpacing(-2)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if let headlineTrailing {
                            headlineTrailing
                        }
                    }

                    if !summary.isEmpty {
                        Text(summary)
                            .font(DesignTokens.mono(size: 11))
                            .foregroundStyle(DesignTokens.tertiaryText)
                            .lineSpacing(1.5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)

                if let accessory {
                    accessory
                }
            }
        }
    }
}

struct WeatherSheetHeader: View {
    let label: String
    let headline: String
    let contextTitle: String?
    let summary: String
    var accent: Color = DesignTokens.sun
    let accessory: AnyView?

    init(title: String, contextTitle: String? = nil, subtitle: String) {
        self.label = title
        self.headline = title
        self.contextTitle = contextTitle
        self.summary = subtitle
        self.accent = DesignTokens.sun
        self.accessory = nil
    }

    init(label: String, headline: String, contextTitle: String? = nil, summary: String, accent: Color = DesignTokens.sun) {
        self.label = label
        self.headline = headline
        self.contextTitle = contextTitle
        self.summary = summary
        self.accent = accent
        self.accessory = nil
    }

    init<Accessory: View>(
        title: String,
        contextTitle: String? = nil,
        subtitle: String,
        accent: Color = DesignTokens.sun,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.label = title
        self.headline = title
        self.contextTitle = contextTitle
        self.summary = subtitle
        self.accent = accent
        self.accessory = AnyView(accessory())
    }

    init<Accessory: View>(
        label: String,
        headline: String,
        contextTitle: String? = nil,
        summary: String,
        accent: Color = DesignTokens.sun,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.label = label
        self.headline = headline
        self.contextTitle = contextTitle
        self.summary = summary
        self.accent = accent
        self.accessory = AnyView(accessory())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Spacer(minLength: 0)
                Rectangle()
                    .fill(accent.opacity(0.82))
                    .frame(width: 34, height: 1.3)
                Spacer(minLength: 0)
            }
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 9) {
                    Text(label.uppercased())
                        .font(DesignTokens.mono(size: 10, weight: .medium))
                        .foregroundStyle(accent)
                        .tracking(2.2)

                    Text(headline)
                        .font(DesignTokens.serifItalic(size: 32, weight: .bold))
                        .foregroundStyle(DesignTokens.ink)
                        .lineSpacing(-2)
                        .fixedSize(horizontal: false, vertical: true)

                    if let contextTitle, !contextTitle.isEmpty {
                        Text(contextTitle.uppercased())
                            .font(DesignTokens.mono(size: 10, weight: .medium))
                            .foregroundStyle(DesignTokens.secondaryText)
                            .tracking(1.6)
                    }

                    if !summary.isEmpty {
                        Text(summary)
                            .font(DesignTokens.mono(size: 11))
                            .foregroundStyle(DesignTokens.tertiaryText)
                            .lineSpacing(1.5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)

                if let accessory {
                    accessory
                }
            }
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

struct WeatherSheetHeadlineValue: View {
    let value: String
    var accent: Color = DesignTokens.ink

    var body: some View {
        Text(value)
            .font(DesignTokens.serif(size: 28, weight: .bold))
            .foregroundStyle(accent)
            .multilineTextAlignment(.trailing)
            .lineLimit(2)
            .minimumScaleFactor(0.72)
            .frame(maxWidth: 140, alignment: .trailing)
    }
}

struct WeatherSheetHeadlineDetail: View {
    let text: String

    var body: some View {
        Text(text)
            .font(DesignTokens.mono(size: 10, weight: .medium))
            .foregroundStyle(DesignTokens.secondaryText)
            .multilineTextAlignment(.trailing)
            .lineSpacing(1.3)
            .frame(maxWidth: 172, alignment: .trailing)
            .fixedSize(horizontal: false, vertical: true)
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

struct EditorialMetricSummaryCard: View {
    let label: String
    let value: String
    let detail: String
    let footnote: String?
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Spacer(minLength: 0)
                Rectangle()
                    .fill(accent.opacity(0.76))
                    .frame(width: 34, height: 1.2)
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(label.uppercased())
                    .font(DesignTokens.mono(size: 10, weight: .medium))
                    .foregroundStyle(DesignTokens.sun)
                    .tracking(2.0)

                Text(value)
                    .font(value.contains("\n") ? DesignTokens.serifItalic(size: 38, weight: .bold) : DesignTokens.serif(size: 42, weight: .bold))
                    .foregroundStyle(DesignTokens.ink)
                    .lineLimit(value.contains("\n") ? 2 : 1)
                    .minimumScaleFactor(0.7)

                Text(detail)
                    .font(DesignTokens.mono(size: 11))
                    .foregroundStyle(DesignTokens.tertiaryText)
                    .lineSpacing(1.5)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let footnote, !footnote.isEmpty {
                Rectangle()
                    .fill(DesignTokens.border.opacity(0.74))
                    .frame(height: 0.8)

                Text(footnote)
                    .font(DesignTokens.mono(size: 10))
                    .foregroundStyle(DesignTokens.secondaryText)
                    .lineSpacing(1.2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .vintageCard()
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

private func temperatureEntries(
    for day: ResolvedDailyForecast,
    in state: WeatherScreenState,
    now: Date,
    temperatureFormatter: ((Double) -> String)? = nil
) -> [HourlyChartCard.Entry] {
    let hours = dayTimelineHours(for: day, in: state)
    let timeZone = state.snapshot.timeZone

    return Array(hours.enumerated()).map { index, hour in
        let temperature = hour.entry?.temperature ?? fallbackTemperature(for: hour.hour, day: day, in: state)

        return HourlyChartCard.Entry(
            id: hour.timestamp,
            displayLabel: dayChartHourLabel(for: hour, relativeTo: now, timeZone: timeZone),
            value: temperature,
            formattedValue: temperatureFormatter?(temperature) ?? "\(Int(temperature.rounded()))°",
            isCurrent: Calendar.weatherCalendar(timeZone: timeZone).isDate(hour.timestamp, equalTo: now, toGranularity: .hour),
            isPast: hour.timestamp < now,
            dayDividerLabel: nil
        )
    }
}

private func precipitationLineEntries(for day: ResolvedDailyForecast, in state: WeatherScreenState, now: Date) -> [PrecipitationLineChartCard.Entry] {
    let hours = dayTimelineHours(for: day, in: state)
    let timeZone = state.snapshot.timeZone

    return Array(hours.enumerated()).map { _, hour in
        let precipitationProbability = hour.entry?.precipitationProbability ?? 0
        let precipitationAmount = max(0, hour.entry?.precipitation ?? 0)

        return PrecipitationLineChartCard.Entry(
            id: hour.timestamp,
            displayLabel: dayChartHourLabel(for: hour, relativeTo: now, timeZone: timeZone),
            precipitationAmount: precipitationAmount,
            precipitationProbability: precipitationProbability,
            isCurrent: Calendar.weatherCalendar(timeZone: timeZone).isDate(hour.timestamp, equalTo: now, toGranularity: .hour),
            isPast: hour.timestamp < now
        )
    }
}

private func precipitationAmountEntries(
    for day: ResolvedDailyForecast,
    in state: WeatherScreenState,
    now: Date,
    precipitationFormatter: ((Double) -> String)? = nil
) -> [HourlyChartCard.Entry] {
    let hours = dayTimelineHours(for: day, in: state)
    let timeZone = state.snapshot.timeZone

    return hours.map { hour in
        let precipitationAmount = max(0, hour.entry?.precipitation ?? 0)
        let probability = hour.entry?.precipitationProbability ?? 0

        return HourlyChartCard.Entry(
            id: hour.timestamp,
            displayLabel: dayChartHourLabel(for: hour, relativeTo: now, timeZone: timeZone),
            value: precipitationAmount,
            formattedValue: precipitationFormatter?(precipitationAmount) ?? formattedPrecipitation(precipitationAmount),
            secondaryFormattedValue: "\(Int(probability.rounded())) %",
            isCurrent: Calendar.weatherCalendar(timeZone: timeZone).isDate(hour.timestamp, equalTo: now, toGranularity: .hour),
            isPast: hour.timestamp < now,
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

private func formattedUVIndex(_ value: Double) -> String {
    if abs(value.rounded() - value) < 0.05 {
        return "\(Int(value.rounded()))"
    }

    return String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",")
}
