import SwiftUI

private enum HomeMetricDetail: String, Identifiable {
    case apparentTemperature
    case wind

    var id: String { rawValue }
}

private enum MoonPhaseKind {
    case newMoon
    case waxingCrescent
    case firstQuarter
    case waxingGibbous
    case fullMoon
    case waningGibbous
    case lastQuarter
    case waningCrescent
}

private struct MoonPhaseInfo {
    let kind: MoonPhaseKind
    let title: String
    let detail: String
    let age: Double
    let illuminationFraction: Double
    let isWaxing: Bool
}

private enum MoonPhaseResolver {
    private static let referenceNewMoon = Date(timeIntervalSince1970: 947182440)
    private static let synodicMonth = 29.530588853

    static func info(for date: Date, timeZone: TimeZone) -> MoonPhaseInfo {
        let calendar = Calendar.weatherCalendar(timeZone: timeZone)
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let localNoon = calendar.date(from: DateComponents(
            timeZone: timeZone,
            year: components.year,
            month: components.month,
            day: components.day,
            hour: 12
        )) ?? date

        var age = localNoon.timeIntervalSince(referenceNewMoon) / 86_400
        age.formTruncatingRemainder(dividingBy: synodicMonth)

        if age < 0 {
            age += synodicMonth
        }

        let illuminationFraction = 0.5 * (1 - cos(2 * .pi * age / synodicMonth))
        let isWaxing = age < synodicMonth / 2

        switch age {
        case ..<1.85:
            return MoonPhaseInfo(
                kind: .newMoon,
                title: "Neumond",
                detail: "Der Mond bleibt heute fast ganz dunkel.",
                age: age,
                illuminationFraction: illuminationFraction,
                isWaxing: isWaxing
            )
        case ..<5.54:
            return MoonPhaseInfo(
                kind: .waxingCrescent,
                title: "Zunehmende Sichel",
                detail: "Jede Nacht wird etwas mehr Fläche sichtbar.",
                age: age,
                illuminationFraction: illuminationFraction,
                isWaxing: isWaxing
            )
        case ..<9.23:
            return MoonPhaseInfo(
                kind: .firstQuarter,
                title: "Erstes Viertel",
                detail: "Die helle Hälfte wächst weiter Richtung Vollmond.",
                age: age,
                illuminationFraction: illuminationFraction,
                isWaxing: isWaxing
            )
        case ..<12.92:
            return MoonPhaseInfo(
                kind: .waxingGibbous,
                title: "Zunehmender Mond",
                detail: "Mehr als die Hälfte ist jetzt beleuchtet.",
                age: age,
                illuminationFraction: illuminationFraction,
                isWaxing: isWaxing
            )
        case ..<16.61:
            return MoonPhaseInfo(
                kind: .fullMoon,
                title: "Vollmond",
                detail: "Die Scheibe steht heute fast vollständig im Licht.",
                age: age,
                illuminationFraction: illuminationFraction,
                isWaxing: isWaxing
            )
        case ..<20.30:
            return MoonPhaseInfo(
                kind: .waningGibbous,
                title: "Abnehmender Mond",
                detail: "Die helle Fläche nimmt nun wieder ab.",
                age: age,
                illuminationFraction: illuminationFraction,
                isWaxing: isWaxing
            )
        case ..<23.99:
            return MoonPhaseInfo(
                kind: .lastQuarter,
                title: "Letztes Viertel",
                detail: "Nur die andere Hälfte bleibt noch beleuchtet.",
                age: age,
                illuminationFraction: illuminationFraction,
                isWaxing: isWaxing
            )
        case ..<27.68:
            return MoonPhaseInfo(
                kind: .waningCrescent,
                title: "Abnehmende Sichel",
                detail: "Der Mond zieht sich Richtung Neumond zurück.",
                age: age,
                illuminationFraction: illuminationFraction,
                isWaxing: isWaxing
            )
        default:
            return MoonPhaseInfo(
                kind: .newMoon,
                title: "Neumond",
                detail: "Der Mond bleibt heute fast ganz dunkel.",
                age: age,
                illuminationFraction: illuminationFraction,
                isWaxing: isWaxing
            )
        }
    }
}

struct HomeView: View {
    @Bindable var model: AppModel
    @State private var isFutureSheetPresented = false
    @State private var isPrecipitationSheetPresented = false
    @State private var isUVSheetPresented = false
    @State private var isSunSheetPresented = false
    @State private var isMoonSheetPresented = false
    @State private var selectedMetricDetail: HomeMetricDetail?

    private struct DashboardLayout {
        let stackSpacing: CGFloat
        let rowSpacing: CGFloat
        let contentScale: CGFloat
        let bannerHeight: CGFloat
        let heroHeight: CGFloat
        let upperRowHeight: CGFloat
        let lowerRowHeight: CGFloat
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                pageTopBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 14)
                    .background(alignment: .top) {
                        topBarBackground
                    }

                content(for: proxy)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
        .refreshable {
            await model.refreshSelectedPlace(force: true)
        }
        .sheet(isPresented: $isFutureSheetPresented) {
            WeekView(model: model)
                .presentationDetents([.fraction(0.65)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isPrecipitationSheetPresented) {
            PrecipitationSheet(model: model)
                .presentationDetents([.fraction(0.65)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isUVSheetPresented) {
            UVSheet(model: model)
                .presentationDetents([.fraction(0.65)])
                .presentationContentInteraction(.scrolls)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isSunSheetPresented) {
            SunSheet(model: model)
                .presentationDetents([.fraction(0.65)])
                .presentationContentInteraction(.scrolls)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isMoonSheetPresented) {
            MoonSheet(model: model)
                .presentationDetents([.fraction(0.72)])
                .presentationContentInteraction(.scrolls)
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedMetricDetail) { detail in
            HomeMetricDetailSheet(model: model, detail: detail)
                .presentationDetents([.fraction(0.65)])
                .presentationDragIndicator(.visible)
        }
        .dismissalHaptic(isPresented: isFutureSheetPresented)
        .dismissalHaptic(isPresented: isPrecipitationSheetPresented)
        .dismissalHaptic(isPresented: isUVSheetPresented)
        .dismissalHaptic(isPresented: isSunSheetPresented)
        .dismissalHaptic(isPresented: isMoonSheetPresented)
        .dismissalHaptic(item: selectedMetricDetail)
    }

    @ViewBuilder
    private func content(for proxy: GeometryProxy) -> some View {
        let topPadding: CGFloat = 12
        let bottomPadding = max(10, proxy.safeAreaInsets.bottom + 6)

        if let state = model.weatherState {
            GeometryReader { contentProxy in
                dashboardContent(
                    state,
                    availableHeight: max(contentProxy.size.height - topPadding - bottomPadding, 0)
                )
                .padding(.horizontal, 16)
                .padding(.top, topPadding)
                .padding(.bottom, bottomPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        } else if model.isRefreshing || model.isBootstrapping || model.isWaitingForCurrentLocation {
            loadingCard
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, 16)
                .padding(.top, topPadding)
                .padding(.bottom, bottomPadding)
        } else {
            emptyCard
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, 16)
                .padding(.top, topPadding)
                .padding(.bottom, bottomPadding)
        }
    }

    private var pageTopBar: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Wetterblatt")
                    .font(DesignTokens.mono(size: 10, weight: .medium))
                    .foregroundStyle(DesignTokens.secondaryText)

                HStack(alignment: .center, spacing: 8) {
                    if model.activePlaceSelection == .currentLocation {
                        Image(systemName: "location.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DesignTokens.sun)
                    }

                    Text(displayPlaceName)
                        .font(DesignTokens.serif(size: 27, weight: .bold))
                        .foregroundStyle(DesignTokens.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 8) {
                Text(topBarDateLabel)
                    .font(DesignTokens.mono(size: 10, weight: .medium))
                    .foregroundStyle(DesignTokens.secondaryText)

                Button {
                    HapticManager.lightImpact()
                    isFutureSheetPresented = true
                } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DesignTokens.ink)
                        .frame(width: 40, height: 40)
                        .background(DesignTokens.chromeFill)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(DesignTokens.border, lineWidth: 0.8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var displayPlaceName: String {
        if let resolvedPlaceName = [
            model.activePlaceSelection == .currentLocation ? model.currentLocationPlace?.name : nil,
            model.weatherState?.place.name,
            model.selectedPlace?.name,
            model.weatherState?.snapshot.placeName,
        ]
        .compactMap(normalizedPlaceName)
        .first {
            return resolvedPlaceName
        }

        if model.activePlaceSelection == .currentLocation {
            return "Aktueller Ort"
        }

        return "Ort"
    }

    private var topBarBackground: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay {
                    LinearGradient(
                        colors: [
                            DesignTokens.background.opacity(0.78),
                            DesignTokens.background.opacity(0.34),
                            .clear,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }

            Rectangle()
                .fill(DesignTokens.border.opacity(0.24))
                .frame(height: 0.8)
        }
        .ignoresSafeArea(edges: .top)
    }

    private var topBarDateLabel: String {
        let timeZone = model.weatherState.map(displayTimeZone(for:)) ?? .current
        return WeatherDateFormatting.topBarDate(model.clock.now, timeZone: timeZone)
    }

    private func heroCard(
        _ state: WeatherScreenState,
        contentScale: CGFloat,
        cardHeight: CGFloat
    ) -> some View {
        let recommendations = heroRecommendationLines(for: state)
        let descriptor = WeatherConditions.descriptor(
            for: state.current.weatherCode,
            isDay: state.current.isDay
        )
        let compactHero = contentScale < 0.9 || cardHeight < 196
        let heroSpacing: CGFloat = compactHero ? 10 : 14
        let temperatureRowSpacing: CGFloat = compactHero ? 10 : 14
        let recommendationSpacing: CGFloat = compactHero ? 4 : 6
        let temperatureFontSize: CGFloat = compactHero ? 52 : 60
        let recommendationFontSize: CGFloat = compactHero ? 10 : 11
        let stageWidth: CGFloat = compactHero ? 132 : 160
        let stageHeight: CGFloat = compactHero ? 92 : 118
        let stageTextInset: CGFloat = compactHero ? 62 : 84
        let conditionTint = heroConditionTint(
            weatherCode: state.current.weatherCode,
            isDay: state.current.isDay
        )

        return ZStack(alignment: .topTrailing) {
            HeroWeatherScene(
                weatherCode: state.current.weatherCode,
                isDay: state.current.isDay,
                density: compactHero ? .compact : .regular
            )
            .frame(width: stageWidth, height: stageHeight)
            .offset(x: compactHero ? 6 : 10, y: compactHero ? 4 : 2)
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: heroSpacing) {
                VStack(alignment: .leading, spacing: compactHero ? 8 : 10) {
                    Text("JETZT")
                        .font(DesignTokens.mono(size: compactHero ? 9 : 10, weight: .semibold))
                        .foregroundStyle(DesignTokens.secondaryText)

                    HStack(alignment: .lastTextBaseline, spacing: temperatureRowSpacing) {
                        Text("\(Int(state.current.temperature.rounded()))°")
                            .font(DesignTokens.heroFont(size: temperatureFontSize))
                            .foregroundStyle(DesignTokens.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .padding(.trailing, stageTextInset)

                    Text(descriptor.title.uppercased())
                        .font(DesignTokens.mono(size: compactHero ? 9 : 10, weight: .semibold))
                        .foregroundStyle(conditionTint)
                        .lineLimit(1)
                        .padding(.horizontal, compactHero ? 10 : 12)
                        .padding(.vertical, compactHero ? 6 : 7)
                        .background(
                            Capsule()
                                .fill(DesignTokens.chromeFill.opacity(0.86))
                        )
                        .overlay(
                            Capsule()
                                .stroke(conditionTint.opacity(0.18), lineWidth: 0.8)
                        )
                }

                VStack(alignment: .leading, spacing: recommendationSpacing) {
                    ForEach(recommendations, id: \.self) { line in
                        Text(line)
                            .font(DesignTokens.mono(size: recommendationFontSize))
                            .foregroundStyle(DesignTokens.tertiaryText)
                            .lineSpacing(compactHero ? -1.3 : -1.0)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .vintageCard()
    }

    private func heroConditionTint(weatherCode: Int, isDay: Bool) -> Color {
        switch weatherCode {
        case 0:
            return isDay ? DesignTokens.sun : DesignTokens.moon
        case 1, 2:
            return isDay ? DesignTokens.hazySun : DesignTokens.moon
        case 51...57:
            return DesignTokens.drizzle
        case 61...67, 80...82:
            return DesignTokens.rain
        case 71...77, 85...86:
            return DesignTokens.frost
        case 95...99:
            return DesignTokens.storm
        default:
            return DesignTokens.tertiaryText
        }
    }

    private func dashboardContent(_ state: WeatherScreenState, availableHeight: CGFloat) -> some View {
        let banner = bannerText(for: state)
        let layout = dashboardLayout(
            for: availableHeight,
            hasBanner: banner != nil
        )

        return VStack(alignment: .leading, spacing: layout.stackSpacing) {
            if let banner {
                OfflineBanner(text: banner)
                    .frame(minHeight: layout.bannerHeight, alignment: .topLeading)
            }

            heroCard(
                state,
                contentScale: layout.contentScale,
                cardHeight: layout.heroHeight
            )
                .frame(height: layout.heroHeight, alignment: .top)

            metricsGrid(
                state,
                upperRowHeight: layout.upperRowHeight,
                lowerRowHeight: layout.lowerRowHeight,
                rowSpacing: layout.rowSpacing
            )
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func metricsGrid(
        _ state: WeatherScreenState,
        upperRowHeight: CGFloat,
        lowerRowHeight: CGFloat,
        rowSpacing: CGFloat
    ) -> some View {
        let timeZone = displayTimeZone(for: state)
        let moonPhase = MoonPhaseResolver.info(for: model.clock.now, timeZone: timeZone)
        let compactLowerRow = lowerRowHeight < 104

        return VStack(spacing: rowSpacing) {
            metricRow(
                leading:
                    feelsLikeMetricCard(state, rowHeight: upperRowHeight),
                trailing:
                    precipitationMetricCard(state, rowHeight: upperRowHeight)
            )
            .frame(height: upperRowHeight, alignment: .top)

            metricRow(
                leading:
                    windMetricCard(state, rowHeight: upperRowHeight),
                trailing:
                    uvMetricCard(state, rowHeight: upperRowHeight)
            )
            .frame(height: upperRowHeight, alignment: .top)

            metricRow(
                leading:
                    sunMetricCard(
                        state,
                        timeZone: timeZone,
                        rowHeight: lowerRowHeight,
                        compactLowerRow: compactLowerRow
                    ),
                trailing:
                    moonMetricCard(
                        moonPhase,
                        rowHeight: lowerRowHeight,
                        compactLowerRow: compactLowerRow
                    )
            )
            .frame(height: lowerRowHeight, alignment: .top)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func feelsLikeMetricCard(_ state: WeatherScreenState, rowHeight: CGFloat) -> some View {
        Button {
            HapticManager.lightImpact()
            selectedMetricDetail = .apparentTemperature
        } label: {
            MetricCard(
                title: "Gefühlt",
                value: "\(Int(state.current.apparentTemperature.rounded()))°",
                detail: feelsLikeSummary(for: state),
                secondaryDetail: feelsLikeReason(for: state),
                secondaryLineLimit: 3,
                contentHeight: rowHeight,
                timeline: apparentTemperatureTimeline(for: state),
                timelineAccent: DesignTokens.sun,
                showsDisclosureIndicator: true
            )
        }
        .buttonStyle(.plain)
    }

    private func precipitationMetricCard(_ state: WeatherScreenState, rowHeight: CGFloat) -> some View {
        Button {
            HapticManager.lightImpact()
            isPrecipitationSheetPresented = true
        } label: {
            MetricCard(
                title: "Niederschlag",
                value: precipitationValue(for: state),
                detail: precipitationAssessment(for: state),
                secondaryDetail: humidityAssessment(for: state.current.relativeHumidity),
                contentHeight: rowHeight,
                timeline: precipitationTimeline(for: state),
                timelineAccent: DesignTokens.rain,
                timelineBaseline: 0,
                showsDisclosureIndicator: true
            )
        }
        .buttonStyle(.plain)
    }

    private func sunMetricCard(
        _ state: WeatherScreenState,
        timeZone: TimeZone,
        rowHeight: CGFloat,
        compactLowerRow: Bool
    ) -> some View {
        Button {
            HapticManager.lightImpact()
            isSunSheetPresented = true
        } label: {
            MetricCard(
                title: sunEventTitle(for: state.nextSunEvent),
                value: sunValue(state.nextSunEvent, timeZone: timeZone),
                detail: sunEventDetail(for: state),
                detailLineLimit: compactLowerRow ? 1 : 2,
                contentHeight: rowHeight,
                showsDisclosureIndicator: true
            )
        }
        .buttonStyle(.plain)
    }

    private func windMetricCard(_ state: WeatherScreenState, rowHeight: CGFloat) -> some View {
        Button {
            HapticManager.lightImpact()
            selectedMetricDetail = .wind
        } label: {
            MetricCard(
                title: "Wind",
                value: "\(Int(state.current.windSpeed.rounded())) km/h",
                detail: windAssessment(for: state.current.windSpeed),
                contentHeight: rowHeight,
                timeline: windTimeline(for: state),
                timelineAccent: DesignTokens.ink,
                timelineBaseline: 0,
                showsDisclosureIndicator: true
            )
        }
        .buttonStyle(.plain)
    }

    private func moonMetricCard(
        _ moonPhase: MoonPhaseInfo,
        rowHeight: CGFloat,
        compactLowerRow: Bool
    ) -> some View {
        Button {
            HapticManager.lightImpact()
            isMoonSheetPresented = true
        } label: {
            MetricCard(
                title: "Mondphase",
                value: moonPhase.title,
                detail: moonPhase.detail,
                valueLineLimit: compactLowerRow ? 1 : 2,
                detailLineLimit: compactLowerRow ? 1 : 2,
                contentHeight: rowHeight,
                showsDisclosureIndicator: true,
                headerAccessory: AnyView(MoonPhaseBadge(kind: moonPhase.kind))
            )
        }
        .buttonStyle(.plain)
    }

    private func uvMetricCard(_ state: WeatherScreenState, rowHeight: CGFloat) -> some View {
        Button {
            HapticManager.lightImpact()
            isUVSheetPresented = true
        } label: {
            MetricCard(
                title: "UV",
                value: uvValue(for: state),
                detail: uvAssessment(for: state),
                secondaryDetail: uvProtectionHint(for: state),
                secondaryLineLimit: 2,
                contentHeight: rowHeight,
                timeline: uvTimeline(for: state),
                timelineAccent: DesignTokens.sun,
                timelineBaseline: 0,
                showsDisclosureIndicator: true
            )
        }
        .buttonStyle(.plain)
    }

    private func metricRow<Leading: View, Trailing: View>(
        leading: Leading,
        trailing: Trailing
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            leading
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            trailing
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var loadingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Wetterblatt startet")
                .font(DesignTokens.serif(size: 24))
                .foregroundStyle(DesignTokens.ink)

            Text("Standort, Cache und aktuelle Prognose werden im Hintergrund vorbereitet.")
                .font(DesignTokens.mono(size: 11))
                .foregroundStyle(DesignTokens.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .vintageCard()
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Noch keine Wetteransicht")
                .font(DesignTokens.serif(size: 24))
                .foregroundStyle(DesignTokens.ink)

            Text("Erlaube den Standortzugriff, damit Wetterblatt deinen Ort laden kann.")
                .font(DesignTokens.mono(size: 11))
                .foregroundStyle(DesignTokens.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .vintageCard()
    }

    private func dashboardLayout(for availableHeight: CGFloat, hasBanner: Bool) -> DashboardLayout {
        let compactHeight = availableHeight < 720
        let stackSpacing: CGFloat = compactHeight ? 8 : 10
        let rowSpacing: CGFloat = compactHeight ? 8 : 9
        let baseBannerHeight: CGFloat = hasBanner ? (compactHeight ? 44 : 48) : 0
        let baseHeroHeight: CGFloat = hasBanner ? (compactHeight ? 168 : 178) : (compactHeight ? 176 : 186)
        let baseUpperRowHeight: CGFloat = compactHeight ? 146 : 156
        let baseLowerRowHeight: CGFloat = compactHeight ? 100 : 108
        let baseSpacing = (hasBanner ? stackSpacing : 0) + stackSpacing + rowSpacing * 2
        let baseTotalHeight = baseBannerHeight + baseHeroHeight + (baseUpperRowHeight * 2) + baseLowerRowHeight + baseSpacing
        let scale = availableHeight / max(baseTotalHeight, 1)

        return DashboardLayout(
            stackSpacing: stackSpacing,
            rowSpacing: rowSpacing,
            contentScale: min(1, scale),
            bannerHeight: baseBannerHeight * scale,
            heroHeight: baseHeroHeight * scale,
            upperRowHeight: baseUpperRowHeight * scale,
            lowerRowHeight: baseLowerRowHeight * scale
        )
    }

    private func bannerText(for state: WeatherScreenState) -> String? {
        let timeZone = displayTimeZone(for: state)

        if !state.isConnected {
            return "Offline. Zeige den letzten Snapshot von \(WeatherDateFormatting.time(state.snapshot.fetchedAt, timeZone: timeZone))."
        }

        if state.freshness != .fresh {
            return "Stand \(WeatherDateFormatting.time(state.snapshot.fetchedAt, timeZone: timeZone)). Im Vordergrund prüft die App automatisch alle \(AppModel.foregroundAutoRefreshMinutes) Min. auf neue Daten."
        }

        switch state.current.source {
        case .liveCurrent:
            return nil
        case .hourlyFallback:
            return "Kein aktueller API-Block. Werte werden für jetzt aus dem Forecast aufgelöst."
        case .staleForecast:
            return "Kein frischer Snapshot. Werte werden für jetzt aus einem älteren Forecast aufgelöst."
        }
    }

    private func precipitationValue(for state: WeatherScreenState) -> String {
        guard let precipitation = precipitationAmount(for: state) else { return "—" }
        return precipitationMillimeterString(precipitation)
    }

    private func precipitationAssessment(for state: WeatherScreenState) -> String {
        let precipitation = precipitationAmount(for: state) ?? 0

        switch precipitation {
        case ..<0.2:
            return "Heute bleibt es voraussichtlich trocken."
        case ..<1:
            return "Nur ein paar Tropfen sind drin."
        case ..<3:
            return "Leichter Niederschlag über den Tag."
        case ..<8:
            return "Spürbarer Regen im Tagesverlauf."
        case ..<15:
            return "Heute kommt einiges an Regen zusammen."
        default:
            return "Deutlich nasser Tag mit viel Niederschlag."
        }
    }

    private func precipitationAmount(for state: WeatherScreenState) -> Double? {
        let timeZone = displayTimeZone(for: state)
        let calendar = Calendar.weatherCalendar(timeZone: timeZone)
        let todayEntries = state.snapshot.hourly.filter { calendar.isDate($0.timestamp, inSameDayAs: model.clock.now) }

        if !todayEntries.isEmpty {
            return todayEntries.reduce(0) { $0 + max(0, $1.precipitation) }
        }

        return currentHourlyEntry(from: state)?.precipitation
    }

    private func precipitationMillimeterString(_ precipitation: Double) -> String {
        if precipitation < 0.15 {
            return "0 mm"
        }

        if precipitation >= 10 || abs(precipitation.rounded() - precipitation) < 0.05 {
            return "\(Int(precipitation.rounded())) mm"
        }

        return "\(String(format: "%.1f", precipitation).replacingOccurrences(of: ".", with: ",")) mm"
    }

    private func humidityAssessment(for humidity: Double?) -> String {
        guard let humidity else { return "Luftfeuchte gerade unklar." }

        switch humidity {
        case ..<30:
            return "Luft sehr trocken."
        case ..<45:
            return "Luft eher trocken."
        case ..<60:
            return "Luft angenehm ausgeglichen."
        case ..<72:
            return "Luft spürbar feucht."
        case ..<85:
            return "Luft feucht und etwas schwer."
        default:
            return "Luft sehr feucht, fast schwül."
        }
    }

    private func windAssessment(for speed: Double) -> String {
        switch speed {
        case ..<5:
            return "Fast windstill."
        case ..<12:
            return "Leichter Zug in der Luft."
        case ..<20:
            return "Leichte Brise."
        case ..<30:
            return "Spürbar windig."
        case ..<40:
            return "Frischer Wind."
        case ..<55:
            return "Kräftiger Wind."
        default:
            return "Schon deutlich stürmisch."
        }
    }

    private func uvValue(for state: WeatherScreenState) -> String {
        guard let uvIndex = currentUVIndex(for: state) else { return "—" }

        if abs(uvIndex.rounded() - uvIndex) < 0.05 {
            return "\(Int(uvIndex.rounded()))"
        }

        return String(format: "%.1f", uvIndex).replacingOccurrences(of: ".", with: ",")
    }

    private func uvAssessment(for state: WeatherScreenState) -> String {
        guard let uvIndex = currentUVIndex(for: state) else { return "UV-Wert gerade unklar." }

        switch uvIndex {
        case ..<1:
            return "Kaum UV-Belastung."
        case ..<3:
            return "Niedrige UV-Last."
        case ..<6:
            return "Mittelstarke Sonne."
        case ..<8:
            return "Deutlich erhöhte UV-Last."
        case ..<11:
            return "Hohe UV-Belastung."
        default:
            return "Sehr starke UV-Belastung."
        }
    }

    private func uvProtectionHint(for state: WeatherScreenState) -> String? {
        guard let uvIndex = currentUVIndex(for: state) else { return nil }

        switch uvIndex {
        case ..<3:
            return "Für kurze Zeit meist unkritisch."
        case ..<6:
            return "Längere Sonne besser nicht ganz ungeschützt."
        case ..<8:
            return "Mittags sind Schatten und Schutz sinnvoll."
        default:
            return "Direkte Mittagssonne besser meiden."
        }
    }

    private func heroRecommendationLines(for state: WeatherScreenState) -> [String] {
        let seed = recommendationSeed(for: state)
        return [
            clothingRecommendation(for: state, seed: seed),
            activityRecommendation(for: state, seed: seed)
        ]
    }

    private func clothingRecommendation(for state: WeatherScreenState, seed: Int) -> String {
        let temperature = state.current.apparentTemperature
        let precipitationChance = state.daily.first?.precipitationProbabilityMax
            ?? currentHourlyEntry(from: state)?.precipitationProbability
            ?? 0
        let wind = state.current.windSpeed
        let uvIndex = currentUVIndex(for: state) ?? 0

        let baseOptions: [String]
        switch temperature {
        case ..<0:
            baseOptions = [
                "Dicke Lagen, Schal und feste Schuhe fühlen sich heute klar richtiger an.",
                "Mit Mantel, warmem Pullover und robusten Schuhen bist du heute entspannter unterwegs.",
                "Heute gewinnt alles, was warm hält und nicht nur gut aussieht.",
                "Wintermodus passt heute besser als irgendein Kompromiss-Look.",
                "Greif heute lieber zu den Sachen, die wirklich isolieren."
            ]
        case ..<6:
            baseOptions = [
                "Mantel oder dicke Jacke, dazu geschlossene Schuhe, passen heute am besten.",
                "Warme Schichten machen den Tag heute deutlich angenehmer.",
                "Mit Pullover, Jacke und festen Schuhen bist du heute gut aufgestellt.",
                "Zieh dich heute lieber eine Stufe wärmer an, als es erst klingt.",
                "Eine ordentliche Jacke zahlt sich heute mehr aus als Leichtigkeit."
            ]
        case ..<12:
            baseOptions = [
                "Leichte Jacke, Strick oder Overshirt treffen den Tag ziemlich gut.",
                "Layering ist heute die bessere Idee als nur ein einzelnes T-Shirt.",
                "Geschlossene Schuhe und eine leichte Extra-Lage passen heute gut zusammen.",
                "Mit einer Jacke zum schnellen An- und Ausziehen bleibst du heute flexibel.",
                "Ein Mix aus leichter Basis und etwas zum Drüberwerfen funktioniert heute am besten."
            ]
        case ..<18:
            baseOptions = [
                "T-Shirt plus leichte Zusatzlage reicht heute meistens locker aus.",
                "Mit Cardigan, Hemdjacke oder dünnem Pulli bleibst du heute entspannt flexibel.",
                "Leichte Lagen sind heute die angenehmste Mitte.",
                "Ganz ohne Extra-Schicht wird es heute schnell frischer, als man denkt.",
                "Etwas Leichtes zum Überwerfen macht den Tag heute unkomplizierter."
            ]
        case ..<24:
            baseOptions = [
                "Luftige Stoffe und leichte Schuhe fühlen sich heute ziemlich richtig an.",
                "Heute reichen leichte Sachen, die Jacke darf meistens Pause machen.",
                "Ein lockerer Look ohne viel Gewicht passt heute am besten.",
                "Kurze Ärmel und höchstens eine sehr leichte Schicht für später genügen heute gut.",
                "Alles darf heute unkompliziert und luftig bleiben."
            ]
        default:
            baseOptions = [
                "Leichte, lockere Kleidung trägt sich heute deutlich angenehmer.",
                "Mit luftigen Stoffen und wenig Ballast bist du heute besser unterwegs.",
                "Heute passt alles, was kühl bleibt und nicht anliegt.",
                "Leichte Kleidung ist heute klar angenehmer als jede Extra-Lage.",
                "Zieh dich heute so an, dass Luft rankommt und Wege entspannt bleiben."
            ]
        }

        let addonOptions: [String]
        if precipitationChance >= 70 {
            addonOptions = [
                "Regenschutz ist heute eher Pflicht als Reserve.",
                "Ein verlässlicher Schirm oder eine gute Kapuze spart dir später Nerven.",
                "Wenn du raus musst, lohnt sich heute alles, was wirklich trocken hält.",
                "Wasserfeste Schuhe machen heute mehr Unterschied als sonst."
            ]
        } else if precipitationChance >= 45 {
            addonOptions = [
                "Ein kleiner Schirm in der Tasche ist heute eine gute Versicherung.",
                "Kapuze oder Schirm mitzunehmen wäre heute die clevere Kurzfassung.",
                "Für unterwegs schadet heute ein bisschen Regenschutz nicht.",
                "Pack lieber etwas ein, das einen Schauer locker abfängt."
            ]
        } else if wind >= 28 {
            addonOptions = [
                "Etwas Windfestes obenrum macht es draußen deutlich angenehmer.",
                "Eine Lage, die nicht sofort durchzieht, lohnt sich heute.",
                "Offene, flatterige Sachen nerven heute eher als sonst.",
                "Windschutz schlägt heute reine Optik."
            ]
        } else if uvIndex >= 6 && state.current.isDay {
            addonOptions = [
                "Sonnencreme und Brille sind heute sinnvoller als nur optional.",
                "Denk heute an UV-Schutz, besonders rund um die Mittagsstunden.",
                "Brille, etwas Schatten und Schutz für die Haut zahlen sich heute aus.",
                "Wenn du länger draußen bist, plane heute Sonnenschutz mit ein."
            ]
        } else {
            addonOptions = [
                "So bleibst du über den Tag flexibler.",
                "Damit fühlt sich heute alles ein bisschen unkomplizierter an.",
                "Damit bist du für den Tag ziemlich entspannt aufgestellt.",
                "So musst du unterwegs am wenigsten nachjustieren."
            ]
        }

        return "\(pickRecommendation(baseOptions, seed: seed, salt: 11)) \(pickRecommendation(addonOptions, seed: seed, salt: 29))"
    }

    private func activityRecommendation(for state: WeatherScreenState, seed: Int) -> String {
        let precipitationChance = state.daily.first?.precipitationProbabilityMax
            ?? currentHourlyEntry(from: state)?.precipitationProbability
            ?? 0
        let wind = state.current.windSpeed
        let temperature = state.current.apparentTemperature
        let uvIndex = currentUVIndex(for: state) ?? 0
        let hour = Calendar.weatherCalendar(timeZone: displayTimeZone(for: state)).component(.hour, from: model.clock.now)
        let weatherCode = state.current.weatherCode

        let baseOptions: [String]
        let detailOptions: [String]

        if weatherCode >= 95 || precipitationChance >= 80 {
            baseOptions = [
                "Ein Indoor-Plan mit Fensterplatz hat heute mehr Charme als große Wege draußen.",
                "Heute gewinnt alles, was warm, trocken und ein bisschen gemütlich ist.",
                "Buchladen, Café oder eine lange Runde drinnen passen heute deutlich besser.",
                "Wenn du die Wahl hast, setz heute lieber auf trockene Orte statt auf spontane Draußen-Pläne.",
                "Küche, Kino oder eine ruhige Ecke funktionieren heute besser als viel Strecke."
            ]
            detailOptions = [
                "Wenn du raus musst, plane lieber trockene Zwischenstopps ein.",
                "Große Umwege fühlen sich heute eher nach Arbeit als nach Freizeit an.",
                "Der angenehmere Teil des Tages spielt sich heute ziemlich sicher drinnen ab.",
                "Mehr als kurze Wege muss man dem Wetter heute nicht abverlangen."
            ]
        } else if isSnowWeatherCode(weatherCode) || temperature < 2 {
            baseOptions = [
                "Kurzer Spaziergang ja, aber der eigentliche Plan darf heute gern drinnen stattfinden.",
                "Frische Luft in kleinen Dosen und danach etwas Warmes ist heute die gute Balance.",
                "Heute fühlt sich ein kurzer Walk mit klarem Rückweg nach drinnen am besten an.",
                "Draußen eher kompakt planen, drinnen dann gemütlicher verlängern.",
                "Alles mit kurzer Strecke und warmem Ziel passt heute gut."
            ]
            detailOptions = [
                "Mit einem warmen Getränk im Anschluss wirkt alles direkt besser.",
                "Zu viel Standzeit draußen lohnt sich heute kaum.",
                "Mach die Außenrunde lieber klein und den gemütlichen Teil danach größer.",
                "Heute zählt eher die richtige Dauer als der große Plan."
            ]
        } else if precipitationChance >= 65 {
            baseOptions = [
                "Ein Café, Museum oder irgendetwas mit Dach fühlt sich heute stimmiger an als ein langer Draußen-Plan.",
                "Heute passen trockene Orte und kurze Wege besser zusammen.",
                "Der Tag eignet sich eher für Stopps mit Tür als für stundenlanges Unterwegssein.",
                "Setz heute lieber auf geschützte Plätze statt auf offene Runden.",
                "Alles mit kurzer Strecke und schnellem Unterstand gewinnt heute."
            ]
            detailOptions = [
                "Wenn du rausgehst, nimm am besten eine Route mit Plan B.",
                "Spontan geht heute eher drinnen als draußen gut auf.",
                "Längere Aufenthalte im Freien verlieren heute schnell ihren Reiz.",
                "Ein bisschen Struktur spart dir heute nasse Überraschungen."
            ]
        } else if wind >= 35 {
            baseOptions = [
                "Für draußen lieber kurze Etappen, geschützte Wege und kein allzu offenes Setting.",
                "Heute lohnt sich eher ein schneller Kaffeegang als ein langer Aufenthalt draußen.",
                "Windige Tage funktionieren besser mit klaren Stopps statt langem Herumtreiben.",
                "Such dir heute lieber Orte mit Wänden, Ecken oder Dach statt freier Fläche.",
                "Draußen besser effizient bleiben und das Gemütliche nach innen verlagern."
            ]
            detailOptions = [
                "Offene Plätze fühlen sich heute schneller ungemütlich an.",
                "Alles, was flattert oder zieht, nervt heute früher als sonst.",
                "Mit einem klaren Hin-und-zurück-Plan läuft der Tag heute besser.",
                "Wenn du draußen sitzt, dann lieber kurz und geschützt."
            ]
        } else if hour >= 19 {
            baseOptions = [
                "Für später passen offene Fenster, eine kleine Runde und dann ein ruhiger Abend.",
                "Heute Abend fühlt sich ein langsamer Ausklang mit etwas frischer Luft ziemlich richtig an.",
                "Später gewinnt eher ein leiser Plan als noch viel Trubel.",
                "Wenn der Tag kippt, passen ein kurzer Walk und dann ein entspannter Abend gut zusammen.",
                "Der Abend lädt heute eher zum Runterfahren als zum Hetzen ein."
            ]
            detailOptions = [
                "Mehr muss der Plan heute eigentlich gar nicht leisten.",
                "Ein bisschen frische Luft reicht heute schon als gutes Extra.",
                "Alles, was ruhig endet, passt heute erstaunlich gut.",
                "Der Tag darf heute ohne großes Finale auslaufen."
            ]
        } else if state.current.isDay && weatherCode <= 2 {
            baseOptions = [
                "Guter Tag für Parkrunde, Marktbesuch oder Kaffee irgendwo mit Sonne.",
                "Heute lohnt sich alles, was ein bisschen draußen, langsam und spontan sein darf.",
                "Wenn du raus willst, ist heute ein schöner Tag für einen Umweg zu Fuß.",
                "Eine Bank in der Sonne passt heute fast besser als jeder feste Plan.",
                "Spaziergang, kurze Pause draußen oder ein offener Balkonmoment funktionieren heute sehr gut."
            ]
            if uvIndex >= 6 {
                detailOptions = [
                    "Die angenehmeren Stunden liegen heute eher vor oder nach Mittag.",
                    "Such dir draußen lieber Schatteninseln statt die volle Mittagssonne.",
                    "Kurze Pausen im Schatten machen heute mehr aus als sonst.",
                    "Längere Draußen-Zeit wirkt heute mit etwas Sonnenschutz deutlich besser."
                ]
            } else {
                detailOptions = [
                    "Die hellen Stunden sind heute klar der Hauptgewinn.",
                    "Gerade kleine spontane Wege fühlen sich heute besonders gut an.",
                    "Wenn du Zeit hast, nimm heute lieber den schöneren als den schnellsten Weg.",
                    "Für einen kurzen Extra-Stopp draußen ist heute ein guter Tag."
                ]
            }
        } else {
            baseOptions = [
                "Heute funktionieren lange Wege zu Fuß erstaunlich gut.",
                "Ein kleiner Umweg, eine Erledigung zu Fuß oder ein Kaffee draußen passen heute gut.",
                "Der Tag eignet sich gut für spontane Mini-Pläne ohne großen Aufwand.",
                "Heute ist gutes Wetter für Dinge, die keinen strengen Plan brauchen.",
                "Ein bisschen draußen sein lohnt sich heute auch ohne großes Ziel."
            ]
            detailOptions = [
                "Gerade die kleinen ungeplanten Stops machen heute etwas aus.",
                "Du musst heute nicht viel organisieren, damit es angenehm wird.",
                "Locker geplante Wege funktionieren heute besser als starre Tagespläne.",
                "Schon ein kurzer Abstecher nach draußen fühlt sich heute nach guter Idee an."
            ]
        }

        return "\(pickRecommendation(baseOptions, seed: seed, salt: 43)) \(pickRecommendation(detailOptions, seed: seed, salt: 71))"
    }

    private func recommendationSeed(for state: WeatherScreenState) -> Int {
        let timeZone = displayTimeZone(for: state)
        let calendar = Calendar.weatherCalendar(timeZone: timeZone)
        let components = calendar.dateComponents([.year, .month, .day], from: model.clock.now)
        let dateKey = "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
        let precipitationChance = state.daily.first?.precipitationProbabilityMax
            ?? currentHourlyEntry(from: state)?.precipitationProbability
            ?? 0

        let weatherKey = [
            state.place.id,
            state.place.name,
            state.snapshot.placeName,
            "\(state.current.weatherCode)",
            "\(Int(state.current.apparentTemperature.rounded()))",
            "\(Int(precipitationChance.rounded()))",
            "\(Int(state.current.windSpeed.rounded()))",
            "\(state.current.isDay ? 1 : 0)"
        ].joined(separator: "|")

        return stableRecommendationHash("\(dateKey)|\(weatherKey)")
    }

    private func stableRecommendationHash(_ value: String) -> Int {
        value.unicodeScalars.reduce(5381) { partial, scalar in
            (partial &* 33) &+ Int(scalar.value)
        }
    }

    private func pickRecommendation(_ options: [String], seed: Int, salt: Int) -> String {
        guard !options.isEmpty else { return "" }
        let mixed = seed &+ salt &* 1_103_515_245
        let index = Int(UInt(bitPattern: mixed) % UInt(options.count))
        return options[index]
    }

    private func isSnowWeatherCode(_ code: Int) -> Bool {
        switch code {
        case 71, 73, 75, 77, 85, 86:
            return true
        default:
            return false
        }
    }

    private func feelsLikeSummary(for state: WeatherScreenState) -> String {
        let delta = state.current.apparentTemperature - state.current.temperature
        let difference = Int(abs(delta).rounded())

        if difference <= 1 {
            return "Fühlt sich fast wie die Luft an."
        }

        if delta > 0 {
            return "Wirkt etwa \(difference)° wärmer."
        }

        return "Wirkt etwa \(difference)° kühler."
    }

    private func feelsLikeReason(for state: WeatherScreenState) -> String {
        let delta = state.current.apparentTemperature - state.current.temperature
        let humidity = state.current.relativeHumidity ?? 50
        let wind = state.current.windSpeed
        let descriptor = WeatherConditions.descriptor(for: state.current.weatherCode, isDay: state.current.isDay).title.lowercased()

        if abs(delta) <= 1 {
            if wind >= 20 {
                return "Der Wind kühlt etwas, insgesamt bleibt es aber nah am echten Wert."
            }

            return "Luft, Wind und Bewölkung halten den Eindruck recht neutral."
        }

        if delta > 0 {
            if humidity >= 70 {
                return "Feuchtere Luft hält die Wärme stärker am Körper."
            }

            if state.current.isDay && state.current.weatherCode <= 2 {
                return "Mehr Sonne und ruhige Luft lassen es wärmer wirken."
            }

            return "Wenig Luftbewegung und \(descriptor) lassen die Wärme stehen."
        }

        if wind >= 20 {
            return "Der Wind nimmt dem Körper spürbar Wärme weg."
        }

        if humidity <= 40 {
            return "Trockenere Luft und offene Lage lassen es schneller abkühlen."
        }

        return "Weniger Sonne und etwas Luftbewegung drücken das Gefühl."
    }

    private func sunValue(_ sunEvent: ResolvedSunEvent?, timeZone: TimeZone) -> String {
        guard let sunEvent else { return "—" }
        return WeatherDateFormatting.time(sunEvent.date, timeZone: timeZone)
    }

    private func sunEventTitle(for sunEvent: ResolvedSunEvent?) -> String {
        guard let sunEvent else { return "Sonne" }
        return sunEvent.kind == .sunrise ? "Sonnenaufgang" : "Sonnenuntergang"
    }

    private func sunEventDetail(for state: WeatherScreenState) -> String {
        guard let sunEvent = state.nextSunEvent else { return "Nächster Sonnenwechsel gerade unklar." }

        let timeZone = displayTimeZone(for: state)
        let calendar = Calendar.weatherCalendar(timeZone: timeZone)
        let startOfEventDay = calendar.startOfDay(for: sunEvent.date)
        guard let previousDay = calendar.date(byAdding: .day, value: -1, to: startOfEventDay),
              let currentDayEntry = state.snapshot.daily.first(where: { calendar.isDate($0.date, inSameDayAs: startOfEventDay) }),
              let previousDayEntry = state.snapshot.daily.first(where: { calendar.isDate($0.date, inSameDayAs: previousDay) })
        else {
            return sunEvent.relativeDescription
        }

        let currentEventDate = sunEvent.kind == .sunrise ? currentDayEntry.sunrise : currentDayEntry.sunset
        let previousEventDate = sunEvent.kind == .sunrise ? previousDayEntry.sunrise : previousDayEntry.sunset

        guard let currentEventDate, let previousEventDate else { return sunEvent.relativeDescription }

        let currentDayStart = calendar.startOfDay(for: currentEventDate)
        let previousDayStart = calendar.startOfDay(for: previousEventDate)
        let currentMinutes = calendar.dateComponents([.minute], from: currentDayStart, to: currentEventDate).minute ?? 0
        let previousMinutes = calendar.dateComponents([.minute], from: previousDayStart, to: previousEventDate).minute ?? 0
        let deltaMinutes = currentMinutes - previousMinutes
        if abs(deltaMinutes) <= 1 {
            return "Fast gleich wie gestern."
        }

        let minutes = abs(deltaMinutes)
        return deltaMinutes > 0
            ? "\(minutes) Min. später als gestern."
            : "\(minutes) Min. früher als gestern."
    }

    private func dayTimelineEntries(for state: WeatherScreenState) -> (hours: [HourlyForecastEntry], activeTimestamp: Date?) {
        let sortedEntries = state.snapshot.hourly.sorted { $0.timestamp < $1.timestamp }
        guard !sortedEntries.isEmpty else { return ([], nil) }

        let historyHourCount = 4
        let maximumTimelineEntryCount = 22
        let calendar = Calendar.weatherCalendar(timeZone: displayTimeZone(for: state))
        let activeIndex = sortedEntries.lastIndex(where: { $0.timestamp <= model.clock.now }) ?? 0
        let activeTimestamp = sortedEntries[activeIndex].timestamp
        let startIndex = max(activeIndex - historyHourCount, 0)
        let pastAndCurrentHours = Array(sortedEntries[startIndex...activeIndex])
        let remainingFutureCapacity = max(maximumTimelineEntryCount - pastAndCurrentHours.count, 0)
        let futureHours = Array(
            sortedEntries
                .dropFirst(activeIndex + 1)
                .prefix { calendar.isDate($0.timestamp, inSameDayAs: activeTimestamp) }
                .prefix(remainingFutureCapacity)
        )

        return (pastAndCurrentHours + futureHours, activeTimestamp)
    }

    private func timelineSamples(
        for state: WeatherScreenState,
        value: (HourlyForecastEntry) -> Double?
    ) -> [MetricCard.TimelineSample] {
        let timeline = dayTimelineEntries(for: state)
        let calendar = Calendar.weatherCalendar(timeZone: displayTimeZone(for: state))

        return timeline.hours.compactMap { hour in
            guard let value = value(hour) else { return nil }
            return MetricCard.TimelineSample(
                id: hour.timestamp,
                value: value,
                isCurrent: timeline.activeTimestamp.map {
                    calendar.isDate(hour.timestamp, equalTo: $0, toGranularity: .hour)
                } ?? false,
                isPast: timeline.activeTimestamp.map { hour.timestamp < $0 } ?? false
            )
        }
    }

    private func apparentTemperatureTimeline(for state: WeatherScreenState) -> [MetricCard.TimelineSample] {
        timelineSamples(for: state) { $0.apparentTemperature }
    }

    private func precipitationTimeline(for state: WeatherScreenState) -> [MetricCard.TimelineSample] {
        timelineSamples(for: state) { $0.precipitationProbability }
    }

    private func windTimeline(for state: WeatherScreenState) -> [MetricCard.TimelineSample] {
        timelineSamples(for: state) { $0.windSpeed }
    }

    private func uvTimeline(for state: WeatherScreenState) -> [MetricCard.TimelineSample] {
        timelineSamples(for: state) { $0.uvIndex }
    }

    private func currentHourlyEntry(from state: WeatherScreenState) -> ResolvedHourlyForecast? {
        state.hourly.first(where: \.isCurrentHour) ?? state.hourly.first
    }

    private func currentUVIndex(for state: WeatherScreenState) -> Double? {
        state.current.uvIndex
            ?? currentHourlyEntry(from: state)?.uvIndex
            ?? state.daily.first?.uvIndexMax
    }

    private func normalizedPlaceName(_ name: String?) -> String? {
        guard let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }

        let placeholderNames = [
            "aktueller ort",
            "aktueller standort",
            "mein standort",
            "standort",
            "current location",
            "zuhause",
            "home",
            "ort",
        ]

        guard !placeholderNames.contains(trimmed.lowercased()) else {
            return nil
        }

        return trimmed
    }

    private func displayTimeZone(for state: WeatherScreenState) -> TimeZone {
        state.snapshot.timeZone
    }

}

private struct MoonPhaseBadge: View {
    let kind: MoonPhaseKind

    var body: some View {
        MoonPhaseIconView(kind: kind)
            .frame(width: 11, height: 11)
    }
}

private struct MoonPhaseIconView: View {
    let kind: MoonPhaseKind

    private let moonLight = Color(red: 0.95, green: 0.91, blue: 0.78)
    private let moonShadow = DesignTokens.darkAccent.opacity(0.82)

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)

            ZStack {
                switch kind {
                case .newMoon:
                    Circle()
                        .fill(moonShadow)
                case .waxingCrescent:
                    phaseBase {
                        Circle()
                            .fill(moonLight)
                            .overlay {
                                Circle()
                                    .fill(moonShadow)
                                    .offset(x: -size * 0.34)
                            }
                    }
                case .firstQuarter:
                    phaseBase {
                        Circle()
                            .fill(moonShadow)
                            .overlay(alignment: .trailing) {
                                Rectangle()
                                    .fill(moonLight)
                                    .frame(width: size * 0.5)
                            }
                    }
                case .waxingGibbous:
                    phaseBase {
                        Circle()
                            .fill(moonLight)
                            .overlay {
                                Ellipse()
                                    .fill(moonShadow)
                                    .frame(width: size * 0.62, height: size)
                                    .offset(x: -size * 0.26)
                            }
                    }
                case .fullMoon:
                    Circle()
                        .fill(moonLight)
                case .waningGibbous:
                    phaseBase {
                        Circle()
                            .fill(moonLight)
                            .overlay {
                                Ellipse()
                                    .fill(moonShadow)
                                    .frame(width: size * 0.62, height: size)
                                    .offset(x: size * 0.26)
                            }
                    }
                case .lastQuarter:
                    phaseBase {
                        Circle()
                            .fill(moonShadow)
                            .overlay(alignment: .leading) {
                                Rectangle()
                                    .fill(moonLight)
                                    .frame(width: size * 0.5)
                            }
                    }
                case .waningCrescent:
                    phaseBase {
                        Circle()
                            .fill(moonLight)
                            .overlay {
                                Circle()
                                    .fill(moonShadow)
                                    .offset(x: size * 0.34)
                            }
                    }
                }
            }
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(DesignTokens.border.opacity(0.45), lineWidth: 0.8)
            }
        }
    }

    @ViewBuilder
    private func phaseBase<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Circle()
                .fill(moonShadow)

            content()
        }
        .clipShape(Circle())
    }
}

private struct MoonMonthEntry: Identifiable {
    var id: Date { date }

    let date: Date
    let day: Int
    let info: MoonPhaseInfo
    let isToday: Bool
}

private struct MoonSheet: View {
    @Bindable var model: AppModel
    @State private var displayedMonthStart: Date?
    @State private var selectedDate: Date?

    private let weekdayHeaders = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
    private let monthGridColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        let monthStart = displayedMonthStart ?? startOfMonth(for: model.clock.now)
        let entries = monthEntries(for: monthStart)
        let selectedEntry = selectedEntry(in: entries)

        return ZStack {
            Rectangle()
                .fill(.clear)
                .paperBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    monthNavigator(monthStart: monthStart)

                    if let selectedEntry {
                        summaryCard(for: selectedEntry, in: entries)
                        monthGridCard(
                            monthStart: monthStart,
                            entries: entries,
                            selectedDate: selectedEntry.date
                        )
                    } else {
                        Text("Noch kein Monatsverlauf für den Mond verfügbar.")
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
            let initialMonth = displayedMonthStart ?? startOfMonth(for: model.clock.now)
            displayedMonthStart = initialMonth

            if selectedDate == nil {
                selectedDate = defaultSelectedDate(for: initialMonth)
            }
        }
    }

    private var timeZone: TimeZone {
        model.weatherState?.snapshot.timeZone ?? .current
    }

    private var calendar: Calendar {
        Calendar.weatherCalendar(timeZone: timeZone)
    }

    private var header: some View {
        WeatherSheetHeader(
            eyebrow: "MOND",
            title: model.weatherState?.place.name ?? "Mondphase",
            subtitle: "Der Monatsverlauf zeigt dir die Mondphase für jeden einzelnen Tag."
        )
    }

    private func monthNavigator(monthStart: Date) -> some View {
        HStack(alignment: .center, spacing: 14) {
            monthButton(systemImage: "chevron.left") {
                changeMonth(by: -1, from: monthStart)
            }

            VStack(spacing: 4) {
                Text("MONAT")
                    .font(DesignTokens.mono(size: 9, weight: .medium))
                    .foregroundStyle(DesignTokens.secondaryText)

                Text(monthTitle(for: monthStart))
                    .font(DesignTokens.serif(size: 22, weight: .bold))
                    .foregroundStyle(DesignTokens.ink)
            }
            .frame(maxWidth: .infinity)

            monthButton(systemImage: "chevron.right") {
                changeMonth(by: 1, from: monthStart)
            }
        }
        .vintageCard()
    }

    private func monthButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DesignTokens.ink)
                .frame(width: 38, height: 38)
                .background(DesignTokens.chromeFill)
                .clipShape(Circle())
                .overlay(Circle().stroke(DesignTokens.border, lineWidth: 0.8))
        }
        .buttonStyle(.plain)
    }

    private func summaryCard(for entry: MoonMonthEntry, in entries: [MoonMonthEntry]) -> some View {
        let illumination = Int((entry.info.illuminationFraction * 100).rounded())
        let title = selectedDayTitle(for: entry)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                MoonPhaseIconView(kind: entry.info.kind)
                    .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(DesignTokens.mono(size: 10, weight: .medium))
                        .foregroundStyle(DesignTokens.secondaryText)

                    Text(entry.info.title)
                        .font(DesignTokens.serif(size: 18))
                        .foregroundStyle(DesignTokens.ink)

                    Text(entry.info.detail)
                        .font(DesignTokens.mono(size: 11))
                        .foregroundStyle(DesignTokens.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                WeatherSheetMetricBadge(
                    title: "LICHT",
                    value: "\(illumination) %"
                )
            }

            WeatherSheetSupportingNote(
                systemImage: trendSymbol(for: entry.info),
                text: trendText(for: entry.info)
            )

            if let nextMajorPhase = nextMajorPhase(after: entry, in: entries) {
                WeatherSheetSupportingNote(
                    systemImage: "calendar",
                    text: "Nächster markanter Wechsel am \(WeatherDateFormatting.shortDayMonth(nextMajorPhase.date, timeZone: timeZone)): \(nextMajorPhase.info.title)."
                )
            }
        }
        .vintageCard()
    }

    private func monthGridCard(
        monthStart: Date,
        entries: [MoonMonthEntry],
        selectedDate: Date
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MONDVERLAUF PRO TAG")
                .font(DesignTokens.mono(size: 10, weight: .medium))
                .foregroundStyle(DesignTokens.secondaryText)

            Text("Tippe auf einen Tag, um oben Phase und Lichtanteil zu wechseln.")
                .font(DesignTokens.mono(size: 11))
                .foregroundStyle(DesignTokens.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(columns: monthGridColumns, spacing: 8) {
                ForEach(weekdayHeaders, id: \.self) { weekday in
                    Text(weekday)
                        .font(DesignTokens.mono(size: 9, weight: .medium))
                        .foregroundStyle(DesignTokens.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 2)
                }

                ForEach(0..<leadingOffset(for: monthStart), id: \.self) { _ in
                    Color.clear
                        .frame(height: 74)
                }

                ForEach(entries) { entry in
                    MoonMonthDayCell(
                        entry: entry,
                        isSelected: calendar.isDate(entry.date, inSameDayAs: selectedDate)
                    ) {
                        HapticManager.selectionChanged()
                        self.selectedDate = entry.date
                    }
                }
            }
        }
        .vintageCard()
    }

    private func startOfMonth(for date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: DateComponents(
            timeZone: timeZone,
            year: components.year,
            month: components.month,
            day: 1
        )) ?? calendar.startOfDay(for: date)
    }

    private func monthEntries(for monthStart: Date) -> [MoonMonthEntry] {
        guard let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }

        return dayRange.compactMap { day -> MoonMonthEntry? in
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) else { return nil }
            return MoonMonthEntry(
                date: date,
                day: day,
                info: MoonPhaseResolver.info(for: date, timeZone: timeZone),
                isToday: calendar.isDate(date, inSameDayAs: model.clock.now)
            )
        }
    }

    private func selectedEntry(in entries: [MoonMonthEntry]) -> MoonMonthEntry? {
        if let selectedDate {
            return entries.first(where: { calendar.isDate($0.date, inSameDayAs: selectedDate) }) ?? entries.first
        }

        let fallbackDate = entries.contains(where: { $0.isToday })
            ? calendar.startOfDay(for: model.clock.now)
            : entries.first?.date

        return fallbackDate.flatMap { selected in
            entries.first(where: { calendar.isDate($0.date, inSameDayAs: selected) })
        } ?? entries.first
    }

    private func defaultSelectedDate(for monthStart: Date) -> Date {
        if calendar.isDate(monthStart, equalTo: model.clock.now, toGranularity: .month) {
            return calendar.startOfDay(for: model.clock.now)
        }

        return monthStart
    }

    private func selectedDayTitle(for entry: MoonMonthEntry) -> String {
        if entry.isToday {
            return "HEUTE"
        }

        return WeatherDateFormatting.longDayMonth(entry.date, timeZone: timeZone).uppercased()
    }

    private func trendText(for info: MoonPhaseInfo) -> String {
        if info.kind.isMajorPhase {
            switch info.kind {
            case .newMoon:
                return "Ein neuer Zyklus startet. Danach nimmt die Lichtfläche wieder zu."
            case .fullMoon:
                return "Der Mond steht fast ganz im Licht. Danach nimmt die sichtbare Fläche wieder ab."
            case .firstQuarter:
                return "Die helle Hälfte ist erreicht und der Mond wächst weiter Richtung Vollmond."
            case .lastQuarter:
                return "Nur noch die andere Hälfte bleibt beleuchtet, der Zyklus läuft Richtung Neumond."
            default:
                return info.detail
            }
        }

        return info.isWaxing
            ? "Die sichtbare Lichtfläche nimmt im Moment weiter zu."
            : "Die sichtbare Lichtfläche nimmt im Moment weiter ab."
    }

    private func trendSymbol(for info: MoonPhaseInfo) -> String {
        if info.kind.isMajorPhase {
            return "sparkles"
        }

        return info.isWaxing ? "arrow.up.right" : "arrow.down.right"
    }

    private func nextMajorPhase(after entry: MoonMonthEntry, in entries: [MoonMonthEntry]) -> MoonMonthEntry? {
        let futureEntries = entries.filter { $0.date > entry.date }

        if entry.info.kind.isMajorPhase {
            return futureEntries.first { $0.info.kind.isMajorPhase && $0.info.kind != entry.info.kind }
        }

        return futureEntries.first(where: { $0.info.kind.isMajorPhase })
    }

    private func leadingOffset(for monthStart: Date) -> Int {
        let weekday = calendar.component(.weekday, from: monthStart)
        return (weekday + 5) % 7
    }

    private func monthTitle(for monthStart: Date) -> String {
        WeatherDateFormatting.string(
            from: monthStart,
            format: "LLLL yyyy",
            timeZone: timeZone,
            capitalized: true
        )
    }

    private func changeMonth(by delta: Int, from monthStart: Date) {
        guard let nextMonth = calendar.date(byAdding: .month, value: delta, to: monthStart) else { return }
        let normalizedMonth = startOfMonth(for: nextMonth)
        HapticManager.selectionChanged()
        displayedMonthStart = normalizedMonth
        selectedDate = defaultSelectedDate(for: normalizedMonth)
    }
}

private struct MoonMonthDayCell: View {
    let entry: MoonMonthEntry
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 6) {
                    Text("\(entry.day)")
                        .font(DesignTokens.mono(size: 10, weight: isSelected || entry.isToday ? .medium : .regular))
                        .foregroundStyle(DesignTokens.ink)

                    Spacer(minLength: 0)

                    if entry.isToday {
                        Circle()
                            .fill(DesignTokens.moon)
                            .frame(width: 5, height: 5)
                    }
                }

                MoonPhaseIconView(kind: entry.info.kind)
                    .frame(width: 22, height: 22)

                Text(entry.info.kind.monthBadge)
                    .font(DesignTokens.mono(size: 7.5, weight: .medium))
                    .foregroundStyle(entry.info.kind.isMajorPhase ? DesignTokens.ink : DesignTokens.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, minHeight: 74, alignment: .topLeading)
            .padding(10)
            .background(backgroundFill)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(borderColor, lineWidth: isSelected || entry.isToday ? 1.1 : 0.8)
            )
        }
        .buttonStyle(.plain)
    }

    private var backgroundFill: Color {
        if isSelected {
            return DesignTokens.chromeFill
        }

        if entry.info.kind.isMajorPhase {
            return DesignTokens.muted.opacity(0.44)
        }

        return DesignTokens.surface.opacity(0.65)
    }

    private var borderColor: Color {
        if isSelected {
            return DesignTokens.ink
        }

        if entry.isToday {
            return DesignTokens.moon
        }

        return DesignTokens.border.opacity(0.85)
    }
}

private extension MoonPhaseKind {
    var isMajorPhase: Bool {
        switch self {
        case .newMoon, .firstQuarter, .fullMoon, .lastQuarter:
            return true
        case .waxingCrescent, .waxingGibbous, .waningGibbous, .waningCrescent:
            return false
        }
    }

    var monthBadge: String {
        switch self {
        case .newMoon:
            return "Neu"
        case .firstQuarter:
            return "1. V."
        case .fullMoon:
            return "Voll"
        case .lastQuarter:
            return "L. V."
        case .waxingCrescent, .waxingGibbous, .waningGibbous, .waningCrescent:
            return ""
        }
    }
}

private struct SunSheet: View {
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
                            days: availableDays(in: state),
                            selectedDayID: selectedDayID
                        ) { day in
                            selectedDayID = day.date
                        }

                        summaryCard(for: day, state: state)
                        courseCard(for: day, state: state)
                    } else {
                        Text("Noch keine Sonnenzeiten verfügbar.")
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
                selectedDayID = model.weatherState.flatMap { availableDays(in: $0).first?.date }
            }
        }
        .onChange(of: model.weatherState?.daily.map(\.date) ?? []) { _, _ in
            let dates = model.weatherState.map { availableDays(in: $0).map(\.date) } ?? []
            guard !dates.isEmpty else {
                selectedDayID = nil
                return
            }
            if let selectedDayID, dates.contains(selectedDayID) {
                return
            }

            self.selectedDayID = dates.first
        }
    }

    private var header: some View {
        WeatherSheetHeader(
            eyebrow: "SONNE",
            title: model.weatherState?.place.name ?? "Sonne",
            subtitle: "Sonnenaufgang, Tagesmitte und Untergang in einem ruhigen Tagesbogen."
        )
    }

    private func availableDays(in state: WeatherScreenState) -> [ResolvedDailyForecast] {
        let daysWithSunTimes = Array(state.daily.prefix(7)).filter { $0.sunrise != nil && $0.sunset != nil }
        return daysWithSunTimes.isEmpty ? Array(state.daily.prefix(1)) : daysWithSunTimes
    }

    private func selectedDay(from state: WeatherScreenState) -> ResolvedDailyForecast? {
        let days = availableDays(in: state)
        return days.first(where: { $0.date == selectedDayID }) ?? days.first
    }

    @ViewBuilder
    private func summaryCard(for day: ResolvedDailyForecast, state: WeatherScreenState) -> some View {
        if let context = context(for: day, in: state) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(day.displayLabel.uppercased())
                            .font(DesignTokens.mono(size: 10, weight: .medium))
                            .foregroundStyle(DesignTokens.secondaryText)

                        Text(summaryText(for: context, timeZone: state.snapshot.timeZone))
                            .font(DesignTokens.serif(size: 17))
                            .foregroundStyle(DesignTokens.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    WeatherSheetMetricBadge(
                        title: "TAG",
                        value: durationString(context.daylightDuration)
                    )
                }

                WeatherSheetSupportingNote(
                    systemImage: "clock",
                    text: supportingText(for: context, day: day, in: state)
                )
            }
            .vintageCard()
        } else {
            Text("Für diesen Tag sind Auf- und Untergang noch nicht vollständig geladen.")
                .font(DesignTokens.mono(size: 11))
                .foregroundStyle(DesignTokens.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .vintageCard()
        }
    }

    @ViewBuilder
    private func courseCard(for day: ResolvedDailyForecast, state: WeatherScreenState) -> some View {
        if let context = context(for: day, in: state) {
            SunCourseCard(
                context: context,
                timeZone: state.snapshot.timeZone,
                statusTitle: statusTitle(for: context),
                statusText: statusText(for: context)
            )
        }
    }

    private func context(for day: ResolvedDailyForecast, in state: WeatherScreenState) -> SunDayContext? {
        guard let sunrise = day.sunrise, let sunset = day.sunset else { return nil }

        let daylightDuration = max(sunset.timeIntervalSince(sunrise), 0)
        let solarNoon = sunrise.addingTimeInterval(daylightDuration / 2)
        let calendar = Calendar.weatherCalendar(timeZone: state.snapshot.timeZone)
        let now = model.clock.now
        let phase: SunDayContext.Phase
        let progress: Double?

        if calendar.isDate(day.date, inSameDayAs: now) {
            if now < sunrise {
                phase = .beforeSunrise
                progress = 0
            } else if now > sunset {
                phase = .afterSunset
                progress = 1
            } else {
                phase = .daylight
                progress = daylightDuration > 0 ? now.timeIntervalSince(sunrise) / daylightDuration : 0
            }
        } else {
            phase = .scheduled
            progress = nil
        }

        return SunDayContext(
            sunrise: sunrise,
            sunset: sunset,
            solarNoon: solarNoon,
            daylightDuration: daylightDuration,
            progress: progress,
            phase: phase
        )
    }

    private func summaryText(for context: SunDayContext, timeZone: TimeZone) -> String {
        let sunrise = WeatherDateFormatting.time(context.sunrise, timeZone: timeZone)
        let sunset = WeatherDateFormatting.time(context.sunset, timeZone: timeZone)
        let duration = durationString(context.daylightDuration)

        switch context.phase {
        case .beforeSunrise:
            let remaining = max(context.sunrise.timeIntervalSince(model.clock.now), 0)
            return "Aufgang um \(sunrise) in \(countdownString(remaining)). Danach bleibt es rund \(duration) hell bis \(sunset)."
        case .daylight:
            let remaining = max(context.sunset.timeIntervalSince(model.clock.now), 0)
            return "Seit \(sunrise) ist Tag. Bis \(sunset) bleiben noch \(countdownString(remaining)) Licht."
        case .afterSunset:
            return "Heute lag das Tageslicht zwischen \(sunrise) und \(sunset) und dauerte rund \(duration)."
        case .scheduled:
            return "Zwischen \(sunrise) und \(sunset) liegen voraussichtlich rund \(duration) Tageslicht."
        }
    }

    private func supportingText(
        for context: SunDayContext,
        day: ResolvedDailyForecast,
        in state: WeatherScreenState
    ) -> String {
        let noon = WeatherDateFormatting.time(context.solarNoon, timeZone: state.snapshot.timeZone)

        if let comparison = daylightComparisonText(for: day, currentDuration: context.daylightDuration, in: state) {
            return "Tagesmitte gegen \(noon). \(comparison)"
        }

        return "Tagesmitte gegen \(noon)."
    }

    private func daylightComparisonText(
        for day: ResolvedDailyForecast,
        currentDuration: TimeInterval,
        in state: WeatherScreenState
    ) -> String? {
        let days = availableDays(in: state)
        guard let index = days.firstIndex(where: { $0.date == day.date }), index > 0 else { return nil }
        guard let previousSunrise = days[index - 1].sunrise, let previousSunset = days[index - 1].sunset else {
            return nil
        }

        let previousDuration = max(previousSunset.timeIntervalSince(previousSunrise), 0)
        let deltaMinutes = Int(((currentDuration - previousDuration) / 60).rounded())

        if abs(deltaMinutes) <= 1 {
            return "Fast gleich viel Tageslicht wie \(days[index - 1].displayLabel.lowercased())."
        }

        let difference = abs(deltaMinutes)
        return deltaMinutes > 0
            ? "\(difference) Min. mehr Tageslicht als \(days[index - 1].displayLabel.lowercased())."
            : "\(difference) Min. weniger Tageslicht als \(days[index - 1].displayLabel.lowercased())."
    }

    private func statusTitle(for context: SunDayContext) -> String {
        switch context.phase {
        case .beforeSunrise:
            return "VOR AUFGANG"
        case .daylight:
            return "IM TAG"
        case .afterSunset:
            return "NACH UNTERGANG"
        case .scheduled:
            return "VORSCHAU"
        }
    }

    private func statusText(for context: SunDayContext) -> String {
        switch context.phase {
        case .beforeSunrise:
            let remaining = max(context.sunrise.timeIntervalSince(model.clock.now), 0)
            return "Noch \(countdownString(remaining)) bis die Sonne den Horizont erreicht."
        case .daylight:
            let remaining = max(context.sunset.timeIntervalSince(model.clock.now), 0)
            return "Noch \(countdownString(remaining)) bis zum Untergang."
        case .afterSunset:
            return "Der heutige Sonnenbogen ist abgeschlossen."
        case .scheduled:
            return "Der Bogen zeigt den Verlauf zwischen Aufgang, Tagesmitte und Untergang."
        }
    }

    private func durationString(_ interval: TimeInterval) -> String {
        let totalMinutes = max(Int(interval / 60), 0)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if minutes == 0 {
            return "\(hours) Std."
        }

        return "\(hours) Std. \(minutes) Min."
    }

    private func countdownString(_ interval: TimeInterval) -> String {
        let totalMinutes = max(Int(interval / 60), 0)
        if totalMinutes < 60 {
            return "\(totalMinutes) Min."
        }

        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if minutes == 0 {
            return "\(hours) Std."
        }

        return "\(hours) Std. \(minutes) Min."
    }
}

private struct SunCourseCard: View {
    let context: SunDayContext
    let timeZone: TimeZone
    let statusTitle: String
    let statusText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Text("TAGESSONNENVERLAUF")
                    .font(DesignTokens.mono(size: 10, weight: .medium))
                    .foregroundStyle(DesignTokens.secondaryText)

                Spacer(minLength: 0)

                Text(statusTitle)
                    .font(DesignTokens.mono(size: 9, weight: .medium))
                    .foregroundStyle(DesignTokens.background)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(statusTint)
                    .clipShape(Capsule())
            }

            Text(statusText)
                .font(DesignTokens.mono(size: 11))
                .foregroundStyle(DesignTokens.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)

            GeometryReader { proxy in
                let metrics = SunCoursePlotMetrics(size: proxy.size)

                ZStack(alignment: .topLeading) {
                    metrics.fillPath
                        .fill(
                            LinearGradient(
                                colors: [
                                    DesignTokens.sun.opacity(0.14),
                                    DesignTokens.sun.opacity(0.03),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    Path { path in
                        path.move(to: metrics.start)
                        path.addLine(to: metrics.end)
                    }
                    .stroke(DesignTokens.border.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                    metrics.arcPath
                        .stroke(DesignTokens.border.opacity(0.6), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))

                    if let progress = context.progress {
                        metrics.progressPath(progress)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        DesignTokens.hazySun.opacity(0.7),
                                        DesignTokens.sun,
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round)
                            )
                    }

                    ForEach([0.0, 0.5, 1.0], id: \.self) { point in
                        let marker = metrics.point(at: point)
                        Circle()
                            .fill(DesignTokens.background)
                            .frame(width: 8, height: 8)
                            .overlay {
                                Circle()
                                    .stroke(DesignTokens.border, lineWidth: 1)
                            }
                            .position(marker)
                    }

                    sunMarker
                        .position(metrics.point(at: displayProgress))
                }
            }
            .frame(height: 150)

            HStack(alignment: .top, spacing: 12) {
                momentLabel(
                    title: "Aufgang",
                    value: WeatherDateFormatting.time(context.sunrise, timeZone: timeZone),
                    alignment: .leading
                )
                momentLabel(
                    title: "Mitte",
                    value: WeatherDateFormatting.time(context.solarNoon, timeZone: timeZone),
                    alignment: .center
                )
                momentLabel(
                    title: "Untergang",
                    value: WeatherDateFormatting.time(context.sunset, timeZone: timeZone),
                    alignment: .trailing
                )
            }
        }
        .vintageCard()
    }

    private var displayProgress: Double {
        min(max(context.progress ?? 0.5, 0), 1)
    }

    private var statusTint: Color {
        switch context.phase {
        case .beforeSunrise, .scheduled:
            return DesignTokens.hazySun
        case .daylight:
            return DesignTokens.sun
        case .afterSunset:
            return DesignTokens.moon
        }
    }

    private var sunMarker: some View {
        Circle()
            .fill(DesignTokens.background)
            .frame(width: 28, height: 28)
            .overlay {
                Circle()
                    .stroke(DesignTokens.sun.opacity(0.75), lineWidth: 1.3)
            }
            .overlay {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DesignTokens.sun)
            }
            .shadow(color: DesignTokens.sun.opacity(0.24), radius: 10, y: 2)
            .opacity(context.progress == nil ? 0.55 : 1)
    }

    private func momentLabel(title: String, value: String, alignment: HorizontalAlignment) -> some View {
        let frameAlignment: Alignment
        switch alignment {
        case .leading:
            frameAlignment = .leading
        case .center:
            frameAlignment = .center
        case .trailing:
            frameAlignment = .trailing
        default:
            frameAlignment = .leading
        }

        return VStack(alignment: alignment, spacing: 4) {
            Text(title.uppercased())
                .font(DesignTokens.mono(size: 9, weight: .medium))
                .foregroundStyle(DesignTokens.secondaryText)

            Text(value)
                .font(DesignTokens.serif(size: 16))
                .foregroundStyle(DesignTokens.ink)
        }
        .frame(maxWidth: .infinity, alignment: frameAlignment)
    }
}

private struct SunDayContext {
    enum Phase {
        case beforeSunrise
        case daylight
        case afterSunset
        case scheduled
    }

    let sunrise: Date
    let sunset: Date
    let solarNoon: Date
    let daylightDuration: TimeInterval
    let progress: Double?
    let phase: Phase
}

private struct SunCoursePlotMetrics {
    let size: CGSize
    let start: CGPoint
    let control: CGPoint
    let end: CGPoint

    init(size: CGSize) {
        self.size = size

        let horizonY = max(size.height - 26, 72)
        let horizontalInset: CGFloat = 22
        start = CGPoint(x: horizontalInset, y: horizonY)
        end = CGPoint(x: max(size.width - horizontalInset, horizontalInset), y: horizonY)
        control = CGPoint(x: size.width / 2, y: 16)
    }

    var arcPath: Path {
        Path { path in
            path.move(to: start)
            path.addQuadCurve(to: end, control: control)
        }
    }

    var fillPath: Path {
        Path { path in
            path.move(to: start)
            path.addQuadCurve(to: end, control: control)
            path.addLine(to: start)
            path.closeSubpath()
        }
    }

    func progressPath(_ progress: Double) -> Path {
        let clamped = min(max(progress, 0), 1)
        let steps = max(Int(clamped * 64), 1)

        return Path { path in
            for step in 0...steps {
                let t = clamped * Double(step) / Double(steps)
                let point = point(at: t)
                if step == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
        }
    }

    func point(at progress: Double) -> CGPoint {
        let t = CGFloat(min(max(progress, 0), 1))
        let inverse = 1 - t
        let x = inverse * inverse * start.x + 2 * inverse * t * control.x + t * t * end.x
        let y = inverse * inverse * start.y + 2 * inverse * t * control.y + t * t * end.y
        return CGPoint(x: x, y: y)
    }
}

private struct HomeMetricDetailSheet: View {
    @Bindable var model: AppModel
    let detail: HomeMetricDetail
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
                        let hours = dayHours(for: day, in: state)
                        let entries = chartEntries(for: state, hours: hours)

                        ForecastDayPicker(
                            title: "Tag wählen",
                            days: availableDays(in: state),
                            selectedDayID: selectedDayID
                        ) { day in
                            selectedDayID = day.date
                        }

                        summaryCard(state: state, day: day, hours: hours)

                        if entries.isEmpty {
                            Text("Für diesen Tag liegt noch kein stündlicher Verlauf vor.")
                                .font(DesignTokens.mono(size: 11))
                                .foregroundStyle(DesignTokens.secondaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .vintageCard()
                        } else {
                            HourlyChartCard(
                                entries: entries,
                                metric: metricKind,
                                titleOverride: chartTitle,
                                accentCurrentEntry: true,
                                layoutStyle: .compact
                            )
                            .vintageCard()
                        }

                        insightCard(state: state, day: day, hours: hours)
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
                selectedDayID = model.weatherState.flatMap { availableDays(in: $0).first?.date }
            }
        }
        .onChange(of: model.weatherState?.daily.map(\.date) ?? []) { _, _ in
            let dates = model.weatherState.map { availableDays(in: $0).map(\.date) } ?? []
            guard !dates.isEmpty else {
                selectedDayID = nil
                return
            }
            if let selectedDayID, dates.contains(selectedDayID) {
                return
            }

            self.selectedDayID = dates.first
        }
    }

    private var header: some View {
        WeatherSheetHeader(
            eyebrow: detail.sectionTitle,
            title: model.weatherState?.place.name ?? detail.title,
            subtitle: detail.subtitle
        )
    }

    private var metricKind: HourlyChartCard.MetricKind {
        switch detail {
        case .apparentTemperature:
            return .temperature
        case .wind:
            return .wind
        }
    }

    private var chartTitle: String {
        switch detail {
        case .apparentTemperature:
            return "Gefühlte Temperatur"
        case .wind:
            return "Windverlauf"
        }
    }

    private func summaryCard(state: WeatherScreenState, day: ResolvedDailyForecast, hours: [HourlyForecastEntry]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            switch detail {
            case .apparentTemperature:
                apparentTemperatureSummary(state: state, day: day, hours: hours)
            case .wind:
                windSummary(state: state, day: day, hours: hours)
            }
        }
        .vintageCard()
    }

    @ViewBuilder
    private func apparentTemperatureSummary(state: WeatherScreenState, day: ResolvedDailyForecast, hours: [HourlyForecastEntry]) -> some View {
        let referenceHour = summaryReferenceHour(for: day, hours: hours, timeZone: state.snapshot.timeZone)
        let referenceDelta = referenceHour.map { $0.apparentTemperature - $0.temperature } ?? 0
        let strongestGap = hours.max { abs($0.apparentTemperature - $0.temperature) < abs($1.apparentTemperature - $1.temperature) }

        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("GEFÜHLT")
                    .font(DesignTokens.mono(size: 10, weight: .medium))
                    .foregroundStyle(DesignTokens.secondaryText)

                Text(apparentTemperatureSummaryText(delta: referenceDelta))
                    .font(DesignTokens.serif(size: 17))
                    .foregroundStyle(DesignTokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            WeatherSheetMetricBadge(
                title: referenceHourBadgeTitle(for: referenceHour, timeZone: state.snapshot.timeZone),
                value: referenceHour.map { formattedTemperature($0.apparentTemperature) } ?? "—"
            )
        }

        if let strongestGap {
            WeatherSheetSupportingNote(
                systemImage: "thermometer.medium",
                text: "Größter Abstand zur Lufttemperatur um \(hourLabel(for: strongestGap.timestamp, timeZone: state.snapshot.timeZone)): \(formattedSignedTemperature(strongestGap.apparentTemperature - strongestGap.temperature))."
            )
        }
    }

    @ViewBuilder
    private func windSummary(state: WeatherScreenState, day: ResolvedDailyForecast, hours: [HourlyForecastEntry]) -> some View {
        let peakHour = hours.max(by: { $0.windSpeed < $1.windSpeed })
        let peakWind = peakHour?.windSpeed ?? 0

        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("WIND")
                    .font(DesignTokens.mono(size: 10, weight: .medium))
                    .foregroundStyle(DesignTokens.secondaryText)

                Text(windNarrative(for: peakWind))
                    .font(DesignTokens.serif(size: 17))
                    .foregroundStyle(DesignTokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            WeatherSheetMetricBadge(
                title: "MAX",
                value: peakHour.map { "\(Int($0.windSpeed.rounded())) km/h" } ?? "—"
            )
        }

        if let peakHour {
            WeatherSheetSupportingNote(
                systemImage: "wind",
                text: "Stärkste Phase um \(hourLabel(for: peakHour.timestamp, timeZone: state.snapshot.timeZone)): \(Int(peakHour.windSpeed.rounded())) km/h."
            )
        }
    }

    private func insightCard(state: WeatherScreenState, day: ResolvedDailyForecast, hours: [HourlyForecastEntry]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("EINORDNUNG")
                .font(DesignTokens.mono(size: 10, weight: .medium))
                .foregroundStyle(DesignTokens.secondaryText)

            Text(insightText(state: state, day: day, hours: hours))
                .font(DesignTokens.mono(size: 11))
                .foregroundStyle(DesignTokens.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .vintageCard()
    }

    private func insightText(state: WeatherScreenState, day: ResolvedDailyForecast, hours: [HourlyForecastEntry]) -> String {
        switch detail {
        case .apparentTemperature:
            let relevantHours = trendHours(for: day, hours: hours)
            let current = relevantHours.first?.apparentTemperature ?? hours.first?.apparentTemperature ?? state.current.apparentTemperature
            let later = relevantHours.dropFirst(2).first?.apparentTemperature ?? relevantHours.last?.apparentTemperature ?? current
            let delta = later - current

            if abs(delta) < 1.5 {
                return "Im weiteren Tagesverlauf bleibt der gefühlte Wert ziemlich stabil. Größere Sprünge sind gerade nicht im Forecast."
            }

            return delta > 0
                ? "Bis später zieht die gefühlte Temperatur noch an. Vor allem in ruhigeren, sonnigen Phasen wirkt es merklich wärmer."
                : "Im weiteren Tagesverlauf verliert die Luft an Wärmegefühl. Wind oder nachlassende Sonne drücken den Eindruck etwas nach unten."
        case .wind:
            let relevantHours = trendHours(for: day, hours: hours)
            let current = relevantHours.first?.windSpeed ?? hours.first?.windSpeed ?? state.current.windSpeed
            let later = relevantHours.dropFirst(2).first?.windSpeed ?? relevantHours.last?.windSpeed ?? current
            let delta = later - current

            if abs(delta) < 4 {
                return "Der Wind bleibt über den restlichen Tag ziemlich gleichmäßig. Keine markante Phase sticht gerade heraus."
            }

            return delta > 0
                ? "Später wird es eher noch zugiger. Wenn du längere Zeit draußen bist, fühlt es sich offener und kühler an."
                : "Später beruhigt sich der Wind etwas. Wege draußen wirken dadurch angenehmer als gerade jetzt."
        }
    }

    private func chartEntries(
        for state: WeatherScreenState,
        hours: [HourlyForecastEntry]
    ) -> [HourlyChartCard.Entry] {
        let values = hours.compactMap(chartValue(for:))
        let peakValue = values.max()
        let calendar = Calendar.weatherCalendar(timeZone: state.snapshot.timeZone)

        return hours.compactMap { hour in
            guard let value = chartValue(for: hour) else { return nil }
            let isCurrent = calendar.isDate(hour.timestamp, equalTo: model.clock.now, toGranularity: .hour)
            let isPast = hour.timestamp < model.clock.now

            return HourlyChartCard.Entry(
                id: hour.timestamp,
                displayLabel: isCurrent ? "Jetzt" : hourLabel(for: hour.timestamp, timeZone: state.snapshot.timeZone),
                value: value,
                formattedValue: formattedChartValue(value),
                isCurrent: isCurrent,
                isPast: isPast,
                isRangeHighlighted: !isPast || isCurrent,
                isPeak: peakValue.map { abs($0 - value) < 0.01 } ?? false
            )
        }
    }

    private func chartValue(for hour: HourlyForecastEntry) -> Double? {
        switch detail {
        case .apparentTemperature:
            return hour.apparentTemperature
        case .wind:
            return hour.windSpeed
        }
    }

    private func formattedChartValue(_ value: Double) -> String {
        switch detail {
        case .apparentTemperature:
            return formattedTemperature(value)
        case .wind:
            return "\(Int(value.rounded())) km/h"
        }
    }

    private func dayHours(for day: ResolvedDailyForecast, in state: WeatherScreenState) -> [HourlyForecastEntry] {
        let calendar = Calendar.weatherCalendar(timeZone: state.snapshot.timeZone)
        let dayEntries = state.snapshot.hourly
            .sorted { $0.timestamp < $1.timestamp }
            .filter { calendar.isDate($0.timestamp, inSameDayAs: day.date) }

        return dayEntries
    }

    private func availableDays(in state: WeatherScreenState) -> [ResolvedDailyForecast] {
        let calendar = Calendar.weatherCalendar(timeZone: state.snapshot.timeZone)
        let hourlyDays = Set(state.snapshot.hourly.map { calendar.startOfDay(for: $0.timestamp) })
        let days = state.daily.filter { hourlyDays.contains(calendar.startOfDay(for: $0.date)) }

        return days.isEmpty ? Array(state.daily.prefix(1)) : days
    }

    private func selectedDay(from state: WeatherScreenState) -> ResolvedDailyForecast? {
        let days = availableDays(in: state)
        return days.first(where: { $0.date == selectedDayID }) ?? days.first
    }

    private func summaryReferenceHour(
        for day: ResolvedDailyForecast,
        hours: [HourlyForecastEntry],
        timeZone: TimeZone
    ) -> HourlyForecastEntry? {
        let calendar = Calendar.weatherCalendar(timeZone: timeZone)

        if day.isToday {
            return hours.last(where: { $0.timestamp <= model.clock.now }) ?? hours.first
        }

        return hours.first(where: { calendar.component(.hour, from: $0.timestamp) >= 12 }) ?? hours.first
    }

    private func referenceHourBadgeTitle(for hour: HourlyForecastEntry?, timeZone: TimeZone) -> String {
        guard let hour else { return "TAG" }
        let calendar = Calendar.weatherCalendar(timeZone: timeZone)
        if calendar.isDate(hour.timestamp, equalTo: model.clock.now, toGranularity: .hour) {
            return "JETZT"
        }

        return "\(hourLabel(for: hour.timestamp, timeZone: timeZone)) UHR"
    }

    private func trendHours(for day: ResolvedDailyForecast, hours: [HourlyForecastEntry]) -> [HourlyForecastEntry] {
        if day.isToday {
            let futureHours = hours.filter { $0.timestamp >= model.clock.now }
            return futureHours.isEmpty ? hours : futureHours
        }

        return hours
    }

    private func hourLabel(for date: Date, timeZone: TimeZone) -> String {
        return WeatherDateFormatting.string(from: date, format: "HH", timeZone: timeZone)
    }

    private func formattedTemperature(_ value: Double) -> String {
        "\(Int(value.rounded()))°"
    }

    private func formattedSignedTemperature(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        if rounded > 0 {
            return "+\(rounded)°"
        }
        return "\(rounded)°"
    }

    private func apparentTemperatureSummaryText(delta: Double) -> String {
        if abs(delta) <= 1 {
            return "Die gefühlte Temperatur liegt nah an der gemessenen Luft."
        }

        if delta > 0 {
            return "Sonne oder ruhigere Luft lassen es etwa \(Int(delta.rounded()))° wärmer wirken als gemessen."
        }

        return "Wind oder Feuchte drücken das Gefühl um etwa \(Int(abs(delta).rounded()))° unter die Lufttemperatur."
    }

    private func windNarrative(for speed: Double) -> String {
        switch speed {
        case ..<10:
            return "Kaum Druck auf der Luft. Draußen wirkt alles eher ruhig."
        case ..<20:
            return "Leichte bis spürbare Brise. Offenere Ecken fühlen sich merklich frischer an."
        case ..<30:
            return "Schon deutlich windig. Auf Wegen und am Wasser ist der Zug konstant da."
        case ..<45:
            return "Kräftige Phase. Jacke oder zusätzliche Schicht machen draußen einen Unterschied."
        default:
            return "Sehr markanter Wind. Längere Zeit im Freien fühlt sich schnell rau an."
        }
    }
}

private extension View {
    func dismissalHaptic(isPresented: Bool) -> some View {
        onChange(of: isPresented) { oldValue, newValue in
            if oldValue && !newValue {
                HapticManager.lightImpact()
            }
        }
    }

    func dismissalHaptic<Item: Equatable>(item: Item?) -> some View {
        onChange(of: item) { oldValue, newValue in
            if oldValue != nil && newValue == nil {
                HapticManager.lightImpact()
            }
        }
    }
}

private extension HomeMetricDetail {
    var sectionTitle: String {
        switch self {
        case .apparentTemperature:
            return "GEFÜHLT"
        case .wind:
            return "WIND"
        }
    }

    var title: String {
        switch self {
        case .apparentTemperature:
            return "Gefühlt"
        case .wind:
            return "Wind"
        }
    }

    var subtitle: String {
        switch self {
        case .apparentTemperature:
            return "So läuft die gefühlte Temperatur über den Tag."
        case .wind:
            return "Hier siehst du, wann der Tag ruhiger oder zugiger wird."
        }
    }
}
