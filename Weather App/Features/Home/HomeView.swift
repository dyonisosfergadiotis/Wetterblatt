import CoreLocation
import SwiftUI
import UIKit

private enum HomeMetricDetail: String, Identifiable {
    case apparentTemperature
    case wind

    var id: String { rawValue }
}

private struct HeroBriefing {
    let headline: String
    let detail: String
}

private struct HeroQuickFact: Identifiable {
    let title: String
    let value: String
    let accent: Color

    var id: String { title }
}

private enum HeroMoment {
    case earlyMorning
    case morning
    case midday
    case afternoon
    case evening
    case night
}

private struct AirQualityQuickGlanceSummary {
    let title: String
    let detail: String
    let tint: Color
    let symbolName: String
}

private enum WeatherAlertSeverity: Int, CaseIterable, Comparable {
    case calm
    case advisory
    case elevated
    case severe

    static func < (lhs: WeatherAlertSeverity, rhs: WeatherAlertSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var title: String {
        switch self {
        case .calm:
            return "Ruhig"
        case .advisory:
            return "Hinweis"
        case .elevated:
            return "Achtung"
        case .severe:
            return "Warnung"
        }
    }

    var tint: Color {
        switch self {
        case .calm:
            return DesignTokens.wind
        case .advisory:
            return DesignTokens.hazySun
        case .elevated:
            return DesignTokens.uv
        case .severe:
            return DesignTokens.airQualityVeryPoor
        }
    }
}

private struct WeatherAlertItem: Identifiable {
    let id: String
    let severity: WeatherAlertSeverity
    let title: String
    let detail: String
    let metric: String
    let symbolName: String
    let tint: Color
}

private struct WeatherAlertSummary {
    let items: [WeatherAlertItem]

    var primarySeverity: WeatherAlertSeverity {
        items.map(\.severity).max() ?? .calm
    }

    var tint: Color {
        items.first(where: { $0.severity == primarySeverity })?.tint ?? primarySeverity.tint
    }

    var symbolName: String {
        items.first(where: { $0.severity == primarySeverity })?.symbolName ?? "checkmark.seal"
    }

    var pillTitle: String {
        guard !items.isEmpty else { return "Lage" }
        if items.count == 1 {
            return items[0].title
        }
        return "\(items.count) Hinweise"
    }

    var headline: String {
        guard !items.isEmpty else { return "Ruhige Wetterlage." }
        if primarySeverity == .severe {
            return "Draußen genauer planen."
        }
        return "Wetterlage im Blick behalten."
    }

    var detail: String {
        guard let primary = items.first(where: { $0.severity == primarySeverity }) ?? items.first else {
            return "Aus den Forecastdaten ergeben sich gerade keine markanten Hinweise."
        }
        return primary.detail
    }

    var severeCount: Int {
        items.filter { $0.severity == .severe }.count
    }

    var elevatedCount: Int {
        items.filter { $0.severity == .elevated }.count
    }

    func containsAlert(with ids: Set<String>) -> Bool {
        items.contains { ids.contains($0.id) }
    }
}

private struct SelectedPollenSnapshot: Identifiable {
    let type: PollenType
    let value: Double?
    let severity: PollenSeverity
    let peak: ResolvedAirQualityMoment?

    var id: String { type.rawValue }
}

@MainActor
private func makeWeatherAlertSummary(for state: WeatherScreenState, model: AppModel) -> WeatherAlertSummary {
    let now = model.clock.now
    let upcomingHours = state.snapshot.hourly
        .sorted { $0.timestamp < $1.timestamp }
        .filter { $0.timestamp >= now && $0.timestamp <= now.addingTimeInterval(12 * 3_600) }
    let today = state.daily.first
    var items: [WeatherAlertItem] = []

    if let thunderHour = upcomingHours.first(where: { [95, 96, 99].contains($0.weatherCode) }) {
        let label = WeatherDateFormatting.hourLabel(for: thunderHour.timestamp, relativeTo: now, timeZone: state.snapshot.timeZone)
        items.append(
            WeatherAlertItem(
                id: "thunderstorm",
                severity: .severe,
                title: "Gewitter",
                detail: "Gewitter ist ab \(label) im kurzfristigen Verlauf enthalten. Draußen lieber mit Schutz und Alternativen planen.",
                metric: label,
                symbolName: "cloud.bolt.rain.fill",
                tint: DesignTokens.storm
            )
        )
    }

    let wetUpcomingHours = upcomingHours.filter {
        $0.precipitation > 0 || $0.precipitationProbability >= 45 || WeatherConditions.isWetWeatherCode($0.weatherCode)
    }
    let peakHourlyPrecipitation = wetUpcomingHours.map(\.precipitation).max() ?? 0
    let maxRollingThreeHourPrecipitation = rollingPrecipitationPeak(hours: wetUpcomingHours, window: 3 * 3_600)
    let peakPrecipitationProbability = wetUpcomingHours.map(\.precipitationProbability).max() ?? 0
    let minutelyWindow = (state.snapshot.minutely15 ?? [])
        .filter { $0.timestamp >= now && $0.timestamp <= now.addingTimeInterval(90 * 60) }
    let minutelyTotalPrecipitation = minutelyWindow.reduce(0) { partial, entry in
        partial + max(entry.precipitation, entry.rain ?? 0)
    }
    let hasHeavyRainCode = wetUpcomingHours.contains { [65, 67, 81, 82].contains($0.weatherCode) }

    if hasHeavyRainCode
        || peakHourlyPrecipitation >= 5
        || maxRollingThreeHourPrecipitation >= 10
        || minutelyTotalPrecipitation >= 8 {
        let amount = max(peakHourlyPrecipitation, maxRollingThreeHourPrecipitation, minutelyTotalPrecipitation)
        items.append(
            WeatherAlertItem(
                id: "heavy-rain",
                severity: .severe,
                title: "Starkregen",
                detail: "Die Niederschlagssignale sind kräftig genug, um Wege, Verkehr und offene Pläne enger zu prüfen.",
                metric: model.formattedPrecipitation(amount),
                symbolName: "cloud.heavyrain.fill",
                tint: DesignTokens.rain
            )
        )
    } else if peakHourlyPrecipitation >= 2.2
        || maxRollingThreeHourPrecipitation >= 5
        || minutelyTotalPrecipitation >= 3
        || (peakPrecipitationProbability >= 75 && !wetUpcomingHours.isEmpty) {
        let amount = max(peakHourlyPrecipitation, maxRollingThreeHourPrecipitation, minutelyTotalPrecipitation)
        items.append(
            WeatherAlertItem(
                id: "rain",
                severity: .elevated,
                title: "Kräftiger Regen",
                detail: "Regen ist im Verlauf deutlich genug, dass trockene Zeitfenster wichtiger werden.",
                metric: amount > 0 ? model.formattedPrecipitation(amount) : "\(Int(peakPrecipitationProbability.rounded())) %",
                symbolName: "cloud.rain.fill",
                tint: DesignTokens.rain
            )
        )
    }

    let peakWind = upcomingHours.map(\.windSpeed).max() ?? state.current.windSpeed
    if peakWind >= 62 {
        items.append(
            WeatherAlertItem(
                id: "storm",
                severity: .severe,
                title: "Sturm",
                detail: "Der Wind kann in den nächsten Stunden sehr markant werden.",
                metric: model.formattedWindSpeed(peakWind),
                symbolName: "wind",
                tint: DesignTokens.storm
            )
        )
    } else if peakWind >= 45 {
        items.append(
            WeatherAlertItem(
                id: "wind",
                severity: .elevated,
                title: "Starker Wind",
                detail: "Offene Wege und Wasserlagen können deutlich zugig werden.",
                metric: model.formattedWindSpeed(peakWind),
                symbolName: "wind",
                tint: DesignTokens.wind
            )
        )
    }

    let maxTemperature = max(today?.temperatureMax ?? state.current.temperature, upcomingHours.map(\.temperature).max() ?? state.current.temperature)
    if maxTemperature >= 35 {
        items.append(
            WeatherAlertItem(
                id: "heat",
                severity: .severe,
                title: "Hitze",
                detail: "Der Tag erreicht eine sehr hohe Temperatur. Schatten, Wasser und Pausen werden wichtiger.",
                metric: model.formattedTemperature(maxTemperature, includesUnit: true),
                symbolName: "thermometer.sun.fill",
                tint: DesignTokens.uv
            )
        )
    } else if maxTemperature >= 30 {
        items.append(
            WeatherAlertItem(
                id: "warm",
                severity: .elevated,
                title: "Heiß",
                detail: "Die Wärme liegt deutlich über dem angenehmen Bereich.",
                metric: model.formattedTemperature(maxTemperature, includesUnit: true),
                symbolName: "thermometer.sun",
                tint: DesignTokens.hazySun
            )
        )
    }

    let minTemperature = min(today?.temperatureMin ?? state.current.temperature, upcomingHours.map(\.temperature).min() ?? state.current.temperature)
    if minTemperature <= -3 {
        items.append(
            WeatherAlertItem(
                id: "hard-frost",
                severity: .severe,
                title: "Frost",
                detail: "Es kann spürbar frieren. Pflanzen, glatte Stellen und frühe Wege verdienen Aufmerksamkeit.",
                metric: model.formattedTemperature(minTemperature, includesUnit: true),
                symbolName: "snowflake",
                tint: DesignTokens.frost
            )
        )
    } else if minTemperature <= 0 {
        items.append(
            WeatherAlertItem(
                id: "frost",
                severity: .elevated,
                title: "Frost möglich",
                detail: "Die Temperatur kratzt am Gefrierpunkt.",
                metric: model.formattedTemperature(minTemperature, includesUnit: true),
                symbolName: "snowflake",
                tint: DesignTokens.frost
            )
        )
    }

    let maxUV = max(today?.uvIndexMax ?? 0, upcomingHours.compactMap(\.uvIndex).max() ?? state.current.uvIndex ?? 0)
    if maxUV >= 8 {
        items.append(
            WeatherAlertItem(
                id: "uv-high",
                severity: .severe,
                title: "UV sehr hoch",
                detail: "Die Sonne kann schnell belasten. Sonnencreme und Schatten sind heute kein Extra.",
                metric: formattedHomeUVIndex(maxUV),
                symbolName: "sun.max.fill",
                tint: DesignTokens.uv
            )
        )
    } else if maxUV >= 6 {
        items.append(
            WeatherAlertItem(
                id: "uv",
                severity: .elevated,
                title: "UV erhöht",
                detail: "Die UV-Belastung ist deutlich genug für Schutz in der Mittagszeit.",
                metric: formattedHomeUVIndex(maxUV),
                symbolName: "sun.max",
                tint: DesignTokens.uv
            )
        )
    }

    if model.showsPollen,
       let pollenAlert = pollenWarningItem(state: state, selectedTypes: model.orderedSelectedPollenTypes) {
        items.append(pollenAlert)
    }

    return WeatherAlertSummary(
        items: items.sorted {
            if $0.severity == $1.severity {
                return $0.title < $1.title
            }
            return $0.severity > $1.severity
        }
    )
}

private func formattedHomeUVIndex(_ value: Double) -> String {
    if abs(value.rounded() - value) < 0.05 {
        return "\(Int(value.rounded()))"
    }

    return String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",")
}

private func rollingPrecipitationPeak(hours: [HourlyForecastEntry], window: TimeInterval) -> Double {
    guard !hours.isEmpty else { return 0 }
    let sorted = hours.sorted { $0.timestamp < $1.timestamp }

    return sorted.map { start in
        sorted
            .filter { $0.timestamp >= start.timestamp && $0.timestamp < start.timestamp.addingTimeInterval(window) }
            .reduce(0) { $0 + max(0, $1.precipitation) }
    }
    .max() ?? 0
}

private func pollenWarningItem(
    state: WeatherScreenState,
    selectedTypes: [PollenType]
) -> WeatherAlertItem? {
    guard !selectedTypes.isEmpty else { return nil }

    let candidates = selectedTypes.compactMap { type -> (type: PollenType, value: Double, severity: PollenSeverity)? in
        let currentValue = state.airQualityCurrent?.pollenValue(for: type)
        let peakValue = state.airQualityHourly.compactMap { $0.pollenValue(for: type) }.max()
        let value = max(currentValue ?? 0, peakValue ?? 0)
        let severity = type.severity(for: value)
        guard severity == .high else { return nil }
        return (type, value, severity)
    }

    guard let strongest = candidates.max(by: { $0.value < $1.value }) else { return nil }

    return WeatherAlertItem(
        id: "pollen-\(strongest.type.rawValue)",
        severity: .elevated,
        title: "\(strongest.type.title) stark",
        detail: "Die Pollenbelastung kann heute spürbar werden.",
        metric: strongest.severity.title,
        symbolName: "leaf.fill",
        tint: strongest.severity.tint
    )
}

struct HomeView: View {
    @Bindable var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private static let heroEffectVisibilityThreshold: CGFloat = 320
    private static let heroBlurTransitionHeight: CGFloat = 240
    private static let heroEffectContentMinY: CGFloat = 0.08
    private static let heroEffectContentMaxY: CGFloat = 0.72
    @State private var isSettingsSheetPresented = false
    @State private var isAirQualitySheetPresented = false
    @State private var isPrecipitationSheetPresented = false
    @State private var isWeatherAlertSheetPresented = false
    @State private var isRainNowcastSheetPresented = false
    @State private var isUVSheetPresented = false
    @State private var isSunSheetPresented = false
    @State private var isMoonSheetPresented = false
    @State private var selectedFutureDay: ResolvedDailyForecast?
    @State private var selectedMetricDetail: HomeMetricDetail?
    @State private var heroTiltController = HeroTiltController()
    @State private var homeScrollOffset: CGFloat = 0

    private struct DashboardLayout {
        let stackSpacing: CGFloat
        let heroBottomSpacing: CGFloat
        let rowSpacing: CGFloat
        let contentScale: CGFloat
        let bannerHeight: CGFloat
        let heroHeight: CGFloat
        let upperRowHeight: CGFloat
        let lowerRowHeight: CGFloat
    }

    private var hasPresentedOverlay: Bool {
        isSettingsSheetPresented
        || isAirQualitySheetPresented
        || isPrecipitationSheetPresented
        || isWeatherAlertSheetPresented
        || isRainNowcastSheetPresented
        || isUVSheetPresented
        || isSunSheetPresented
        || isMoonSheetPresented
        || selectedFutureDay != nil
        || selectedMetricDetail != nil
    }

    private var heroEffectsAreEnabled: Bool {
        shouldRunHeroEffects(in: scenePhase)
    }

    private var currentWeatherPaperPalette: WeatherPaperPalette {
        guard let state = model.weatherState else {
            return DesignTokens.defaultWeatherPaperPalette
        }

        return weatherPaperPalette(for: state)
    }

    private func weatherPaperPalette(for state: WeatherScreenState) -> WeatherPaperPalette {
        let weatherCode = heroWeatherCode(for: state)

        return DesignTokens.weatherPaperPalette(
            weatherCode: weatherCode,
            isDay: heroWeatherIsDay(for: state),
            rainIntensity: heroRainIntensity(for: state, weatherCode: weatherCode)
        )
    }

    var body: some View {
        let paperPalette = currentWeatherPaperPalette

        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(.clear)
                    .paperBackground()
                    .ignoresSafeArea()

                content(for: proxy)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
        .environment(\.weatherPaperPalette, paperPalette)
        .background {
            ShakeResponder {
                presentSettingsSheet()
            }
        }
        .sheet(isPresented: $isSettingsSheetPresented) {
            SettingsSheet(model: model)
                .weatherSheetChrome(paperPalette)
                .presentationDetents([.large])
                .presentationContentInteraction(.scrolls)
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $isAirQualitySheetPresented) {
            AirQualitySheet(model: model)
                .weatherSheetChrome(paperPalette)
                .presentationDetents([.fraction(0.75)])
                .presentationContentInteraction(.scrolls)
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $isPrecipitationSheetPresented) {
            PrecipitationSheet(model: model)
                .weatherSheetChrome(paperPalette)
                .presentationDetents([.fraction(0.75)])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $isWeatherAlertSheetPresented) {
            WeatherAlertSheet(model: model)
                .weatherSheetChrome(paperPalette)
                .presentationDetents([.fraction(0.68)])
                .presentationContentInteraction(.scrolls)
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $isRainNowcastSheetPresented) {
            RainNowcastSheet(model: model)
                .weatherSheetChrome(paperPalette)
                .presentationDetents([.fraction(0.62)])
                .presentationContentInteraction(.scrolls)
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $isUVSheetPresented) {
            UVSheet(model: model)
                .weatherSheetChrome(paperPalette)
                .presentationDetents([.fraction(0.65)])
                .presentationContentInteraction(.scrolls)
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $isSunSheetPresented) {
            SunSheet(model: model)
                .weatherSheetChrome(paperPalette)
                .presentationDetents([.fraction(0.65)])
                .presentationContentInteraction(.scrolls)
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $isMoonSheetPresented) {
            MoonSheet(model: model)
                .weatherSheetChrome(paperPalette)
                .presentationDetents([.fraction(0.8)])
                .presentationContentInteraction(.scrolls)
                .presentationDragIndicator(.hidden)
        }
        .sheet(item: $selectedFutureDay) { day in
            DayForecastDetailSheet(model: model, day: day)
                .weatherSheetChrome(paperPalette)
                .presentationDetents([.fraction(0.75)])
                .presentationContentInteraction(.scrolls)
                .presentationDragIndicator(.hidden)
        }
        .sheet(item: $selectedMetricDetail) { detail in
            HomeMetricDetailSheet(model: model, detail: detail)
                .weatherSheetChrome(paperPalette)
                .presentationDetents([.fraction(0.65)])
                .presentationDragIndicator(.hidden)
        }
        .dismissalHaptic(isPresented: isSettingsSheetPresented)
        .dismissalHaptic(isPresented: isAirQualitySheetPresented)
        .dismissalHaptic(isPresented: isPrecipitationSheetPresented)
        .dismissalHaptic(isPresented: isWeatherAlertSheetPresented)
        .dismissalHaptic(isPresented: isRainNowcastSheetPresented)
        .dismissalHaptic(isPresented: isUVSheetPresented)
        .dismissalHaptic(isPresented: isSunSheetPresented)
        .dismissalHaptic(isPresented: isMoonSheetPresented)
        .dismissalHaptic(item: selectedFutureDay?.id)
        .dismissalHaptic(item: selectedMetricDetail)
        .onAppear {
            updateHeroTiltMonitoring(for: scenePhase)
        }
        .onChange(of: scenePhase) { _, newPhase in
            updateHeroTiltMonitoring(for: newPhase)
        }
        .onChange(of: hasPresentedOverlay) { _, _ in
            updateHeroTiltMonitoring(for: scenePhase)
        }
        .onChange(of: model.reducesMotionEffects) { _, _ in
            updateHeroTiltMonitoring(for: scenePhase)
        }
        .onChange(of: reduceMotion) { _, _ in
            updateHeroTiltMonitoring(for: scenePhase)
        }
        .onDisappear {
            heroTiltController.stop()
        }
    }

    private func presentSettingsSheet() {
        guard !hasPresentedOverlay else { return }
        HapticManager.lightImpact()
        isSettingsSheetPresented = true
    }

    private var homeMotionIsReduced: Bool {
        reduceMotion || model.reducesMotionEffects
    }

    private var heroInteractionOffset: CGSize {
        guard heroEffectsAreEnabled else { return .zero }
        return clampedHeroInteractionOffset(heroTiltController.offset)
    }

    private func updateHeroTiltMonitoring(for phase: ScenePhase) {
        guard shouldRunHeroEffects(in: phase) else {
            heroTiltController.stop()
            return
        }

        heroTiltController.start()
    }

    private func shouldRunHeroEffects(in phase: ScenePhase) -> Bool {
        phase == .active
            && !hasPresentedOverlay
            && homeScrollOffset < Self.heroEffectVisibilityThreshold
            && !homeMotionIsReduced
    }

    @ViewBuilder
    private func content(for proxy: GeometryProxy) -> some View {
        let topPadding = homeContentTopPadding
        let bottomPadding = max(420, proxy.safeAreaInsets.bottom + 360)
        let heroHeight = firstViewportHeroHeight(for: proxy)
        let cardsLandingTopInset = cardsSnapLandingTopInset(for: proxy)

        if let state = model.weatherState {
            let palette = weatherPaperPalette(for: state)

            ZStack(alignment: .top) {
                heroOverscrollBackground(
                    height: heroHeight + proxy.safeAreaInsets.top + 160,
                    palette: palette
                )

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        GeometryReader { geometry in
                            Color.clear
                                .preference(
                                    key: HomeScrollOffsetPreferenceKey.self,
                                    value: max(0, -geometry.frame(in: .named("home-scroll")).minY)
                                )
                        }
                        .frame(height: 0)

                        editorialHeroSection(
                            state,
                            heroHeight: heroHeight,
                            proxy: proxy,
                            palette: palette
                        )
                        .zIndex(1)

                        editorialCardsSection(
                            state,
                            proxy: proxy,
                            bottomPadding: bottomPadding
                        )
                        .zIndex(0)
                    }
                }
                .scrollTargetBehavior(
                    HeroCardsSnapScrollTargetBehavior(
                        heroHeight: heroHeight,
                        landingTopInset: cardsLandingTopInset
                    )
                )
                .fastScrollDeceleration()
                .coordinateSpace(name: "home-scroll")
                .ignoresSafeArea(edges: [.top, .bottom])
                .onPreferenceChange(HomeScrollOffsetPreferenceKey.self) { value in
                    homeScrollOffset = value
                    updateHeroTiltMonitoring(for: scenePhase)
                }
            }
            .ignoresSafeArea(edges: [.top, .bottom])
        } else {
            emptyCard
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, 16)
                .padding(.top, topPadding)
                .padding(.bottom, bottomPadding)
        }
    }

    private var homeContentTopPadding: CGFloat { 0 }

    private func heroOverscrollBackground(
        height: CGFloat,
        palette: WeatherPaperPalette
    ) -> some View {
        palette.heroGradient
        .frame(maxWidth: .infinity)
        .frame(height: height, alignment: .top)
        .allowsHitTesting(false)
    }

    private func heroScrollMotionProgress(for heroHeight: CGFloat) -> CGFloat {
        guard !homeMotionIsReduced else { return 0 }

        let travel = max(heroHeight * 0.16, 110)
        return min(max(homeScrollOffset / travel, 0), 1)
    }

    private func firstViewportHeroHeight(for proxy: GeometryProxy) -> CGFloat {
        let safeAreaAdjustedHeight = proxy.size.height
            + proxy.safeAreaInsets.top
            + proxy.safeAreaInsets.bottom
        return max(proxy.size.height, safeAreaAdjustedHeight)
    }

    private func cardsSnapLandingTopInset(for _: GeometryProxy) -> CGFloat {
        0
    }

    private var statusRibbonHeroGap: CGFloat { 12 }

    private var statusRibbonTopSpacing: CGFloat { 8 }

    private var statusRibbonRevealDistance: CGFloat { 64 }

    private func statusRibbonRestingTop(for heroHeight: CGFloat) -> CGFloat {
        homeContentTopPadding + heroHeight + statusRibbonHeroGap
    }

    private func floatingStickyStatusRibbon(
        _ state: WeatherScreenState,
        safeAreaTop: CGFloat,
        heroHeight: CGFloat
    ) -> some View {
        let stickyTop = safeAreaTop + statusRibbonTopSpacing
        let restingTop = statusRibbonRestingTop(for: heroHeight)
        let currentTop = max(stickyTop, restingTop - homeScrollOffset)
        let revealProgress = min(
            max(1 - ((currentTop - stickyTop) / statusRibbonRevealDistance), 0),
            1
        )
        let timeZone = displayTimeZone(for: state)

        return editorialStatusRibbon(state, timeZone: timeZone)
            .padding(.horizontal, 16)
            .padding(.top, currentTop)
            .opacity(revealProgress)
            .allowsHitTesting(revealProgress > 0.45)
    }

    private func heroBottomGlanceBar(_ state: WeatherScreenState) -> some View {
        let barHeight: CGFloat = 88
        let cornerRadius: CGFloat = 26

        return HStack(alignment: .center, spacing: 8) {
            Button {
                HapticManager.lightImpact()
                selectedMetricDetail = .apparentTemperature
            } label: {
                bottomGlanceItem(
                    symbolName: "thermometer.medium",
                    title: "Gefühlt",
                    value: model.formattedTemperature(state.current.apparentTemperature),
                    tint: DesignTokens.sun
                )
            }

            Button {
                HapticManager.lightImpact()
                isPrecipitationSheetPresented = true
            } label: {
                bottomGlanceItem(
                    symbolName: "cloud.rain.fill",
                    title: "Regen",
                    value: bottomPrecipitationGlanceValue(for: state),
                    tint: DesignTokens.rain
                )
            }

            Button {
                HapticManager.lightImpact()
                selectedMetricDetail = .wind
            } label: {
                bottomGlanceItem(
                    symbolName: "wind",
                    title: "Wind",
                    value: model.formattedWindSpeed(state.current.windSpeed),
                    tint: DesignTokens.wind
                )
            }

            Button {
                HapticManager.lightImpact()
                isUVSheetPresented = true
            } label: {
                bottomGlanceItem(
                    symbolName: "sun.max.fill",
                    title: "UV",
                    value: heroUVValue(for: state),
                    tint: DesignTokens.uv
                )
            }
        }
        .buttonStyle(GentlePressButtonStyle(scale: 0.975, verticalOffset: 1, pressedOpacity: 0.96))
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .frame(height: barHeight)
        .background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(DesignTokens.chromeFill.opacity(0.72))
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(DesignTokens.border.opacity(0.62), lineWidth: 0.8)
        }
        .shadow(color: DesignTokens.shadow.opacity(0.18), radius: 22, y: 10)
        .accessibilityElement(children: .contain)
    }

    private func bottomGlanceItem(
        symbolName: String,
        title: String,
        value: String,
        tint: Color
    ) -> some View {
        VStack(spacing: 7) {
            HStack(spacing: 5) {
                Image(systemName: symbolName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)

                Text(title.uppercased(with: WeatherDateFormatting.germanLocale))
                    .font(DesignTokens.mono(size: 9, weight: .bold))
                    .foregroundStyle(DesignTokens.secondaryText)
                    .tracking(0.8)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
            .frame(maxWidth: .infinity)

            Text(value)
                .font(DesignTokens.mono(size: 15, weight: .bold))
                .foregroundStyle(DesignTokens.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 3)
        .frame(maxWidth: .infinity)
        .frame(height: 70)
        .contentShape(Rectangle())
    }

    private func bottomPrecipitationGlanceValue(for state: WeatherScreenState) -> String {
        if let nowcast = rainNowcastSummary(for: state), nowcast.isRelevant {
            guard let firstWetSample = nowcast.firstWetSample else {
                return model.formattedPrecipitation(nowcast.totalPrecipitation)
            }

            let minutes = max(0, Int((firstWetSample.timestamp.timeIntervalSince(nowcast.now) / 60.0).rounded()))
            if minutes <= 2 {
                return "Jetzt"
            }

            return "\(minutes) Min"
        }

        let expectation = precipitationExpectation(for: state)
        if expectation.expectedAmount < 0.5 {
            return "\(Int(expectation.probability.rounded())) %"
        }

        return model.formattedPrecipitation(expectation.expectedAmount)
    }

    private func editorialHeroSection(
        _ state: WeatherScreenState,
        heroHeight: CGFloat,
        proxy: GeometryProxy,
        palette: WeatherPaperPalette
    ) -> some View {
        let weatherCode = heroWeatherCode(for: state)
        let isDay = heroWeatherIsDay(for: state)
        let heroTemperature = heroTemperature(for: state)
        let descriptor = WeatherConditions.descriptor(
            for: weatherCode,
            isDay: isDay
        )
        let today = state.daily.first
        let alertSummary = weatherAlertSummary(for: state)
        let rainNowcastSummary = rainNowcastSummary(for: state)
        let matchingHeroThemes = matchingHeroThemes(for: state)
        let mantra = heroMantra(
            for: state,
            descriptor: descriptor,
            alertSummary: alertSummary,
            rainNowcastSummary: rainNowcastSummary
        )
        let conditionTint = heroConditionTint(
            weatherCode: weatherCode,
            isDay: isDay
        )
        let moonPhaseKind = MoonPhaseResolver.info(
            for: model.clock.now,
            timeZone: displayTimeZone(for: state)
        ).kind
        let rainIntensity = heroRainIntensity(for: state, weatherCode: weatherCode)
        let usesRainHeroScene = heroUsesRainScene(for: weatherCode)
        let headerToWeatherSpacing = min(max(heroHeight * 0.11, 92), 126)
        let mantraSpacing = min(max(heroHeight * 0.018, 14), 20)
        let briefingTopPadding = heroHeight * Self.heroEffectContentMaxY
        let scrollIndicatorOpacity = max(0, min(1, 1.0 - Double(homeScrollOffset / 28)))
        let scrollMotionProgress = heroScrollMotionProgress(for: heroHeight)
        let sceneParallaxOffset = scrollMotionProgress * 58
        let headerParallaxOffset = -scrollMotionProgress * 24
        let weatherHorizontalOffset: CGFloat = usesRainHeroScene ? -36 : -18
        let weatherParallaxOffset = -10 - scrollMotionProgress * 62
        let briefingParallaxOffset = -scrollMotionProgress * 82

        return ZStack {
            Rectangle()
                .fill(palette.heroGradient)

            HeroWeatherScene(
                weatherCode: weatherCode,
                isDay: isDay,
                moonPhaseKind: moonPhaseKind,
                density: .regular,
                isAnimated: heroEffectsAreEnabled,
                compositionYOffset: usesRainHeroScene ? 0 : -heroHeight * 0.045,
                effectContentMinY: usesRainHeroScene ? 0 : Self.heroEffectContentMinY,
                effectContentMaxY: usesRainHeroScene ? 0.66 : Self.heroEffectContentMaxY,
                interactionOffset: clampedHeroInteractionOffset(heroTiltController.offset),
                cornerRadius: 0,
                rainIntensity: rainIntensity
            )
            .opacity(0.8)
            .scaleEffect(1 + scrollMotionProgress * 0.055, anchor: .top)
            .offset(y: sceneParallaxOffset)
            .blur(radius: homeScrollOffset * 0.095)
            .allowsHitTesting(false)

            heroBottomBlurTransition(
                tint: conditionTint,
                height: Self.heroBlurTransitionHeight,
                palette: palette
            )
            .frame(height: Self.heroBlurTransitionHeight)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .offset(y: Self.heroBlurTransitionHeight * 0.4)
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("WETTERBLATT")
                            .font(DesignTokens.mono(size: 9, weight: .bold))
                            .tracking(3)
                            .foregroundStyle(DesignTokens.secondaryText)

                        HStack(spacing: 6) {
                            if model.activePlaceSelection == .currentLocation {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(conditionTint)
                            }

                            Text(displayPlaceName)
                                .font(DesignTokens.serifItalic(size: 24, weight: .bold))
                                .foregroundStyle(DesignTokens.ink)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Text(topBarDateLabel)
                        .font(DesignTokens.mono(size: 10, weight: .medium))
                        .foregroundStyle(DesignTokens.secondaryText)
                        .lineLimit(1)
                }
                .padding(.horizontal, 24)
                .padding(.top, proxy.safeAreaInsets.top + 8)
                .offset(y: headerParallaxOffset)

                Spacer(minLength: 0)
                    .frame(height: headerToWeatherSpacing)

                VStack(spacing: 4) {
                    heroTemperatureDisplayText(heroTemperature, size: 132)
                        .foregroundStyle(DesignTokens.ink)
                        .shadow(color: conditionTint.opacity(0.1), radius: 20)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    VStack(spacing: 9) {
                        Text(descriptor.title.uppercased())
                            .font(DesignTokens.mono(size: 12, weight: .bold))
                            .tracking(2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.74)

                        HStack(spacing: 8) {
                            Button {
                                HapticManager.lightImpact()
                                isWeatherAlertSheetPresented = true
                            } label: {
                                heroAlertPill(alertSummary)
                            }
                            .buttonStyle(GentlePressButtonStyle(scale: 0.97, verticalOffset: 1, pressedOpacity: 0.96))

                            if let rainNowcastSummary, rainNowcastSummary.isRelevant {
                                Button {
                                    HapticManager.lightImpact()
                                    isRainNowcastSheetPresented = true
                                } label: {
                                    heroRainNowcastPill(rainNowcastSummary)
                                }
                                .buttonStyle(GentlePressButtonStyle(scale: 0.97, verticalOffset: 1, pressedOpacity: 0.96))
                            }
                        }
                        .frame(maxWidth: 330)

                        heroHighLowPill(
                            min: today?.temperatureMin ?? state.current.temperature,
                            max: today?.temperatureMax ?? state.current.temperature,
                            size: 10,
                            tint: conditionTint
                        )
                    }
                }
                .offset(x: weatherHorizontalOffset, y: weatherParallaxOffset)
                .scaleEffect(1 - scrollMotionProgress * 0.035, anchor: .center)

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: mantraSpacing) {
                Text(mantra)
                    .font(DesignTokens.serifItalic(size: 28, weight: .bold))
                    .foregroundStyle(DesignTokens.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !matchingHeroThemes.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(matchingHeroThemes) { theme in
                                heroThemePill(theme)
                            }
                        }
                        .padding(.vertical, 1)
                    }
                    .scrollClipDisabled()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, briefingTopPadding)
            .offset(y: briefingParallaxOffset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 9) {
                heroBottomGlanceBar(state)
                    .padding(.horizontal, 14)

                VStack(spacing: 4) {
                    Text("MEHR DETAILS")
                        .font(DesignTokens.mono(size: 8))
                        .foregroundStyle(DesignTokens.tertiaryText)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(conditionTint)
                }
            }
            .opacity(scrollIndicatorOpacity)
            .padding(.bottom, max(10, proxy.safeAreaInsets.bottom * 0.28))
        }
        .frame(height: heroHeight)
    }

    private func heroWeatherCode(for state: WeatherScreenState) -> Int {
        state.daily.first?.weatherCode
            ?? heroWeatherCode(for: todayHourlyEntries(from: state))
            ?? state.current.weatherCode
    }

    private func heroWeatherIsDay(for state: WeatherScreenState) -> Bool {
        state.daily.first == nil ? state.current.isDay : true
    }

    private func heroUsesRainScene(for weatherCode: Int) -> Bool {
        switch weatherCode {
        case 51...57, 61...67, 80...82, 95...99:
            return true
        default:
            return false
        }
    }

    private func heroTemperature(for state: WeatherScreenState) -> Double {
        state.daily.first?.temperatureMax
            ?? todayHourlyEntries(from: state).map(\.temperature).max()
            ?? state.current.temperature
    }

    private func heroRainIntensity(for state: WeatherScreenState, weatherCode: Int) -> Double {
        let now = model.clock.now
        let upcomingHours = state.snapshot.hourly
            .sorted { $0.timestamp < $1.timestamp }
            .filter { entry in
                entry.timestamp >= now && entry.timestamp <= now.addingTimeInterval(6 * 3_600)
            }
        let currentHour = currentHourlyEntry(from: state)
        let chanceValues = upcomingHours.map(\.precipitationProbability)
            + [currentHour?.precipitationProbability, state.daily.first?.precipitationProbabilityMax].compactMap { $0 }
        let peakChance = chanceValues.max() ?? 0
        let peakHourlyAmount = upcomingHours.map(\.precipitation).max()
            ?? currentHour?.precipitation
            ?? 0
        let totalUpcomingAmount = upcomingHours.reduce(0) { $0 + max(0, $1.precipitation) }
        let expectedUpcomingAmount = PrecipitationExpectation.day(from: upcomingHours).expectedAmount
        let minutelyWindow = (state.snapshot.minutely15 ?? [])
            .filter { $0.timestamp >= now && $0.timestamp <= now.addingTimeInterval(90 * 60) }
        let peakMinuteAmount = minutelyWindow
            .map { max($0.precipitation, $0.rain ?? 0) }
            .max() ?? 0
        let minuteTotalAmount = minutelyWindow.reduce(0) { partial, entry in
            partial + max(entry.precipitation, entry.rain ?? 0)
        }

        let codeScore: Double
        switch weatherCode {
        case 51:
            codeScore = 0.16
        case 53, 56:
            codeScore = 0.25
        case 55, 57:
            codeScore = 0.34
        case 61, 80:
            codeScore = 0.38
        case 63, 66, 81:
            codeScore = 0.58
        case 65, 67, 82:
            codeScore = 0.82
        case 95:
            codeScore = 0.74
        case 96, 99:
            codeScore = 0.92
        default:
            codeScore = 0
        }

        let chanceScore = min(max(peakChance / 100, 0), 1)
        let amountScore = max(
            min(max(peakHourlyAmount / 4.0, 0), 1),
            min(max(totalUpcomingAmount / 12.0, 0), 1),
            min(max(expectedUpcomingAmount / 5.0, 0), 1),
            min(max(peakMinuteAmount / 1.8, 0), 1),
            min(max(minuteTotalAmount / 4.0, 0), 1)
        )
        let hasWetSignal = WeatherConditions.isWetWeatherCode(weatherCode)
            || peakChance >= 24
            || amountScore >= 0.08

        guard hasWetSignal else { return 0 }
        return min(1, max(codeScore, chanceScore * 0.34 + amountScore * 0.66))
    }

    private func heroWeatherCode(for hours: [HourlyForecastEntry]) -> Int? {
        hours.max {
            heroWeatherPriority(for: $0.weatherCode) < heroWeatherPriority(for: $1.weatherCode)
        }?.weatherCode
    }

    private func heroWeatherPriority(for code: Int) -> Int {
        switch code {
        case 95, 96, 99:
            return 7
        case 71, 73, 75, 77, 85, 86:
            return 6
        case 65, 67, 80, 81, 82:
            return 5
        case 61, 63, 66:
            return 4
        case 51, 53, 55, 56, 57:
            return 3
        case 45, 48:
            return 2
        case 3:
            return 1
        default:
            return 0
        }
    }

    private func heroBottomBlurTransition(
        tint: Color,
        height: CGFloat,
        palette: WeatherPaperPalette
    ) -> some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .mask(heroTransitionMask)

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: palette.heroBottom.opacity(0.12), location: 0.24),
                    .init(color: palette.heroBottom.opacity(0.48), location: 0.56),
                    .init(color: palette.heroBottom.opacity(0.84), location: 0.82),
                    .init(color: palette.heroBottom, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [
                    .clear,
                    tint.opacity(0.08),
                    DesignTokens.shadow.opacity(0.18),
                    .clear,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .blur(radius: 18)
        }
        .compositingGroup()
        .blur(radius: 6)
        .frame(height: height)
    }

    private var heroTransitionMask: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black.opacity(0.28), location: 0.2),
                .init(color: .black.opacity(0.86), location: 0.58),
                .init(color: .black, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func heroQuickFacts(for state: WeatherScreenState) -> [HeroQuickFact] {
        let today = state.daily.first
        let todayHours = todayHourlyEntries(from: state)
        let apparentTemperature = todayHours.map(\.apparentTemperature).max()
            ?? state.current.apparentTemperature
        let precipitationChance = today?.precipitationProbabilityMax
            ?? todayHours.map(\.precipitationProbability).max()
            ?? currentHourlyEntry(from: state)?.precipitationProbability
            ?? 0
        return [
            HeroQuickFact(
                title: "Gefühlt",
                value: model.formattedTemperature(apparentTemperature),
                accent: DesignTokens.sun
            ),
            HeroQuickFact(
                title: "Regen",
                value: "\(Int(precipitationChance.rounded())) %",
                accent: DesignTokens.rain
            ),
            HeroQuickFact(
                title: "Wind",
                value: model.formattedWindSpeed(todayPeakWind(for: state)),
                accent: DesignTokens.wind
            ),
            HeroQuickFact(
                title: "UV",
                value: heroUVValue(for: state),
                accent: DesignTokens.uv
            ),
        ]
    }

    private func heroUVValue(for state: WeatherScreenState) -> String {
        let todayHours = todayHourlyEntries(from: state)
        let uvIndex = state.daily.first?.uvIndexMax
            ?? todayHours.compactMap(\.uvIndex).max()
            ?? currentUVIndex(for: state)
        guard let uvIndex else { return "—" }
        return formattedUVQuickFactValue(uvIndex)
    }

    private func weatherAlertSummary(for state: WeatherScreenState) -> WeatherAlertSummary {
        makeWeatherAlertSummary(for: state, model: model)
    }

    private func rainNowcastSummary(for state: WeatherScreenState) -> RainNowcastSummary? {
        RainNowcastResolver.summary(for: state, now: model.clock.now)
    }

    private func rainNowcastPillTitle(_ summary: RainNowcastSummary) -> String {
        guard let firstWetSample = summary.firstWetSample else {
            return "Regen \(summary.compactWindowLabel)"
        }
        let minutes = max(0, Int((firstWetSample.timestamp.timeIntervalSince(summary.now) / 60.0).rounded()))

        if minutes <= 2 {
            return "Regen jetzt"
        }

        return "Regen in \(minutes) Min"
    }

    private func todayHourlyEntries(from state: WeatherScreenState) -> [HourlyForecastEntry] {
        let timeZone = displayTimeZone(for: state)
        let calendar = Calendar.weatherCalendar(timeZone: timeZone)
        let referenceDay = state.daily.first?.date ?? model.clock.now

        return state.snapshot.hourly
            .sorted { $0.timestamp < $1.timestamp }
            .filter { calendar.isDate($0.timestamp, inSameDayAs: referenceDay) }
    }

    private func remainingTodayHourlyEntries(from state: WeatherScreenState) -> [HourlyForecastEntry] {
        let timeZone = displayTimeZone(for: state)
        let calendar = Calendar.weatherCalendar(timeZone: timeZone)
        let referenceDay = state.daily.first?.date ?? model.clock.now
        let currentHourStart = calendar.dateInterval(of: .hour, for: model.clock.now)?.start ?? model.clock.now

        return state.snapshot.hourly
            .sorted { $0.timestamp < $1.timestamp }
            .filter {
                calendar.isDate($0.timestamp, inSameDayAs: referenceDay)
                    && $0.timestamp >= currentHourStart
            }
    }

    private func todayPeakWind(for state: WeatherScreenState) -> Double {
        todayHourlyEntries(from: state).map(\.windSpeed).max() ?? state.current.windSpeed
    }

    private func heroTemperatureText(_ value: Double) -> String {
        model.formattedTemperature(value)
    }

    private func heroTemperatureDisplayText(
        _ value: Double,
        size: CGFloat,
        degreeScale: CGFloat = 0.46,
        degreeBaselineOffset: CGFloat = 0.3
    ) -> Text {
        let valueText = Text("\(Int(value.rounded()))")
            .font(DesignTokens.heroFont(size: size))
        let degreeText = Text("°")
            .font(DesignTokens.heroFont(size: size * degreeScale))
            .baselineOffset(size * degreeBaselineOffset)
        return Text("\(valueText)\(degreeText)")
    }

    private func heroTemperatureRangeText(
        min: Double,
        max: Double,
        size: CGFloat
    ) -> Text {
        let separator = Text(" — ")
            .font(DesignTokens.heroFont(size: size))
        return Text(
            "\(heroTemperatureDisplayText(min, size: size))\(separator)\(heroTemperatureDisplayText(max, size: size))"
        )
    }

    private func heroConditionTitle(_ title: String, size: CGFloat) -> some View {
        Text(title.uppercased())
            .font(DesignTokens.mono(size: size, weight: .semibold))
            .foregroundStyle(DesignTokens.ink.opacity(0.92))
            .tracking(2.3)
            .lineLimit(1)
    }

    private func heroAlertPill(_ summary: WeatherAlertSummary) -> some View {
        heroActionPill(
            symbolName: summary.symbolName,
            title: summary.pillTitle,
            tint: summary.tint
        )
    }

    private func heroRainNowcastPill(_ summary: RainNowcastSummary) -> some View {
        heroActionPill(
            symbolName: "cloud.rain.fill",
            title: rainNowcastPillTitle(summary),
            tint: DesignTokens.rain
        )
    }

    private func heroMantra(
        for state: WeatherScreenState,
        descriptor: WeatherConditionDescriptor,
        alertSummary: WeatherAlertSummary,
        rainNowcastSummary: RainNowcastSummary?
    ) -> String {
        if alertSummary.primarySeverity == .severe {
            return "Heute besser vorsichtig planen."
        }

        if rainNowcastSummary?.isRelevant == true {
            return "Es kann bald nass werden."
        }

        if todayPeakWind(for: state) >= 36 {
            return "Es wird spürbar windig."
        }

        let maxTemperature = state.daily.first?.temperatureMax ?? state.current.temperature
        if maxTemperature >= 28 {
            return "Heute wird es ziemlich warm."
        }

        if [0, 1].contains(state.current.weatherCode) {
            return "Heute sieht es freundlich aus."
        }

        return "\(descriptor.title), insgesamt gut planbar."
    }

    private func matchingHeroThemes(for state: WeatherScreenState) -> [HeroThemeRule] {
        model.heroThemes.filter { heroThemeMatches($0, state: state) }
    }

    private func heroThemeMatches(_ theme: HeroThemeRule, state: WeatherScreenState) -> Bool {
        guard !theme.criteria.isEmpty else { return false }
        let results = theme.criteria.map { selection in
            let matches = heroThemeCriterionMatches(selection.criterion, state: state)
            return selection.isNegated ? !matches : matches
        }

        switch theme.matchMode {
        case .all:
            return results.allSatisfy { $0 }
        case .any:
            return results.contains(true)
        }
    }

    private func heroThemeCriterionMatches(_ criterion: HeroThemeCriterion, state: WeatherScreenState) -> Bool {
        let remainingHours = remainingTodayHourlyEntries(from: state)
        let today = state.daily.first

        switch criterion {
        case .rain:
            return precipitationExpectation(for: state).category != .trace
                || rainNowcastSummary(for: state)?.isRelevant == true
        case .heavyRain:
            let peakHourly = remainingHours.map(\.precipitation).max() ?? 0
            let rollingPeak = rollingPrecipitationPeak(hours: remainingHours, window: 3 * 3_600)
            return remainingHours.contains { [65, 67, 81, 82].contains($0.weatherCode) }
                || peakHourly >= 3
                || rollingPeak >= 6
        case .thunderstorm:
            return remainingHours.contains { [95, 96, 99].contains($0.weatherCode) }
        case .strongWind:
            return max(todayPeakWind(for: state), state.current.windSpeed) >= 45
        case .heat:
            let maxTemperature = max(today?.temperatureMax ?? state.current.temperature, remainingHours.map(\.temperature).max() ?? state.current.temperature)
            return maxTemperature >= 30
        case .frost:
            let minTemperature = min(today?.temperatureMin ?? state.current.temperature, remainingHours.map(\.temperature).min() ?? state.current.temperature)
            return minTemperature <= 0
        case .highUV:
            let maxUV = max(today?.uvIndexMax ?? 0, remainingHours.compactMap(\.uvIndex).max() ?? state.current.uvIndex ?? 0)
            return maxUV >= 6
        case .poorAir:
            let currentAQI = state.airQualityCurrent?.europeanAQI
            let peakAQI = state.airQualityHourly.compactMap(\.europeanAQI).max()
            let aqi = max(currentAQI ?? 0, peakAQI ?? 0)
            return EuropeanAQICategory(value: aqi).scalePosition >= 4
        case .pollen:
            guard model.showsPollen else { return false }
            return pollenWarningItem(state: state, selectedTypes: model.orderedSelectedPollenTypes) != nil
        case .fog:
            return [45, 48].contains(state.current.weatherCode)
                || remainingHours.contains { [45, 48].contains($0.weatherCode) }
        case .snow:
            return [71, 73, 75, 77, 85, 86].contains(state.current.weatherCode)
                || remainingHours.contains { [71, 73, 75, 77, 85, 86].contains($0.weatherCode) }
        }
    }

    private func heroActionPill(symbolName: String, title: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbolName)
                .font(.system(size: 9.5, weight: .semibold))
                .imageScale(.small)

            Text(title.uppercased())
                .font(DesignTokens.mono(size: 8.5, weight: .bold))
                .tracking(1.1)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .foregroundStyle(DesignTokens.ink)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(DesignTokens.chromeFill.opacity(0.34))
        .overlay(
            Capsule()
                .stroke(tint.opacity(0.5), lineWidth: 0.9)
        )
        .clipShape(Capsule())
    }

    private func heroThemePill(_ theme: HeroThemeRule) -> some View {
        let tint = Color(
            red: theme.color.red,
            green: theme.color.green,
            blue: theme.color.blue,
            opacity: theme.color.alpha
        )

        return Text(theme.title.uppercased())
            .font(DesignTokens.mono(size: 9, weight: .bold))
            .tracking(1.1)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .foregroundStyle(DesignTokens.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(tint.opacity(0.18))
            .overlay(
                Capsule()
                    .stroke(tint.opacity(0.68), lineWidth: 0.9)
            )
            .clipShape(Capsule())
    }

    private func heroHighLowPill(
        min: Double,
        max: Double,
        size: CGFloat,
        tint: Color
    ) -> some View {
        HStack(spacing: 10) {
            heroHighLowValue(symbolName: "arrow.up", value: max, size: size)
            heroHighLowValue(symbolName: "arrow.down", value: min, size: size)
        }
            .font(DesignTokens.mono(size: size, weight: .semibold))
            .foregroundStyle(DesignTokens.ink)
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(DesignTokens.chromeFill.opacity(0.24))
            .overlay(
                Capsule()
                    .stroke(tint.opacity(0.38), lineWidth: 0.9)
            )
            .clipShape(Capsule())
    }

    private func heroHighLowValue(
        symbolName: String,
        value: Double,
        size: CGFloat
    ) -> some View {
        HStack(spacing: 3) {
            Image(systemName: symbolName)
                .font(.system(size: size * 0.96, weight: .semibold))
                .imageScale(.small)
            Text(model.formattedTemperature(value))
                .tracking(1.1)
        }
    }

    @ViewBuilder
    private func heroQuickFactColumn(_ fact: HeroQuickFact) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text(fact.title)
                .font(DesignTokens.mono(size: 8, weight: .bold))
                .foregroundStyle(fact.accent)
                .tracking(1)
                .multilineTextAlignment(.center)

            Text(fact.value)
                .font(DesignTokens.serif(size: 18, weight: .bold))
                .foregroundStyle(fact.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func futurePreviewRange(for days: [ResolvedDailyForecast]) -> ClosedRange<Double> {
        let minValue = days.map(\.temperatureMin).min() ?? 0
        let maxValue = days.map(\.temperatureMax).max() ?? 1
        return minValue...maxValue
    }

    private func futurePreviewDateLabel(for day: ResolvedDailyForecast) -> String {
        WeatherDateFormatting.shortDayMonth(
            day.date,
            timeZone: model.weatherState?.snapshot.timeZone ?? .current
        )
    }

    private func futurePreviewDayNumberLabel(for day: ResolvedDailyForecast) -> String {
        WeatherDateFormatting.string(
            from: day.date,
            format: "d",
            timeZone: model.weatherState?.snapshot.timeZone ?? .current
        )
    }

    private func futurePreviewMonthLabel(for day: ResolvedDailyForecast) -> String {
        WeatherDateFormatting.string(
            from: day.date,
            format: "MMM",
            timeZone: model.weatherState?.snapshot.timeZone ?? .current
        )
        .replacingOccurrences(of: ".", with: "")
        .uppercased(with: WeatherDateFormatting.germanLocale)
    }

    private func editorialCardsSection(
        _ state: WeatherScreenState,
        proxy: GeometryProxy,
        bottomPadding: CGFloat
    ) -> some View {
        let timeZone = displayTimeZone(for: state)
        let moonPhase = MoonPhaseResolver.info(for: model.clock.now, timeZone: timeZone)

        return VStack(alignment: .leading, spacing: 14) {
            if let banner = bannerText(for: state) {
                OfflineBanner(text: banner)
            }

            futurePreviewCard(state)

            editorialOverviewGridCard(state)

            editorialSunCard(state, timeZone: timeZone)

            editorialBottomPairCard(state, moonPhase: moonPhase)
        }
        .padding(.horizontal, 16)
        .padding(.top, proxy.safeAreaInsets.top + min(max(proxy.size.height * 0.03, 18), 30))
        .padding(.bottom, bottomPadding)
    }

    private func futurePreviewCard(_ state: WeatherScreenState) -> some View {
        let days = Array(state.daily.prefix(7))
        let dailyRange = futurePreviewRange(for: days)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Text("TAGE")
                    .font(DesignTokens.mono(size: 10, weight: .medium))
                    .foregroundStyle(DesignTokens.secondaryText)
                    .tracking(1.8)

                Spacer(minLength: 0)

                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DesignTokens.secondaryText)
            }

            futurePreviewDailyPage(days: days, range: dailyRange)
        }
        .vintageCard()
    }

    private func futurePreviewRow(
        day: ResolvedDailyForecast,
        range: ClosedRange<Double>,
        isLast: Bool
    ) -> some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                futurePreviewDateBadge(for: day)
                    .frame(width: 58, height: 42, alignment: .leading)

                WeatherIconView(weatherCode: day.weatherCode, isDay: true, size: .small)

                TemperatureRangeTrack(
                    min: day.temperatureMin,
                    max: day.temperatureMax,
                    range: range,
                    trackHeight: 8,
                    labelSpacing: 4,
                    labelWidth: 28,
                    labelFontSize: 9,
                    minimumVisibleFraction: 0.1,
                    centersTrackInAvailableHeight: true,
                    valueFormatter: { model.formattedTemperature($0) }
                )
                .frame(maxWidth: .infinity)
                .frame(height: 42, alignment: .center)
            }

            if !isLast {
                Rectangle()
                    .fill(DesignTokens.border.opacity(0.18))
                    .frame(height: 1)
            }
        }
    }

    private func futurePreviewDateBadge(for day: ResolvedDailyForecast) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(day.displayLabel.uppercased(with: WeatherDateFormatting.germanLocale))
                .font(DesignTokens.mono(size: 8, weight: .medium))
                .foregroundStyle(day.isToday ? DesignTokens.sun : DesignTokens.secondaryText)
                .tracking(1.1)
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(futurePreviewDayNumberLabel(for: day))
                    .font(DesignTokens.serif(size: 20, weight: .bold))
                    .foregroundStyle(DesignTokens.ink)
                    .lineLimit(1)

                Text(futurePreviewMonthLabel(for: day))
                    .font(DesignTokens.mono(size: 7, weight: .medium))
                    .foregroundStyle(DesignTokens.tertiaryText)
                    .tracking(1)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(day.displayLabel), \(futurePreviewDateLabel(for: day))")
    }

    @ViewBuilder
    private func futurePreviewDailyPage(
        days: [ResolvedDailyForecast],
        range: ClosedRange<Double>
    ) -> some View {
        if days.isEmpty {
            Text("Noch keine Tagesdaten.")
                .font(DesignTokens.mono(size: 11))
                .foregroundStyle(DesignTokens.secondaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            VStack(spacing: 10) {
                ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                    Button {
                        HapticManager.lightImpact()
                        selectedFutureDay = day
                    } label: {
                        futurePreviewRow(
                            day: day,
                            range: range,
                            isLast: index == days.count - 1
                        )
                    }
                    .buttonStyle(GentlePressButtonStyle(scale: 0.99, verticalOffset: 0.5, pressedOpacity: 0.98))
                    .accessibilityLabel("\(day.displayLabel) im Tagesdetail öffnen")
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    private func editorialStatusRibbon(_ state: WeatherScreenState, timeZone: TimeZone) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text(model.formattedTemperature(state.current.temperature))
                .font(DesignTokens.serif(size: 20, weight: .bold))
                .foregroundStyle(DesignTokens.ink)

            Text(displayPlaceName.uppercased())
                .font(DesignTokens.mono(size: 9, weight: .medium))
                .foregroundStyle(DesignTokens.secondaryText)
                .tracking(1.8)
                .lineLimit(1)

            Spacer(minLength: 10)

            Text(WeatherDateFormatting.time(model.clock.now, timeZone: timeZone))
                .font(DesignTokens.mono(size: 10, weight: .medium))
                .foregroundStyle(DesignTokens.secondaryText)
        }
        .vintageCard()
    }

    private func editorialOverviewGridCard(_ state: WeatherScreenState) -> some View {
        let cardSpacing: CGFloat = 14
        let cellInsets = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)

        return VStack(spacing: cardSpacing) {
            HStack(alignment: .top, spacing: cardSpacing) {
                editorialMetricCell(
                    label: "Niederschlag",
                    value: editorialPrecipitationValue(for: state),
                    detail: precipitationAssessment(for: state),
                    support: precipitationContextText(for: state),
                    accent: DesignTokens.rain,
                    contentInsets: cellInsets
                ) {
                    isPrecipitationSheetPresented = true
                }
                .vintageCard()

                editorialMetricCell(
                    label: "Wind",
                    value: model.formattedWindSpeed(state.current.windSpeed),
                    detail: windAssessment(for: state.current.windSpeed),
                    support: windSupportText(for: state.current.windSpeed),
                    accent: DesignTokens.wind,
                    contentInsets: cellInsets
                ) {
                    selectedMetricDetail = .wind
                }
                .vintageCard()
            }

            HStack(alignment: .top, spacing: cardSpacing) {
                editorialMetricCell(
                    label: "UV",
                    value: uvValue(for: state),
                    detail: uvAssessment(for: state),
                    support: uvProtectionHint(for: state),
                    accent: DesignTokens.uv,
                    contentInsets: cellInsets
                ) {
                    isUVSheetPresented = true
                }
                .vintageCard()

                editorialMetricCell(
                    label: "Gefühlt",
                    value: model.formattedTemperature(state.current.apparentTemperature),
                    detail: feelsLikeReason(for: state),
                    support: apparentTemperatureDeltaText(for: state),
                    accent: heroConditionTint(
                        weatherCode: state.current.weatherCode,
                        isDay: state.current.isDay
                    ),
                    contentInsets: cellInsets
                ) {
                    selectedMetricDetail = .apparentTemperature
                }
                .vintageCard()
            }
        }
    }

    private func editorialMetricCell(
        label: String,
        value: String,
        detail: String,
        support: String?,
        accent: Color,
        contentInsets: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
        action: @escaping () -> Void
    ) -> some View {
        let usesHeadlineStyle = value.contains("\n") || value.count > 12

        return Button {
            HapticManager.lightImpact()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 8) {
                    Text(label.uppercased())
                        .font(DesignTokens.mono(size: 9, weight: .medium))
                        .foregroundStyle(accent)
                        .tracking(1.8)

                    Spacer(minLength: 0)

                    ZStack {
                        Circle()
                            .fill(accent.opacity(0.16))

                        Circle()
                            .fill(accent)
                            .frame(width: 5.5, height: 5.5)
                    }
                    .frame(width: 14, height: 14)
                }

                Text(value)
                    .font(
                        usesHeadlineStyle
                            ? DesignTokens.serifItalic(size: 25, weight: .bold)
                            : DesignTokens.serif(size: 30, weight: .bold)
                    )
                    .foregroundStyle(accent)
                    .lineLimit(usesHeadlineStyle ? 2 : 1)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.7)

                Text(detail)
                    .font(DesignTokens.mono(size: 10))
                    .foregroundStyle(DesignTokens.tertiaryText)
                    .lineSpacing(-0.4)
                    .lineLimit(3)

                if let support, !support.isEmpty {
                    Text(support)
                        .font(DesignTokens.mono(size: 9))
                        .foregroundStyle(DesignTokens.secondaryText)
                        .lineSpacing(-0.4)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 152, alignment: .topLeading)
            .padding(contentInsets)
            .contentShape(Rectangle())
        }
        .buttonStyle(GentlePressButtonStyle())
    }

    private var editorialHorizontalDivider: some View {
        Rectangle()
            .fill(DesignTokens.border.opacity(0.74))
            .frame(height: 0.8)
    }

    private var editorialVerticalDivider: some View {
        Rectangle()
            .fill(DesignTokens.border.opacity(0.74))
            .frame(width: 0.8)
    }

    private func editorialSunCard(_ state: WeatherScreenState, timeZone: TimeZone) -> some View {
        let context = homeSunContext(for: state)

        return Button {
            HapticManager.lightImpact()
            isSunSheetPresented = true
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("SONNE")
                        .font(DesignTokens.mono(size: 9, weight: .medium))
                        .foregroundStyle(DesignTokens.secondaryText)
                        .tracking(1.8)

                    Text("Tag im Bogen.")
                        .font(DesignTokens.serifItalic(size: 26, weight: .bold))
                        .foregroundStyle(DesignTokens.ink)

                    Text(homeSunSummary(for: context, timeZone: timeZone))
                        .font(DesignTokens.mono(size: 10))
                        .foregroundStyle(DesignTokens.tertiaryText)
                        .lineSpacing(-0.5)
                        .lineLimit(2)
                }

                GeometryReader { proxy in
                    let metrics = SunCoursePlotMetrics(size: proxy.size)

                    ZStack(alignment: .topLeading) {
                        Path { path in
                            path.move(to: metrics.dayStart)
                            path.addLine(to: metrics.dayEnd)
                        }
                        .stroke(DesignTokens.border.opacity(0.82), lineWidth: 0.8)

                        if let context {
                            metrics.arcPath(for: context)
                                .stroke(
                                    DesignTokens.border.opacity(0.48),
                                    style: StrokeStyle(lineWidth: 1.4, dash: [5, 5])
                                )

                            if let progress = context.progress {
                                metrics.progressPath(for: context, progress: progress)
                                    .stroke(
                                        LinearGradient(
                                            colors: [DesignTokens.hazySun, DesignTokens.sun],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                                    )

                                SunCourseMarker()
                                    .position(metrics.point(at: progress, for: context))
                            }

                            ForEach(Array([context.sunriseProgress, context.sunsetProgress].enumerated()), id: \.offset) { _, anchor in
                                Circle()
                                    .fill(DesignTokens.secondaryText)
                                    .frame(width: 6, height: 6)
                                    .position(metrics.point(at: anchor, for: context))
                            }
                        }
                    }
                }
                .frame(height: 114)

                HStack(spacing: 0) {
                    editorialSunStat(
                        title: "Aufgang",
                        value: state.daily.first?.sunrise.map { WeatherDateFormatting.time($0, timeZone: timeZone) } ?? "—",
                        alignment: .leading
                    )
                    editorialVerticalDivider
                    editorialSunStat(
                        title: "Tagesmitte",
                        value: context.map { WeatherDateFormatting.time($0.solarNoon, timeZone: timeZone) } ?? "—",
                        alignment: .center
                    )
                    editorialVerticalDivider
                    editorialSunStat(
                        title: "Untergang",
                        value: state.daily.first?.sunset.map { WeatherDateFormatting.time($0, timeZone: timeZone) } ?? "—",
                        alignment: .trailing
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .vintageCard()
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(GentlePressButtonStyle())
    }

    private enum EditorialSunStatAlignment {
        case leading
        case center
        case trailing

        var frameAlignment: Alignment {
            switch self {
            case .leading:
                return .leading
            case .center:
                return .center
            case .trailing:
                return .trailing
            }
        }

        var textAlignment: TextAlignment {
            switch self {
            case .leading:
                return .leading
            case .center:
                return .center
            case .trailing:
                return .trailing
            }
        }
    }

    private func editorialSunStat(
        title: String,
        value: String,
        alignment: EditorialSunStatAlignment = .leading
    ) -> some View {
        VStack(spacing: 5) {
            Text(title.uppercased())
                .font(DesignTokens.mono(size: 8, weight: .medium))
                .foregroundStyle(DesignTokens.secondaryText)
                .tracking(1.6)
                .frame(maxWidth: .infinity, alignment: alignment.frameAlignment)

            Text(value)
                .font(DesignTokens.serif(size: 18, weight: .bold))
                .foregroundStyle(DesignTokens.ink)
                .frame(maxWidth: .infinity, alignment: alignment.frameAlignment)
        }
        .multilineTextAlignment(alignment.textAlignment)
        .frame(maxWidth: .infinity, alignment: alignment.frameAlignment)
        .padding(.horizontal, 12)
    }

    private func editorialBottomPairCard(_ state: WeatherScreenState, moonPhase: MoonPhaseInfo) -> some View {
        let summary = makeAirQualityQuickGlanceSummary(
            state: state,
            showsPollen: model.showsPollen,
            selectedTypes: model.orderedSelectedPollenTypes
        )

        return HStack(spacing: 0) {
            editorialMetricCell(
                label: "Luftqualität",
                value: formattedAQIValue(state.airQualityCurrent?.europeanAQI),
                detail: summary.title.capitalized,
                support: summary.detail,
                accent: summary.tint
            ) {
                isAirQualitySheetPresented = true
            }

            editorialVerticalDivider

            editorialMetricCell(
                label: "Mondphase",
                value: moonPhase.title,
                detail: moonPhase.detail,
                support: "\(Int((moonPhase.illuminationFraction * 100).rounded())) % beleuchtet",
                accent: DesignTokens.moon
            ) {
                isMoonSheetPresented = true
            }
        }
        .vintageCard()
    }

    private func editorialPrecipitationValue(for state: WeatherScreenState) -> String {
        let expectation = precipitationExpectation(for: state)
        if expectation.expectedAmount < 0.5 {
            return "Kaum Regen."
        }

        return model.formattedPrecipitation(expectation.expectedAmount)
    }

    private func windSupportText(for speed: Double) -> String {
        switch speed {
        case ..<12:
            return "Fast ruhig über den Tag."
        case ..<24:
            return "Offene Wege wirken etwas frischer."
        case ..<36:
            return "In freien Lagen konstant spürbar."
        default:
            return "Draußen ist der Wind deutlich spürbar."
        }
    }

    private func apparentTemperatureDeltaText(for state: WeatherScreenState) -> String {
        let delta = state.current.apparentTemperature - state.current.temperature
        if abs(delta) < 0.5 {
            return "Nahe an der gemessenen Luft."
        }

        if delta > 0 {
            return "Etwas wärmer als die Luft."
        }

        return "Etwas kühler als die Luft."
    }

    private func homeSunContext(for state: WeatherScreenState) -> SunDayContext? {
        guard let day = state.daily.first,
              let sunrise = day.sunrise,
              let sunset = day.sunset else {
            return nil
        }

        let daylightDuration = max(sunset.timeIntervalSince(sunrise), 0)
        let solarNoon = sunrise.addingTimeInterval(daylightDuration / 2)
        let calendar = Calendar.weatherCalendar(timeZone: state.snapshot.timeZone)
        let dayStart = calendar.startOfDay(for: day.date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return nil }
        let dayDuration = max(dayEnd.timeIntervalSince(dayStart), 1)
        let now = model.clock.now
        let phase: SunDayContext.Phase
        let progress: Double?

        func dayProgress(for date: Date) -> Double {
            min(max(date.timeIntervalSince(dayStart) / dayDuration, 0), 1)
        }

        let sunriseProgress = dayProgress(for: sunrise)
        let solarNoonProgress = dayProgress(for: solarNoon)
        let sunsetProgress = dayProgress(for: sunset)

        if calendar.isDate(day.date, inSameDayAs: now) {
            if now < sunrise {
                phase = .beforeSunrise
                progress = dayProgress(for: now)
            } else if now > sunset {
                phase = .afterSunset
                progress = dayProgress(for: now)
            } else {
                phase = .daylight
                progress = dayProgress(for: now)
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
            sunriseProgress: sunriseProgress,
            solarNoonProgress: solarNoonProgress,
            sunsetProgress: sunsetProgress,
            progress: progress,
            phase: phase
        )
    }

    private func homeSunSummary(for context: SunDayContext?, timeZone: TimeZone) -> String {
        guard let context else {
            return "Sonnenzeiten werden noch geladen."
        }

        let sunrise = WeatherDateFormatting.time(context.sunrise, timeZone: timeZone)
        let sunset = WeatherDateFormatting.time(context.sunset, timeZone: timeZone)

        switch context.phase {
        case .beforeSunrise:
            return "Aufgang um \(sunrise). Noch \(homeCountdownString(max(context.sunrise.timeIntervalSince(model.clock.now), 0)))."
        case .daylight:
            return "Noch \(homeCountdownString(max(context.sunset.timeIntervalSince(model.clock.now), 0))) bis Untergang."
        case .afterSunset:
            return "Heute offen von \(sunrise) bis \(sunset)."
        case .scheduled:
            return "Zwischen \(sunrise) und \(sunset) liegt der Bogen des Tages."
        }
    }

    private func homeCountdownString(_ interval: TimeInterval) -> String {
        let totalMinutes = max(Int(interval / 60), 0)
        if totalMinutes < 60 {
            return "\(totalMinutes) min"
        }

        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if minutes == 0 {
            return "\(hours) h"
        }

        return "\(hours) h \(minutes) min"
    }

    private func airQualityMetricCard(_ state: WeatherScreenState, rowHeight: CGFloat) -> some View {
        let selectedTypes = model.orderedSelectedPollenTypes
        let summary = makeAirQualityQuickGlanceSummary(
            state: state,
            showsPollen: model.showsPollen,
            selectedTypes: selectedTypes
        )

        return Button {
            HapticManager.lightImpact()
            isAirQualitySheetPresented = true
        } label: {
            MetricCard(
                title: model.showsPollen ? "Pollen & Luft" : "Luftqualität",
                value: model.showsPollen
                    ? summary.title
                    : formattedAQIValue(state.airQualityCurrent?.europeanAQI),
                detail: model.showsPollen ? summary.detail : summary.title,
                secondaryDetail: model.showsPollen
                    ? (selectedTypes.isEmpty ? "Typen im Sheet auswählen." : "\(selectedTypes.count) Typ\(selectedTypes.count == 1 ? "" : "en") im Blick")
                    : aqiScaleText(for: state.airQualityCurrent?.europeanAQI),
                secondaryLineLimit: 2,
                contentHeight: rowHeight,
                timeline: model.showsPollen
                    ? pollenTimelineSamples(state: state, selectedTypes: selectedTypes)
                    : airQualityTimelineSamples(state: state) { $0.europeanAQI },
                timelineAccent: summary.tint,
                timelineBaseline: 0,
                accent: summary.tint,
                showsDisclosureIndicator: true
            )
        }
        .buttonStyle(GentlePressButtonStyle())
    }

    private var pageTopBar: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Wetterblatt")
                    .font(DesignTokens.mono(size: 10, weight: .medium))
                    .foregroundStyle(DesignTokens.secondaryText)

                HStack(alignment: .center, spacing: 5) {
                    if model.activePlaceSelection == .currentLocation {
                        Image(systemName: "location.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DesignTokens.sun)
                    }

                    Text(displayPlaceName)
                        .font(DesignTokens.serif(size: 25, weight: .bold))
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                HStack(spacing: 10) {
                    airQualityQuickGlanceButton
                    calendarButton
                }
            }
        }
    }

    private var airQualityQuickGlanceButton: some View {
        let summary = makeAirQualityQuickGlanceSummary(
            state: model.weatherState,
            showsPollen: model.showsPollen,
            selectedTypes: model.orderedSelectedPollenTypes
        )
        let label = model.showsPollen ? "Pollen" : "Luft"

        return Button {
            HapticManager.lightImpact()
            isAirQualitySheetPresented = true
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(summary.tint.opacity(0.16))

                    Image(systemName: summary.symbolName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(summary.tint)
                }
                .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(DesignTokens.mono(size: 8, weight: .medium))
                        .foregroundStyle(DesignTokens.secondaryText)

                    Text(summary.title)
                        .font(DesignTokens.mono(size: 10, weight: .medium))
                        .foregroundStyle(summary.tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(summary.tint.opacity(0.08))
            .background(DesignTokens.chromeFill)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(summary.tint.opacity(0.52), lineWidth: 0.8))
        }
        .buttonStyle(GentlePressButtonStyle(scale: 0.972, verticalOffset: 1, pressedOpacity: 0.96))
        .accessibilityLabel(model.showsPollen ? "Pollenübersicht öffnen" : "Luftqualitätsübersicht öffnen")
        .accessibilityHint(summary.detail)
    }

    private var calendarButton: some View {
        Button {
            HapticManager.lightImpact()
            selectedFutureDay = model.weatherState?.daily.first
        } label: {
            Image(systemName: "calendar")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DesignTokens.ink)
                .frame(width: 40, height: 40)
                .background(DesignTokens.chromeFill)
                .clipShape(Circle())
                .overlay(Circle().stroke(DesignTokens.border, lineWidth: 0.8))
        }
        .buttonStyle(GentlePressButtonStyle(scale: 0.96, verticalOffset: 1, pressedOpacity: 0.95))
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
        let briefing = heroBriefing(for: state)
        let compactHero = contentScale < 0.9 || cardHeight < 196
        let effectiveCardHeight = max(164, cardHeight)
        let cardCornerRadius: CGFloat = compactHero ? 24 : 28
        let temperatureFontSize: CGFloat = compactHero ? 52 : 62
        let headlineFontSize: CGFloat = compactHero ? 16 : 18
        let detailFontSize: CGFloat = compactHero ? 9.2 : 10
        let weatherCode = heroWeatherCode(for: state)
        let isDay = heroWeatherIsDay(for: state)
        let heroTemperature = heroTemperature(for: state)
        let conditionTint = heroConditionTint(
            weatherCode: weatherCode,
            isDay: isDay
        )
        let moonPhaseKind = MoonPhaseResolver.info(
            for: model.clock.now,
            timeZone: displayTimeZone(for: state)
        ).kind
        let rainIntensity = heroRainIntensity(for: state, weatherCode: weatherCode)

        return ZStack {
            HeroWeatherScene(
                weatherCode: weatherCode,
                isDay: isDay,
                moonPhaseKind: moonPhaseKind,
                density: compactHero ? .compact : .regular,
                isAnimated: heroEffectsAreEnabled,
                compositionYOffset: compactHero ? -4 : -6,
                effectContentMaxY: 0.72,
                interactionOffset: heroInteractionOffset,
                rainIntensity: rainIntensity
            )
            .allowsHitTesting(false)

            LinearGradient(
                colors: [
                    DesignTokens.chromeWash.opacity(0.18),
                    .clear,
                    conditionTint.opacity(compactHero ? 0.10 : 0.13),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .allowsHitTesting(false)
        }
        .overlay(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: compactHero ? 8 : 10) {
                heroTemperatureDisplayText(
                    heroTemperature,
                    size: temperatureFontSize
                )
                    .foregroundStyle(DesignTokens.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                VStack(alignment: .leading, spacing: compactHero ? 4 : 5) {
                    Text(briefing.headline)
                        .font(DesignTokens.serif(size: headlineFontSize, weight: .bold))
                        .foregroundStyle(DesignTokens.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(briefing.detail)
                        .font(DesignTokens.mono(size: detailFontSize, weight: .medium))
                        .foregroundStyle(DesignTokens.tertiaryText)
                        .lineSpacing(compactHero ? -1.0 : -0.8)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: compactHero ? 214 : 250, alignment: .leading)
            .padding(.leading, compactHero ? 18 : 22)
            .padding(.trailing, compactHero ? 20 : 24)
            .padding(.bottom, compactHero ? 16 : 20)
            .background(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [
                        DesignTokens.surface.opacity(0.94),
                        DesignTokens.surface.opacity(0.74),
                        DesignTokens.surface.opacity(0.28),
                        .clear,
                    ],
                    startPoint: .bottomLeading,
                    endPoint: .topTrailing
                )
                .frame(width: compactHero ? 224 : 274, height: compactHero ? 116 : 132)
                .blur(radius: compactHero ? 12 : 14)
                .offset(x: -18, y: 12)
                .allowsHitTesting(false)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .stroke(DesignTokens.border.opacity(0.34), lineWidth: 0.7)
        }
        .overlay(alignment: .topLeading) {
            Capsule()
                .fill(conditionTint.opacity(0.28))
                .frame(width: compactHero ? 34 : 42, height: 4)
                .padding(.top, compactHero ? 14 : 16)
                .padding(.leading, compactHero ? 14 : 16)
        }
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        .ignoresSafeArea(edges: .all)
        .contentShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 6) {
                Text("MEHR DETAILS")
                    .font(DesignTokens.mono(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 10)
        }
        .rotation3DEffect(
            .degrees(Double(-heroInteractionOffset.height / 5.4)),
            axis: (x: 1, y: 0, z: 0),
            perspective: 0.75
        )
        .rotation3DEffect(
            .degrees(Double(heroInteractionOffset.width / 5.0)),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.75
        )
        .shadow(color: DesignTokens.shadow.opacity(0.10), radius: 12, y: 6)
        .frame(maxWidth: .infinity)
        .frame(height: effectiveCardHeight)
    }

    private func heroConditionTint(weatherCode: Int, isDay: Bool) -> Color {
        switch weatherCode {
        case 0...1:
            return isDay ? DesignTokens.sun : DesignTokens.moon
        case 2...3:
            return DesignTokens.hazySun
        case 45...48:
            return DesignTokens.tertiaryText
        case 51...67:
            return DesignTokens.drizzle
        case 71...77, 85...86:
            return DesignTokens.frost
        case 80...82:
            return DesignTokens.rain
        case 95...99:
            return DesignTokens.storm
        default:
            return DesignTokens.ink
        }
    }

    private func clampedHeroInteractionOffset(_ offset: CGSize) -> CGSize {
        CGSize(
            width: min(max(offset.width, -26), 26),
            height: min(max(offset.height, -20), 20)
        )
    }

    private func dashboardContent(_ state: WeatherScreenState, availableHeight: CGFloat) -> some View {
        let banner = bannerText(for: state)
        let layout = dashboardLayout(
            for: availableHeight,
            hasBanner: banner != nil
        )

        return VStack(alignment: .leading, spacing: 0) {
            if let banner {
                OfflineBanner(text: banner)
                    .frame(minHeight: layout.bannerHeight, alignment: .topLeading)
                    .padding(.bottom, layout.stackSpacing)
            }

            heroCard(
                state,
                contentScale: layout.contentScale,
                cardHeight: layout.heroHeight
            )
            .padding(.bottom, layout.heroBottomSpacing)

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
                value: model.formattedTemperature(state.current.apparentTemperature),
                detail: feelsLikeReason(for: state),
                detailLineLimit: 3,
                contentHeight: rowHeight,
                timeline: apparentTemperatureTimeline(for: state),
                timelineAccent: DesignTokens.sun,
                accent: DesignTokens.sun,
                showsDisclosureIndicator: true
            )
        }
        .buttonStyle(GentlePressButtonStyle())
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
                secondaryDetail: precipitationContextText(for: state),
                contentHeight: rowHeight,
                timeline: precipitationTimeline(for: state),
                timelineAccent: DesignTokens.rain,
                timelineLowAccent: DesignTokens.drizzle,
                timelineBaseline: 0,
                timelineCaption: "Erwartete Menge",
                accent: DesignTokens.rain,
                showsDisclosureIndicator: true
            )
        }
        .buttonStyle(GentlePressButtonStyle())
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
        .buttonStyle(GentlePressButtonStyle())
    }

    private func windMetricCard(_ state: WeatherScreenState, rowHeight: CGFloat) -> some View {
        Button {
            HapticManager.lightImpact()
            selectedMetricDetail = .wind
        } label: {
            MetricCard(
                title: "Wind",
                value: model.formattedWindSpeed(state.current.windSpeed),
                detail: windAssessment(for: state.current.windSpeed),
                contentHeight: rowHeight,
                timeline: windTimeline(for: state),
                timelineAccent: DesignTokens.wind,
                timelineLowAccent: DesignTokens.windLow,
                timelineBaseline: 0,
                accent: DesignTokens.wind,
                showsDisclosureIndicator: true
            )
        }
        .buttonStyle(GentlePressButtonStyle())
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
        .buttonStyle(GentlePressButtonStyle())
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
                timelineAccent: DesignTokens.uv,
                timelineBaseline: 0,
                accent: DesignTokens.uv,
                showsDisclosureIndicator: true
            )
        }
        .buttonStyle(GentlePressButtonStyle())
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

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(emptyStateTitle)
                .font(DesignTokens.serif(size: 24))
                .foregroundStyle(DesignTokens.ink)

            Text(emptyStateDetail)
                .font(DesignTokens.mono(size: 11))
                .foregroundStyle(DesignTokens.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .vintageCard()
    }

    private var emptyStateTitle: String {
        switch model.locationAuthorization {
        case .denied, .restricted:
            return "Standortzugriff fehlt"
        default:
            break
        }

        if model.isWaitingForCurrentLocation {
            return "Standort wird vorbereitet"
        }

        if !model.reachability.isConnected {
            return "Noch keine Wetterdaten"
        }

        return "Noch keine Wetteransicht"
    }

    private var emptyStateDetail: String {
        switch model.locationAuthorization {
        case .denied, .restricted:
            return "Erlaube den Standortzugriff in den iOS-Einstellungen, damit Wetterblatt deinen Ort laden kann."
        default:
            break
        }

        if model.isWaitingForCurrentLocation {
            return "Sobald iOS einen Standort liefert, aktualisiert Wetterblatt die Ansicht automatisch."
        }

        if !model.reachability.isConnected {
            return "Für diesen Ort gibt es noch keinen ersten Snapshot. Sobald wieder Verbindung da ist, lädt Wetterblatt automatisch nach."
        }

        return "Zieh nach unten zum Aktualisieren oder versuche es gleich noch einmal."
    }

    private func dashboardLayout(for availableHeight: CGFloat, hasBanner: Bool) -> DashboardLayout {
        let compactHeight = availableHeight < 720
        let stackSpacing: CGFloat = compactHeight ? 8 : 10
        let heroBottomSpacing: CGFloat = compactHeight ? 12 : 14
        let rowSpacing: CGFloat = compactHeight ? 8 : 9
        let baseBannerHeight: CGFloat = hasBanner ? (compactHeight ? 44 : 48) : 0
        let baseHeroHeight: CGFloat = availableHeight
        let baseUpperRowHeight: CGFloat = compactHeight ? 146 : 156
        let baseLowerRowHeight: CGFloat = compactHeight ? 100 : 108
        let baseSpacing = (hasBanner ? stackSpacing : 0) + heroBottomSpacing + rowSpacing * 2
        let baseTotalHeight = baseBannerHeight + baseHeroHeight + (baseUpperRowHeight * 2) + baseLowerRowHeight + baseSpacing
        let scale = availableHeight / max(baseTotalHeight, 1)

        return DashboardLayout(
            stackSpacing: stackSpacing,
            heroBottomSpacing: heroBottomSpacing,
            rowSpacing: rowSpacing,
            contentScale: min(1, scale),
            bannerHeight: baseBannerHeight * scale,
            heroHeight: baseHeroHeight,
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
        model.formattedPrecipitation(precipitationExpectation(for: state).expectedAmount)
    }

    private func precipitationAssessment(for state: WeatherScreenState) -> String {
        precipitationAssessment(for: precipitationExpectation(for: state))
    }

    private func precipitationAssessment(for expectation: PrecipitationExpectation) -> String {
        if expectation.hasHighChanceLowAmountShape {
            return "Hohe Chance, wenig Menge: eher Niesel."
        }

        if expectation.hasLowChanceHighAmountShape {
            return "Mehr Menge möglich, aber eher als Schauer."
        }

        switch expectation.category {
        case .trace:
            return "Kombiniert bleibt das kaum spürbar."
        case .light:
            return "Leichter Regen ist möglich."
        case .wet:
            return "Draußen wird es wahrscheinlich nass."
        case .strong:
            return "Deutlich nasser Tag mit kräftigem Regen."
        }
    }

    private func precipitationContextText(for state: WeatherScreenState) -> String {
        let expectation = precipitationExpectation(for: state)
        return "Menge \(model.formattedPrecipitation(expectation.sourceAmount)) · Chance \(Int(expectation.probability.rounded())) %"
    }

    private func precipitationExpectation(for state: WeatherScreenState) -> PrecipitationExpectation {
        let todayEntries = todayHourlyEntries(from: state)
        let fallbackAmount = currentHourlyEntry(from: state)?.precipitation
            ?? todayEntries.reduce(0) { $0 + max(0, $1.precipitation) }
        let fallbackProbability = state.daily.first?.precipitationProbabilityMax
            ?? currentHourlyEntry(from: state)?.precipitationProbability
            ?? 0

        return PrecipitationExpectation.day(
            from: todayEntries,
            fallbackAmount: fallbackAmount,
            fallbackProbability: fallbackProbability
        )
    }

    private func precipitationAmount(for state: WeatherScreenState) -> Double? {
        let todayEntries = todayHourlyEntries(from: state)

        if !todayEntries.isEmpty {
            return todayEntries.reduce(0) { $0 + max(0, $1.precipitation) }
        }

        return currentHourlyEntry(from: state)?.precipitation
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
        return formattedUVQuickFactValue(uvIndex)
    }

    private func formattedUVQuickFactValue(_ uvIndex: Double) -> String {
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

    private func heroBriefing(for state: WeatherScreenState) -> HeroBriefing {
        let today = state.daily.first
        let remainingHours = remainingTodayHourlyEntries(from: state)
        let precipitationChance = remainingHours.map(\.precipitationProbability).max()
            ?? today?.precipitationProbabilityMax
            ?? currentHourlyEntry(from: state)?.precipitationProbability
            ?? 0
        let precipitationVolume = remainingHours.isEmpty
            ? (currentHourlyEntry(from: state)?.precipitation ?? precipitationAmount(for: state) ?? 0)
            : remainingHours.reduce(0) { $0 + max(0, $1.precipitation) }
        let maxTemperature = remainingHours.map(\.temperature).max()
            ?? today?.temperatureMax
            ?? state.current.apparentTemperature
        let minTemperature = remainingHours.map(\.temperature).min()
            ?? today?.temperatureMin
            ?? state.current.apparentTemperature
        let uvIndex = remainingHours.compactMap(\.uvIndex).max()
            ?? today?.uvIndexMax
            ?? currentUVIndex(for: state)
            ?? 0
        let weatherCode = heroWeatherCode(for: remainingHours) ?? heroWeatherCode(for: state)
        let peakWind = remainingHours.map(\.windSpeed).max() ?? state.current.windSpeed
        let precipitationExpectation = remainingHours.isEmpty
            ? precipitationExpectation(for: state)
            : PrecipitationExpectation.day(
                from: remainingHours,
                fallbackAmount: precipitationVolume,
                fallbackProbability: precipitationChance
            )
        let dryDay = precipitationExpectation.expectedAmount < 0.5 && precipitationChance < 55
        let calmDay = weatherCode <= 3 && precipitationChance < 35 && peakWind < 28
        let adviceLead = remainingDayAdviceLead(for: state)
        let seed = heroBriefingSeed(for: state)

        if weatherCode >= 95 || precipitationExpectation.expectedAmount >= 5 || precipitationChance >= 85 || (precipitationChance >= 70 && peakWind >= 32) {
            return pickHeroBriefing(
                from: [
                    .init(headline: "Heute lieber drinnen bleiben.", detail: "\(adviceLead): kurze Wege, trockene Pausen und keine langen Strecken draußen."),
                    .init(headline: "Plan B für draußen.", detail: "\(adviceLead): draußen nur das Nötigste, lose Sachen lieber reinholen."),
                    .init(headline: "Das wird ungemütlich.", detail: "\(adviceLead): draußen knapp halten und längere Wege ins Trockene legen.")
                ],
                seed: seed
            )
        }

        if isSnowWeatherCode(weatherCode) || maxTemperature < 3 || minTemperature < 1 {
            return pickHeroBriefing(
                from: [
                    .init(headline: "Warm anziehen.", detail: "\(adviceLead): eine warme Schicht einplanen und Wege bündeln."),
                    .init(headline: "Draußen lieber kurz.", detail: "\(adviceLead): kurze Wege sind besser als lange Aufenthalte draußen."),
                    .init(headline: "Kalt, aber machbar.", detail: "\(adviceLead): frische Luft geht, aber nur mit guter Jacke.")
                ],
                seed: seed
            )
        }

        if precipitationChance >= 60 || precipitationExpectation.expectedAmount >= 2 {
            return pickHeroBriefing(
                from: [
                    .init(headline: "Regen einplanen.", detail: "\(adviceLead): Wege bündeln, feste Schuhe anziehen und trockene Pausen nutzen."),
                    .init(headline: "Lieber mit Dach planen.", detail: "\(adviceLead): kurze Wege funktionieren, offene Pläne draußen eher nicht."),
                    .init(headline: "Heute eher nass.", detail: "\(adviceLead): trockene Pausen einbauen und Umwege vermeiden.")
                ],
                seed: seed
            )
        }

        if peakWind >= 35 {
            return pickHeroBriefing(
                from: [
                    .init(headline: "Wind bleibt Thema.", detail: "\(adviceLead): Jacke schließen, freie Ecken meiden und Leichtes draußen sichern."),
                    .init(headline: "Draußen wird es zugig.", detail: "\(adviceLead): zu Fuß geht es okay; Rad und offene Flächen fühlen sich rauer an."),
                    .init(headline: "Windig, aber planbar.", detail: "\(adviceLead): kurz lüften, feste Schichten wählen und lose Sachen sichern.")
                ],
                seed: seed
            )
        }

        if weatherCode <= 2 {
            if maxTemperature >= 24 || uvIndex >= 6 {
                return pickHeroBriefing(
                    from: [
                        .init(headline: "Sonne, aber nicht übertreiben.", detail: "\(adviceLead): Wasser mitnehmen und sonnige Pausen nutzen."),
                        .init(headline: "Gut für draußen.", detail: "\(adviceLead): helle Stunden nutzen, bei direkter Sonne aber Schatten mitdenken."),
                        .init(headline: "Gute Gelegenheit für draußen.", detail: dryDay ? "\(adviceLead): Wege zu Fuß, offene Fenster und Wäsche draußen passen gut." : "\(adviceLead): draußen geht gut, kurze Schauer im Blick behalten.")
                    ],
                    seed: seed
                )
            }

            if minTemperature < 8 {
                return pickHeroBriefing(
                    from: [
                        .init(headline: "Klar, aber frisch.", detail: "\(adviceLead): leichte Jacke mitnehmen; kurze Runde und frische Luft gehen gut."),
                        .init(headline: "Frisch, aber gut draußen.", detail: "\(adviceLead): eine leichte Jacke reicht wahrscheinlich, draußen bleibt es angenehm."),
                        .init(headline: "Trocken und klar.", detail: "\(adviceLead): gut für Besorgungen, eine kurze Runde und einmal richtig lüften.")
                    ],
                    seed: seed
                )
            }

            return pickHeroBriefing(
                from: [
                    .init(headline: "Gutes Wetter für draußen.", detail: dryDay ? "\(adviceLead): zu Fuß gehen, Fenster auf und länger draußen bleiben passt gut." : "\(adviceLead): draußen lohnt sich, nur kurze Schauer im Blick behalten."),
                    .init(headline: "Ruhiger Tag.", detail: "\(adviceLead): wenig zu beachten; alles Normale passt gut."),
                    .init(headline: "Draußen lohnt sich.", detail: "\(adviceLead): Park, Markt oder ein kleiner Umweg passen besser als direkt drinnen bleiben.")
                ],
                seed: seed
            )
        }

        if weatherCode == 3 || weatherCode == 45 || weatherCode == 48 {
            return pickHeroBriefing(
                from: calmDay ? [
                    .init(headline: "Grau, aber gut machbar.", detail: "\(adviceLead): Wege, Erledigungen und kurze Pausen draußen passen."),
                    .init(headline: "Bedeckt, aber brauchbar.", detail: "\(adviceLead): Einkaufen, kurze Runden und Pausen draußen gehen auch ohne Sonne."),
                    .init(headline: "Ruhig, nur ohne viel Sonne.", detail: "\(adviceLead): draußen bleibt es unspektakulär, aber gut genug für kurze Wege.")
                ] : [
                    .init(headline: "Bedeckt, aber okay.", detail: "\(adviceLead): leichte Jacke nehmen und Wege eher einfach planen."),
                    .init(headline: "Grau, aber planbar.", detail: "\(adviceLead): kurze Erledigungen passen besser als lange Pläne draußen."),
                    .init(headline: "Draußen lieber kurz.", detail: "\(adviceLead): vieles geht, aber kompakter und ohne große Sonnenpläne.")
                ],
                seed: seed
            )
        }

        return pickHeroBriefing(
            from: calmDay ? [
                .init(headline: "Ruhiger Resttag.", detail: "\(adviceLead): kurz raus, Luft rein und Erledigungen ohne viel Aufwand machen."),
                .init(headline: "Gut planbar.", detail: "\(adviceLead): Wege, kleine Runden draußen und normale Erledigungen passen gut."),
                .init(headline: "Alltag passt.", detail: "\(adviceLead): genug Ruhe für Erledigungen, Bewegung und frische Luft.")
            ] : [
                .init(headline: "Mit etwas Planung okay.", detail: "\(adviceLead): trockene und ruhige Phasen nutzen, Wege nicht unnötig lang machen."),
                .init(headline: "Heute lieber kompakt.", detail: "\(adviceLead): passende Lücken nutzen, draußen nicht zu viel erzwingen."),
                .init(headline: "Geht, mit kleinen Abstrichen.", detail: "\(adviceLead): Erledigungen und Bewegung sind drin, nur etwas kürzer planen.")
            ],
            seed: seed
        )
    }

    private func remainingDayAdviceLead(for state: WeatherScreenState) -> String {
        let calendar = Calendar.weatherCalendar(timeZone: displayTimeZone(for: state))
        let hour = calendar.component(.hour, from: model.clock.now)

        switch hour {
        case ..<14:
            return "Für den Rest des Tages"
        case 14..<18:
            return "Bis heute Abend"
        case 18..<22:
            return "Für den Abend"
        default:
            return "Für den späten Abend"
        }
    }

    private func pickHeroBriefing(from options: [HeroBriefing], seed: Int) -> HeroBriefing {
        guard !options.isEmpty else {
            return HeroBriefing(headline: "Ruhig und gut planbar.", detail: "Der restliche Tag bleibt gut machbar.")
        }

        let index = Int(seed.magnitude % UInt(options.count))
        return options[index]
    }

    private func heroMoment(for hour: Int) -> HeroMoment {
        switch hour {
        case 5..<8:
            return .earlyMorning
        case 8..<11:
            return .morning
        case 11..<14:
            return .midday
        case 14..<18:
            return .afternoon
        case 18..<22:
            return .evening
        default:
            return .night
        }
    }

    private func heroBriefingSeed(for state: WeatherScreenState) -> Int {
        let calendar = Calendar.weatherCalendar(timeZone: state.snapshot.timeZone)
        let referenceDate = state.daily.first?.date ?? state.current.timestamp
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: referenceDate) ?? 0
        let weatherCode = heroWeatherCode(for: state)
        let high = Int((state.daily.first?.temperatureMax ?? state.current.temperature).rounded())
        let low = Int((state.daily.first?.temperatureMin ?? state.current.temperature).rounded())

        return dayOfYear * 31
            + weatherCode * 11
            + high * 7
            + low * 5
            + state.place.name.count
    }

    private func upcomingHeroHours(for state: WeatherScreenState) -> [ResolvedHourlyForecast] {
        let hours = Array(state.hourly.filter { !$0.isPast }.prefix(6))

        if hours.isEmpty, let currentHour = currentHourlyEntry(from: state) {
            return [currentHour]
        }

        return hours
    }

    private func isSnowWeatherCode(_ code: Int) -> Bool {
        switch code {
        case 71, 73, 75, 77, 85, 86:
            return true
        default:
            return false
        }
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

        let historyHourCount = 2
        let futureHourCount = 8
        let activeIndex = sortedEntries.lastIndex(where: { $0.timestamp <= model.clock.now }) ?? 0
        let activeTimestamp = sortedEntries[activeIndex].timestamp

        // Keep the dashboard card sparklines centered on the current forecast hour.
        let startIndex = max(activeIndex - historyHourCount, 0)
        let endIndex = min(activeIndex + futureHourCount + 1, sortedEntries.count)

        return (Array(sortedEntries[startIndex..<endIndex]), activeTimestamp)
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
        timelineSamples(for: state) {
            PrecipitationExpectation.weightedAmount(
                precipitation: $0.precipitation,
                probability: $0.precipitationProbability
            )
        }
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

private struct HomeScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private extension View {
    func fastScrollDeceleration() -> some View {
        background(FastScrollDecelerationConfigurator())
    }
}

private struct FastScrollDecelerationConfigurator: UIViewRepresentable {
    private static let decelerationRate = UIScrollView.DecelerationRate(rawValue: 0.955)

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        DispatchQueue.main.async {
            configureScrollView(from: view)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            configureScrollView(from: uiView)
        }
    }

    private func configureScrollView(from view: UIView) {
        var candidate = view.superview
        while let current = candidate {
            if let scrollView = current as? UIScrollView {
                scrollView.decelerationRate = Self.decelerationRate
                scrollView.delaysContentTouches = false
                return
            }
            candidate = current.superview
        }
    }
}

private struct HeroCardsSnapScrollTargetBehavior: ScrollTargetBehavior {
    let heroHeight: CGFloat
    let landingTopInset: CGFloat

    private let heroExitVelocityThreshold: CGFloat = 1.5
    private let snapVelocityThreshold: CGFloat = 18
    private let snapReturnThreshold: CGFloat = 0.68

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        guard context.axes.contains(.vertical), heroHeight > 0 else { return }

        let maximumOffset = max(context.contentSize.height - context.containerSize.height, 0)
        let cardsOffset = min(max(heroHeight - landingTopInset, 0), maximumOffset)
        guard cardsOffset > 0 else { return }

        let originalY = context.originalTarget.rect.minY
        let proposedY = target.rect.minY
        let velocityY = context.velocity.dy
        let startedInHero = originalY < cardsOffset * 0.92
        let proposedBetweenHeroAndCards = proposedY > 0 && proposedY < cardsOffset

        if startedInHero {
            target.rect.origin.y = proposedY > 1 || velocityY > heroExitVelocityThreshold ? cardsOffset : 0
            target.anchor = .top
            return
        }

        guard proposedBetweenHeroAndCards else { return }

        if velocityY < -snapVelocityThreshold {
            target.rect.origin.y = 0
        } else if velocityY > snapVelocityThreshold {
            target.rect.origin.y = cardsOffset
        } else if proposedY < cardsOffset * snapReturnThreshold {
            target.rect.origin.y = 0
        } else {
            target.rect.origin.y = cardsOffset
        }

        target.anchor = .top
    }
}

private struct MoonPhaseBadge: View {
    let kind: MoonPhaseKind

    var body: some View {
        MoonPhaseIconView(kind: kind)
            .frame(width: 11, height: 11)
    }
}

private struct MoonMonthEntry: Identifiable {
    var id: Date { date }

    let date: Date
    let day: Int
    let info: MoonPhaseInfo
    let isToday: Bool
}

private struct AirQualitySheet: View {
    @Bindable var model: AppModel
    @Environment(\.weatherPaperPalette) private var palette
    @State private var isScaleSheetPresented = false
    @State private var focusedPollenType: PollenType?

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.clear)
                .paperBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    if let state = model.weatherState {
                        content(state)
                    } else {
                        placeholder
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 36)
            }
        }
        .sheet(isPresented: $isScaleSheetPresented) {
            AirQualityScaleSheet(currentAQI: model.weatherState?.airQualityCurrent?.europeanAQI)
                .weatherSheetChrome(palette)
                .presentationDetents([.fraction(0.56)])
                .presentationContentInteraction(.scrolls)
                .presentationDragIndicator(.hidden)
        }
        .dismissalHaptic(isPresented: isScaleSheetPresented)
        .onChange(of: model.orderedSelectedPollenTypes) { _, selectedTypes in
            guard let focusedType = focusedPollenType, !selectedTypes.contains(focusedType) else { return }
            focusedPollenType = nil
        }
    }

    @ViewBuilder
    private func content(_ state: WeatherScreenState) -> some View {
        let selectedTypes = model.orderedSelectedPollenTypes
        let showsPollen = model.showsPollen
        let chartFocusedPollenType = focusedPollenType.flatMap { type in
            selectedTypes.contains(type) ? type : nil
        }
        let chartPollenTypes = chartFocusedPollenType.map { [$0] } ?? selectedTypes
        let summary = makeAirQualityQuickGlanceSummary(
            state: state,
            showsPollen: showsPollen,
            selectedTypes: selectedTypes
        )
        let pollenEntries = selectedPollenSnapshots(state: state, selectedTypes: selectedTypes)
        let pollenChartData = pollenChartEntries(state: state, selectedTypes: chartPollenTypes)
        let aqiChartData = airQualityChartEntries(
            state: state,
            value: { $0.europeanAQI },
            formattedValue: { "\(Int($0.rounded())) AQI" },
            secondaryFormattedValue: { EuropeanAQICategory(value: $0).compactScaleDescription }
        )
        let headline = airQualityHeadline(
            summary: summary,
            currentAQI: state.airQualityCurrent?.europeanAQI,
            showsPollen: showsPollen
        )

        WeatherSheetHeader(
            label: showsPollen ? "Pollen & Luft" : "Luftqualität",
            headline: headline,
            summary: summary.detail,
            accent: summary.tint
        )

        if !state.isConnected {
            WeatherSheetSupportingNote(
                systemImage: "antenna.radiowaves.left.and.right.slash",
                text: "Letzter Snapshot. Aktualisiert wieder bei Verbindung."
            )
        }

        if showsPollen {
            if selectedTypes.isEmpty {
                chartFallbackCard("Typen im Einstellungen-Sheet wählen, um einen Pollenverlauf zu sehen.")
            } else if pollenChartData.isEmpty {
                chartFallbackCard("Für die aktuelle Auswahl liegt noch kein Pollenverlauf vor.")
            } else {
                HourlyChartCard(
                    entries: pollenChartData,
                    metric: .pollen,
                    titleOverride: pollenChartTitle(for: chartPollenTypes),
                    descriptionText: pollenChartDescription(for: chartPollenTypes),
                    accentCurrentEntry: true,
                    layoutStyle: .compact
                )
                .vintageCard()
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("AUSWAHL")
                        .font(DesignTokens.mono(size: 10, weight: .medium))
                        .foregroundStyle(DesignTokens.secondaryText)

                    if !selectedTypes.isEmpty {
                        Text("\(selectedTypes.count)")
                            .font(DesignTokens.mono(size: 10, weight: .medium))
                            .foregroundStyle(DesignTokens.tertiaryText)
                    }
                }

                if selectedTypes.isEmpty {
                    Text("Noch keine Typen gewählt.")
                        .font(DesignTokens.mono(size: 11))
                        .foregroundStyle(DesignTokens.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(pollenEntries) { entry in
                        Button {
                            HapticManager.selectionChanged()
                            focusedPollenType = chartFocusedPollenType == entry.type ? nil : entry.type
                        } label: {
                            PollenSelectionRow(
                                entry: entry,
                                timeZone: state.snapshot.timeZone,
                                isSelected: chartFocusedPollenType == entry.type
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            chartFocusedPollenType == entry.type
                                ? "\(entry.type.title)-Pollenfokus entfernen"
                                : "\(entry.type.title)-Pollen im Verlauf anzeigen"
                        )
                    }
                }
            }
            .vintageCard()
        }

        if aqiChartData.isEmpty {
            chartFallbackCard("Noch kein AQI-Verlauf verfügbar.")
        } else {
            HourlyChartCard(
                entries: aqiChartData,
                metric: .airQualityIndex,
                titleOverride: "AQI-Verlauf",
                descriptionText: "EU-AQI auf Stufe 1-6, niedriger ist besser.",
                accentCurrentEntry: true,
                layoutStyle: .compact,
                headerAccessory: AnyView(
                    AirQualityScaleInfoButton {
                        isScaleSheetPresented = true
                    }
                )
            )
            .vintageCard()
        }

        HStack(alignment: .top, spacing: 12) {
            MetricCard(
                title: "PM2.5",
                value: formattedMicrogramsValue(state.airQualityCurrent?.pm2_5),
                detail: "Feine Partikel.",
                detailLineLimit: 2,
                contentHeight: 138,
                timeline: airQualityTimelineSamples(state: state) { $0.pm2_5 },
                timelineAccent: DesignTokens.airQualityPoor,
                timelineBaseline: 0,
                timelineCaption: "μg/m³",
                accent: DesignTokens.airQualityPoor
            )
            .frame(maxWidth: .infinity)

            MetricCard(
                title: "PM10",
                value: formattedMicrogramsValue(state.airQualityCurrent?.pm10),
                detail: "Grobere Partikel.",
                detailLineLimit: 2,
                contentHeight: 138,
                timeline: airQualityTimelineSamples(state: state) { $0.pm10 },
                timelineAccent: DesignTokens.airQualityVeryPoor,
                timelineBaseline: 0,
                timelineCaption: "μg/m³",
                accent: DesignTokens.airQualityVeryPoor
            )
            .frame(maxWidth: .infinity)
        }

        WeatherSheetSupportingNote(
            systemImage: showsPollen ? "leaf" : "wind",
            text: showsPollen
                ? "Pollendaten fehlen je nach Region oder Saison."
                : "Pollen lassen sich im Einstellungen-Sheet wieder einblenden."
        )
    }

    private var placeholder: some View {
        VStack(alignment: .leading, spacing: 18) {
            WeatherSheetHeader(
                label: model.showsPollen ? "Pollen & Luft" : "Luftqualität",
                headline: model.showsPollen ? "Pollen im Blick." : "Luft lädt noch.",
                contextTitle: "Wetterblatt",
                summary: model.showsPollen
                    ? "Pollen- und Luftwerte laden."
                    : "Luftwerte laden.",
                accent: DesignTokens.airQualityFair
            )

            Text("Noch keine Daten geladen.")
                .font(DesignTokens.mono(size: 11))
                .foregroundStyle(DesignTokens.tertiaryText)
                .vintageCard()
        }
    }

    private func airQualityHeadline(
        summary: AirQualityQuickGlanceSummary,
        currentAQI: Double?,
        showsPollen: Bool
    ) -> String {
        if showsPollen {
            return summary.title.capitalized + "."
        }

        guard let currentAQI else {
            return "Luft noch offen."
        }

        let category = EuropeanAQICategory(value: currentAQI)
        return "AQI \(formattedAQIValue(currentAQI)) · \(category.scaleDescription)."
    }

    private func pollenChartDescription(for selectedTypes: [PollenType]) -> String {
        if selectedTypes.count == 1 {
            return "\(selectedTypes[0].title) im Stundenverlauf."
        }

        if selectedTypes.count <= 3 {
            return "Je Stunde der stärkste Wert aus \(naturalList(selectedTypes.map(\.title)))."
        }

        return "Je Stunde der stärkste Wert aus \(selectedTypes.count) gewählten Typen."
    }

    private func pollenChartTitle(for selectedTypes: [PollenType]) -> String {
        guard selectedTypes.count == 1, let selectedType = selectedTypes.first else {
            return "Pollen-Verlauf"
        }

        return "\(selectedType.title)-Verlauf"
    }

    private func chartFallbackCard(_ text: String) -> some View {
        Text(text)
            .font(DesignTokens.mono(size: 11))
            .foregroundStyle(DesignTokens.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .vintageCard()
    }
}

private struct AirQualityScaleSheet: View {
    let currentAQI: Double?

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.clear)
                .paperBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                AirQualityScaleCard(currentAQI: currentAQI)
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 36)
            }
        }
    }
}

private struct AirQualityScaleInfoButton: View {
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.lightImpact()
            action()
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DesignTokens.ink)
                .frame(width: 32, height: 32)
                .background(DesignTokens.chromeFill.opacity(0.94))
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(DesignTokens.border, lineWidth: 0.8)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("EU-AQI-Skala öffnen")
        .help("EU-AQI-Skala")
    }
}

private struct AirQualityScaleCard: View {
    let currentAQI: Double?

    private var currentCategory: EuropeanAQICategory? {
        currentAQI.map(EuropeanAQICategory.init(value:))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("EU-AQI-SKALA")
                    .font(DesignTokens.mono(size: 10, weight: .medium))
                    .foregroundStyle(DesignTokens.secondaryText)

                Spacer(minLength: 0)

                Text("NIEDRIGER IST BESSER")
                    .font(DesignTokens.mono(size: 9, weight: .medium))
                    .foregroundStyle(DesignTokens.tertiaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            VStack(spacing: 9) {
                ForEach(EuropeanAQICategory.allCases, id: \.self) { category in
                    AirQualityScaleRow(
                        category: category,
                        isCurrent: category == currentCategory
                    )
                }
            }
        }
        .vintageCard()
    }
}

private struct AirQualityScaleRow: View {
    let category: EuropeanAQICategory
    let isCurrent: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                Circle()
                    .fill(aqiTint(for: category).opacity(isCurrent ? 0.22 : 0.12))

                Text("\(category.scalePosition)")
                    .font(DesignTokens.mono(size: 10, weight: .semibold))
                    .foregroundStyle(aqiTint(for: category))
            }
            .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(category.title)
                    .font(DesignTokens.serif(size: 15))
                    .foregroundStyle(DesignTokens.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)

                Text(category.scaleDescription)
                    .font(DesignTokens.mono(size: 9))
                    .foregroundStyle(DesignTokens.tertiaryText)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text("EU-AQI \(category.rangeDescription)")
                    .font(DesignTokens.mono(size: 10, weight: isCurrent ? .semibold : .regular))
                    .foregroundStyle(isCurrent ? DesignTokens.ink : DesignTokens.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                if isCurrent {
                    Text("AKTUELL")
                        .font(DesignTokens.mono(size: 8, weight: .medium))
                        .foregroundStyle(aqiTint(for: category))
                }
            }
        }
        .padding(.horizontal, isCurrent ? 8 : 0)
        .padding(.vertical, isCurrent ? 6 : 0)
        .background {
            if isCurrent {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(aqiTint(for: category).opacity(0.08))
            }
        }
        .overlay {
            if isCurrent {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(aqiTint(for: category).opacity(0.28), lineWidth: 0.8)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct PollenSelectionRow: View {
    let entry: SelectedPollenSnapshot
    let timeZone: TimeZone
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Circle()
                .fill(entry.severity.tint.opacity(0.18))
                .frame(width: 9, height: 9)
                .overlay {
                    Circle()
                        .stroke(entry.severity.tint, lineWidth: 0.8)
                }

            VStack(alignment: .leading, spacing: peakText == nil ? 0 : 3) {
                Text(entry.type.title)
                    .font(DesignTokens.serif(size: 16))
                    .foregroundStyle(DesignTokens.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)

                if let peakText {
                    Text(peakText)
                        .font(DesignTokens.mono(size: 10))
                        .foregroundStyle(DesignTokens.tertiaryText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 2) {
                Text(compactPollenValue(entry.value))
                    .font(DesignTokens.serif(size: 18))
                    .foregroundStyle(DesignTokens.ink)

                Text(entry.severity.detailTitle.uppercased())
                    .font(DesignTokens.mono(size: 9, weight: .medium))
                    .foregroundStyle(entry.severity.tint)
            }

            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSelected ? entry.severity.tint : DesignTokens.tertiaryText.opacity(0.58))
                .frame(width: 18, height: 18)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(entry.severity.tint.opacity(0.08))
            }
        }
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(entry.severity.tint.opacity(0.30), lineWidth: 0.8)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private var peakText: String? {
        guard let value = entry.value else {
            return "Keine Daten"
        }

        guard let peak = entry.peak,
              let peakValue = peak.pollenValue(for: entry.type),
              peakValue >= value
        else {
            return entry.severity == .none ? "Ruhig" : nil
        }

        if peakValue > value {
            return "Peak \(WeatherDateFormatting.time(peak.timestamp, timeZone: timeZone)) · \(compactPollenValue(peakValue))"
        }

        return entry.severity == .none ? "Ruhig" : nil
    }
}

private func makeAirQualityQuickGlanceSummary(
    state: WeatherScreenState?,
    showsPollen: Bool,
    selectedTypes: [PollenType]
) -> AirQualityQuickGlanceSummary {
    if showsPollen {
        return makePollenQuickGlanceSummary(state: state, selectedTypes: selectedTypes)
    }

    return makeAQIQuickGlanceSummary(state: state)
}

private func makePollenQuickGlanceSummary(
    state: WeatherScreenState?,
    selectedTypes: [PollenType]
) -> AirQualityQuickGlanceSummary {
    guard let state else {
        return AirQualityQuickGlanceSummary(
            title: "Lädt",
            detail: "Pollenlage lädt.",
            tint: DesignTokens.secondaryText,
            symbolName: "leaf"
        )
    }

    guard !selectedTypes.isEmpty else {
        return AirQualityQuickGlanceSummary(
            title: "Typen",
            detail: "Typen wählen.",
            tint: DesignTokens.secondaryText,
            symbolName: "slider.horizontal.3"
        )
    }

    guard state.airQualityCurrent != nil else {
        return AirQualityQuickGlanceSummary(
            title: "Unklar",
            detail: "Keine Pollendaten.",
            tint: DesignTokens.secondaryText,
            symbolName: "leaf"
        )
    }

    let entries = selectedPollenSnapshots(state: state, selectedTypes: selectedTypes)
    let valuesWithData = entries.filter { $0.value != nil }

    guard !valuesWithData.isEmpty else {
        return AirQualityQuickGlanceSummary(
            title: "Unklar",
            detail: "Aktuell keine Werte.",
            tint: DesignTokens.secondaryText,
            symbolName: "leaf"
        )
    }

    let highestSeverity = valuesWithData.map(\.severity).max() ?? .none

    if highestSeverity == .none {
        return AirQualityQuickGlanceSummary(
            title: highestSeverity.title,
            detail: "Aktuell ruhig.",
            tint: highestSeverity.tint,
            symbolName: "leaf"
        )
    }

    let activeTypes = valuesWithData
        .filter { $0.severity.isActive }
        .map(\.type.title)

    let detail: String
    if activeTypes.count > 2 {
        detail = "\(activeTypes.count) Typen aktiv."
    } else if activeTypes.count == 2 {
        detail = "\(activeTypes[0]) und \(activeTypes[1]) aktiv."
    } else {
        detail = "\(activeTypes[0]) aktiv."
    }

    return AirQualityQuickGlanceSummary(
        title: highestSeverity.title,
        detail: detail,
        tint: highestSeverity.tint,
        symbolName: "leaf.fill"
    )
}

private func makeAQIQuickGlanceSummary(
    state: WeatherScreenState?
) -> AirQualityQuickGlanceSummary {
    guard let state else {
        return AirQualityQuickGlanceSummary(
            title: "Lädt",
            detail: "Luftwerte laden.",
            tint: DesignTokens.secondaryText,
            symbolName: "wind"
        )
    }

    guard let value = state.airQualityCurrent?.europeanAQI else {
        return AirQualityQuickGlanceSummary(
            title: "Unklar",
            detail: "Kein AQI-Wert.",
            tint: DesignTokens.secondaryText,
            symbolName: "wind"
        )
    }

    let category = EuropeanAQICategory(value: value)

    return AirQualityQuickGlanceSummary(
        title: category.title,
        detail: "\(category.comparableDescription).",
        tint: aqiTint(for: category),
        symbolName: "wind"
    )
}

private func selectedPollenSnapshots(
    state: WeatherScreenState,
    selectedTypes: [PollenType]
) -> [SelectedPollenSnapshot] {
    selectedTypes.map { type in
        let currentValue = state.airQualityCurrent?.pollenValue(for: type)
        let peak = state.airQualityHourly.max {
            ($0.pollenValue(for: type) ?? -.greatestFiniteMagnitude) < ($1.pollenValue(for: type) ?? -.greatestFiniteMagnitude)
        }

        return SelectedPollenSnapshot(
            type: type,
            value: currentValue,
            severity: type.severity(for: currentValue),
            peak: peak
        )
    }
}

private func pollenTimelineSamples(
    state: WeatherScreenState,
    selectedTypes: [PollenType]
) -> [MetricCard.TimelineSample] {
    guard !selectedTypes.isEmpty else { return [] }

    let calendar = Calendar.weatherCalendar(timeZone: state.snapshot.timeZone)
    let activeTimestamp = state.airQualityCurrent?.timestamp ?? state.airQualityHourly.first?.timestamp

    return state.airQualityHourly.map { item in
        let value = selectedTypes
            .compactMap { item.pollenValue(for: $0) }
            .max() ?? 0

        return MetricCard.TimelineSample(
            id: item.timestamp,
            value: value,
            isCurrent: activeTimestamp.map {
                calendar.isDate(item.timestamp, equalTo: $0, toGranularity: .hour)
            } ?? false,
            isPast: activeTimestamp.map { item.timestamp < $0 } ?? false
        )
    }
}

private func airQualityTimelineSamples(
    state: WeatherScreenState,
    value: (ResolvedAirQualityMoment) -> Double?
) -> [MetricCard.TimelineSample] {
    let calendar = Calendar.weatherCalendar(timeZone: state.snapshot.timeZone)
    let activeTimestamp = state.airQualityCurrent?.timestamp ?? state.airQualityHourly.first?.timestamp

    return state.airQualityHourly.compactMap { item in
        guard let sampleValue = value(item) else { return nil }

        return MetricCard.TimelineSample(
            id: item.timestamp,
            value: sampleValue,
            isCurrent: activeTimestamp.map {
                calendar.isDate(item.timestamp, equalTo: $0, toGranularity: .hour)
            } ?? false,
            isPast: activeTimestamp.map { item.timestamp < $0 } ?? false
        )
    }
}

private func pollenChartEntries(
    state: WeatherScreenState,
    selectedTypes: [PollenType]
) -> [HourlyChartCard.Entry] {
    guard !selectedTypes.isEmpty else { return [] }

    let calendar = Calendar.weatherCalendar(timeZone: state.snapshot.timeZone)
    let activeTimestamp = state.airQualityCurrent?.timestamp ?? state.airQualityHourly.first?.timestamp

    return state.airQualityHourly.compactMap { item in
        let values = selectedTypes.compactMap { type -> (type: PollenType, value: Double)? in
            guard let value = item.pollenValue(for: type) else { return nil }
            return (type, value)
        }

        guard let dominant = values.max(by: { $0.value < $1.value }) else {
            return nil
        }

        let isCurrent = activeTimestamp.map {
            calendar.isDate(item.timestamp, equalTo: $0, toGranularity: .hour)
        } ?? false

        let secondaryValue: String?
        if selectedTypes.count == 1 {
            secondaryValue = dominant.type.severity(for: dominant.value).detailTitle
        } else {
            secondaryValue = dominant.type.title
        }

        return HourlyChartCard.Entry(
            id: item.timestamp,
            displayLabel: isCurrent ? "Jetzt" : airQualityHourLabel(for: item.timestamp, timeZone: state.snapshot.timeZone),
            value: dominant.value,
            formattedValue: "\(Int(dominant.value.rounded()))",
            secondaryFormattedValue: secondaryValue,
            isCurrent: isCurrent,
            isPast: activeTimestamp.map { item.timestamp < $0 } ?? false,
            isRangeHighlighted: dominant.value > 0
        )
    }
}

private func airQualityChartEntries(
    state: WeatherScreenState,
    value: (ResolvedAirQualityMoment) -> Double?,
    formattedValue: (Double) -> String,
    secondaryFormattedValue: ((Double) -> String?)? = nil,
    isRangeHighlighted: ((Double) -> Bool)? = nil
) -> [HourlyChartCard.Entry] {
    let calendar = Calendar.weatherCalendar(timeZone: state.snapshot.timeZone)
    let activeTimestamp = state.airQualityCurrent?.timestamp ?? state.airQualityHourly.first?.timestamp

    return state.airQualityHourly.compactMap { item in
        guard let sampleValue = value(item) else { return nil }

        let isCurrent = activeTimestamp.map {
            calendar.isDate(item.timestamp, equalTo: $0, toGranularity: .hour)
        } ?? false

        return HourlyChartCard.Entry(
            id: item.timestamp,
            displayLabel: isCurrent ? "Jetzt" : airQualityHourLabel(for: item.timestamp, timeZone: state.snapshot.timeZone),
            value: sampleValue,
            formattedValue: formattedValue(sampleValue),
            secondaryFormattedValue: secondaryFormattedValue?(sampleValue),
            isCurrent: isCurrent,
            isPast: activeTimestamp.map { item.timestamp < $0 } ?? false,
            isRangeHighlighted: isRangeHighlighted?(sampleValue) ?? false
        )
    }
}

private func airQualityHourLabel(for date: Date, timeZone: TimeZone) -> String {
    WeatherDateFormatting.string(from: date, format: "HH", timeZone: timeZone)
}

private func compactPollenValue(_ value: Double?) -> String {
    guard let value else { return "—" }
    return "\(Int(value.rounded()))"
}

private func formattedAQIValue(_ value: Double?) -> String {
    guard let value else { return "—" }
    return "\(Int(value.rounded()))"
}

private func aqiScaleText(for value: Double?) -> String {
    guard let value else {
        return "EU-AQI im Tagesverlauf."
    }

    return EuropeanAQICategory(value: value).comparableDescription + "."
}

private func formattedMicrogramsValue(_ value: Double?) -> String {
    guard let value else { return "—" }
    return "\(Int(value.rounded())) μg/m³"
}

private func naturalList(_ items: [String]) -> String {
    switch items.count {
    case 0:
        return "Keine Auswahl"
    case 1:
        return items[0]
    case 2:
        return "\(items[0]) und \(items[1])"
    default:
        let head = items.dropLast().joined(separator: ", ")
        return "\(head) und \(items.last ?? "")"
    }
}

private func aqiTint(for value: Double?) -> Color {
    guard let value else { return DesignTokens.secondaryText }

    return aqiTint(for: EuropeanAQICategory(value: value))
}

private func aqiTint(for category: EuropeanAQICategory) -> Color {
    switch category {
    case .good:
        return DesignTokens.airQualityGood
    case .fair:
        return DesignTokens.airQualityFair
    case .moderate:
        return DesignTokens.airQualityModerate
    case .poor:
        return DesignTokens.airQualityPoor
    case .veryPoor:
        return DesignTokens.airQualityVeryPoor
    case .extremelyPoor:
        return DesignTokens.airQualityExtreme
    }
}

private extension PollenSeverity {
    var tint: Color {
        switch self {
        case .unavailable:
            return DesignTokens.secondaryText
        case .none:
            return DesignTokens.rain
        case .low:
            return DesignTokens.sun
        case .medium:
            return DesignTokens.hazySun
        case .high:
            return DesignTokens.darkAccent
        }
    }
}

private struct MoonSheet: View {
    @Bindable var model: AppModel
    @State private var displayedMonthStart: Date?
    @State private var selectedDate: Date?

    private let weekdayHeaders = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
    private let monthGridColumns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        let monthStart = displayedMonthStart ?? startOfMonth(for: model.clock.now)
        let entries = monthEntries(for: monthStart)
        let selectedEntry = selectedEntry(in: entries)
        let monthOptions = availableMonthStarts()

        return ZStack {
            Rectangle()
                .fill(.clear)
                .paperBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header(for: selectedEntry, in: entries)
                    monthPicker(monthOptions: monthOptions, selectedMonthStart: monthStart)

                    if let selectedEntry {
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
                .padding(.top, 28)
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

    private func header(for selectedEntry: MoonMonthEntry?, in entries: [MoonMonthEntry]) -> some View {
        if let selectedEntry {
            WeatherNarrativeSheetHeader(
                label: "Mondphase",
                headline: moonHeadline(for: selectedEntry),
                summary: headerSummary(for: selectedEntry, in: entries),
                accent: DesignTokens.moon,
                headlineTrailing: {
                    MoonPhaseIconView(kind: selectedEntry.info.kind)
                        .frame(width: 42, height: 42)
                }
            )
        } else {
            WeatherNarrativeSheetHeader(
                label: "Mondphase",
                headline: moonHeadline(for: selectedEntry),
                summary: headerSummary(for: selectedEntry, in: entries),
                accent: DesignTokens.moon
            )
        }
    }

    private func monthPicker(monthOptions: [Date], selectedMonthStart: Date) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(monthOptions, id: \.self) { monthStart in
                    let isSelected = calendar.isDate(monthStart, equalTo: selectedMonthStart, toGranularity: .month)

                    Button {
                        selectMonth(monthStart)
                    } label: {
                        Text(monthPickerTitle(for: monthStart))
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
                    .contentShape(Capsule())
                }
            }
            .padding(.horizontal, 1)
            .padding(.vertical, 2)
        }
        .contentShape(Rectangle())
        .zIndex(1)
    }

    private func monthGridCard(
        monthStart: Date,
        entries: [MoonMonthEntry],
        selectedDate: Date
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: monthGridColumns, spacing: 6) {
                ForEach(weekdayHeaders, id: \.self) { weekday in
                    Text(weekday)
                        .font(DesignTokens.mono(size: 9, weight: .medium))
                        .foregroundStyle(DesignTokens.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 1)
                }

                ForEach(0..<leadingOffset(for: monthStart), id: \.self) { _ in
                    Color.clear
                        .frame(height: 64)
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

    private func headerSummary(for selectedEntry: MoonMonthEntry?, in entries: [MoonMonthEntry]) -> String {
        guard let selectedEntry else {
            return "Noch kein Monatsverlauf für den Mond verfügbar."
        }

        let illumination = Int((selectedEntry.info.illuminationFraction * 100).rounded())
        if let nextMajorPhase = nextMajorPhase(after: selectedEntry, in: entries) {
            return "\(selectedEntry.info.title) mit \(illumination) % Licht. Nächster markanter Wechsel am \(WeatherDateFormatting.shortDayMonth(nextMajorPhase.date, timeZone: timeZone))."
        }

        return "\(selectedEntry.info.title) mit \(illumination) % Licht. \(trendText(for: selectedEntry.info))"
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

    private func moonHeadline(for entry: MoonMonthEntry?) -> String {
        guard let entry else { return "Mond noch offen." }
        return entry.info.title + "."
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

    private func monthPickerTitle(for monthStart: Date) -> String {
        let isCurrentYear = calendar.isDate(monthStart, equalTo: model.clock.now, toGranularity: .year)
        return WeatherDateFormatting.string(
            from: monthStart,
            format: isCurrentYear ? "LLL" : "LLL yy",
            timeZone: timeZone,
            capitalized: true
        )
    }

    private func availableMonthStarts() -> [Date] {
        let currentMonthStart = startOfMonth(for: model.clock.now)

        return (0...12).compactMap { offset in
            guard let month = calendar.date(byAdding: .month, value: offset, to: currentMonthStart) else { return nil }
            return startOfMonth(for: month)
        }
    }

    private func selectMonth(_ monthStart: Date) {
        let normalizedMonth = startOfMonth(for: monthStart)

        if let displayedMonthStart,
           calendar.isDate(displayedMonthStart, equalTo: normalizedMonth, toGranularity: .month) {
            return
        }

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
            VStack(alignment: .leading, spacing: 6) {
                Text("\(entry.day)")
                    .font(DesignTokens.mono(size: 10, weight: isSelected || entry.isToday ? .medium : .regular))
                    .foregroundStyle(DesignTokens.ink)

                MoonPhaseIconView(kind: entry.info.kind)
                    .frame(width: 20, height: 20)

                Text(entry.info.kind.monthBadge)
                    .font(DesignTokens.mono(size: 7.5, weight: .medium))
                    .foregroundStyle(entry.info.kind.isMajorPhase ? DesignTokens.ink : DesignTokens.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
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
                    if let state = model.weatherState,
                       let day = selectedDay(from: state) {
                        let sunContext = context(for: day, in: state)

                        header(for: day, state: state, context: sunContext)

                        ForecastDayPicker(
                            days: availableDays(in: state),
                            selectedDayID: selectedDayID
                        ) { day in
                            selectedDayID = day.date
                        }

                        courseCard(for: day, state: state)
                    } else {
                        headerFallback

                        Text("Noch keine Sonnenzeiten verfügbar.")
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

    private func header(
        for day: ResolvedDailyForecast,
        state: WeatherScreenState,
        context: SunDayContext?
    ) -> some View {
        if let context {
            WeatherNarrativeSheetHeader(
                label: "Sonne",
                headline: "Tag im Bogen.",
                summary: headerSummary(for: day, state: state, context: context),
                headlineTrailing: {
                    Text(durationString(context.daylightDuration))
                        .font(DesignTokens.serif(size: 28, weight: .bold))
                        .foregroundStyle(DesignTokens.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: 140, alignment: .trailing)
                }
            )
        } else {
            WeatherNarrativeSheetHeader(
                label: "Sonne",
                headline: "Tag im Bogen.",
                summary: headerSummary(for: day, state: state, context: context)
            )
        }
    }

    private var headerFallback: some View {
        WeatherNarrativeSheetHeader(
            label: "Sonne",
            headline: "Tag im Bogen.",
            summary: "Noch keine Sonnenzeiten für einen vollständigen Tageslauf verfügbar."
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

    private func headerSummary(
        for day: ResolvedDailyForecast,
        state: WeatherScreenState,
        context: SunDayContext?
    ) -> String {
        guard let context else {
            return "Für \(day.displayLabel.lowercased()) sind Auf- und Untergang noch nicht vollständig geladen."
        }

        return summaryText(for: context, timeZone: state.snapshot.timeZone)
    }

    @ViewBuilder
    private func summaryCard(
        for day: ResolvedDailyForecast,
        state: WeatherScreenState,
        context: SunDayContext?
    ) -> some View {
        if let context {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(day.displayLabel.uppercased())
                            .font(DesignTokens.mono(size: 10, weight: .medium))
                            .foregroundStyle(DesignTokens.secondaryText)

                        Text("Tageslicht \(durationString(context.daylightDuration))")
                            .font(DesignTokens.serif(size: 18))
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
        let dayStart = calendar.startOfDay(for: day.date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return nil }
        let dayDuration = max(dayEnd.timeIntervalSince(dayStart), 1)
        let now = model.clock.now
        let phase: SunDayContext.Phase
        let progress: Double?

        func dayProgress(for date: Date) -> Double {
            min(max(date.timeIntervalSince(dayStart) / dayDuration, 0), 1)
        }

        let sunriseProgress = dayProgress(for: sunrise)
        let solarNoonProgress = dayProgress(for: solarNoon)
        let sunsetProgress = dayProgress(for: sunset)

        if calendar.isDate(day.date, inSameDayAs: now) {
            if now < sunrise {
                phase = .beforeSunrise
                progress = dayProgress(for: now)
            } else if now > sunset {
                phase = .afterSunset
                progress = dayProgress(for: now)
            } else {
                phase = .daylight
                progress = dayProgress(for: now)
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
            sunriseProgress: sunriseProgress,
            solarNoonProgress: solarNoonProgress,
            sunsetProgress: sunsetProgress,
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
            return "\(hours) h"
        }

        return "\(hours) h \(minutes) min"
    }

    private func countdownString(_ interval: TimeInterval) -> String {
        let totalMinutes = max(Int(interval / 60), 0)
        if totalMinutes < 60 {
            return "\(totalMinutes) min"
        }

        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if minutes == 0 {
            return "\(hours) h"
        }

        return "\(hours) h \(minutes) min"
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
                    metrics.fillPath(for: context)
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
                        path.move(to: metrics.dayStart)
                        path.addLine(to: metrics.dayEnd)
                    }
                    .stroke(DesignTokens.border.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                    metrics.arcPath(for: context)
                        .stroke(DesignTokens.border.opacity(0.6), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))

                    if let progress = context.progress {
                        metrics.progressPath(for: context, progress: progress)
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

                    ForEach(Array([context.sunriseProgress, context.solarNoonProgress, context.sunsetProgress].enumerated()), id: \.offset) { _, point in
                        let marker = metrics.point(at: point, for: context)
                        Circle()
                            .fill(DesignTokens.background)
                            .frame(width: 8, height: 8)
                            .overlay {
                                Circle()
                                    .stroke(DesignTokens.border, lineWidth: 1)
                            }
                            .position(marker)
                    }

                    SunCourseMarker(isDimmed: context.progress == nil)
                        .position(metrics.point(at: displayProgress, for: context))
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
        min(max(context.progress ?? context.solarNoonProgress, 0), 1)
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

}

private struct SunCourseMarker: View {
    var isDimmed = false

    var body: some View {
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
            .opacity(isDimmed ? 0.55 : 1)
    }
}

private extension SunCourseCard {
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
    let sunriseProgress: Double
    let solarNoonProgress: Double
    let sunsetProgress: Double
    let progress: Double?
    let phase: Phase
}

private struct SunCoursePlotMetrics {
    let size: CGSize
    let dayStart: CGPoint
    let dayEnd: CGPoint
    let arcTopY: CGFloat

    init(size: CGSize) {
        self.size = size

        let horizonY = max(size.height - 26, 72)
        let horizontalInset: CGFloat = 22
        dayStart = CGPoint(x: horizontalInset, y: horizonY)
        dayEnd = CGPoint(x: max(size.width - horizontalInset, horizontalInset), y: horizonY)
        arcTopY = 16
    }

    func arcPath(for context: SunDayContext) -> Path {
        let start = horizonPoint(at: context.sunriseProgress)
        let end = horizonPoint(at: context.sunsetProgress)
        let control = arcControl(for: context)

        return Path { path in
            path.move(to: start)
            path.addQuadCurve(to: end, control: control)
        }
    }

    func fillPath(for context: SunDayContext) -> Path {
        let start = horizonPoint(at: context.sunriseProgress)
        let end = horizonPoint(at: context.sunsetProgress)
        let control = arcControl(for: context)

        return Path { path in
            path.move(to: start)
            path.addQuadCurve(to: end, control: control)
            path.addLine(to: start)
            path.closeSubpath()
        }
    }

    func progressPath(for context: SunDayContext, progress: Double) -> Path {
        let clamped = min(max(progress, 0), 1)
        let steps = max(Int(clamped * 96), 1)

        return Path { path in
            for step in 0...steps {
                let t = clamped * Double(step) / Double(steps)
                let point = point(at: t, for: context)
                if step == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
        }
    }

    func point(at progress: Double, for context: SunDayContext) -> CGPoint {
        let clamped = min(max(progress, 0), 1)

        if clamped <= context.sunriseProgress || clamped >= context.sunsetProgress {
            return horizonPoint(at: clamped)
        }

        let daylightSpan = max(context.sunsetProgress - context.sunriseProgress, 0.0001)
        let daylightProgress = (clamped - context.sunriseProgress) / daylightSpan
        let start = horizonPoint(at: context.sunriseProgress)
        let control = arcControl(for: context)
        let end = horizonPoint(at: context.sunsetProgress)
        let t = CGFloat(daylightProgress)
        let inverse = 1 - t
        let x = inverse * inverse * start.x + 2 * inverse * t * control.x + t * t * end.x
        let y = inverse * inverse * start.y + 2 * inverse * t * control.y + t * t * end.y
        return CGPoint(x: x, y: y)
    }

    private func horizonPoint(at progress: Double) -> CGPoint {
        let t = CGFloat(min(max(progress, 0), 1))
        let x = dayStart.x + (dayEnd.x - dayStart.x) * t
        return CGPoint(x: x, y: dayStart.y)
    }

    private func arcControl(for context: SunDayContext) -> CGPoint {
        CGPoint(x: horizonPoint(at: context.solarNoonProgress).x, y: arcTopY)
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
                    if let state = model.weatherState,
                       let day = selectedDay(from: state) {
                        let chartDomain = comparisonChartDomain(for: state)
                        let hours = dayHours(for: day, in: state)
                        let entries = chartEntries(for: state, hours: hours)

                        WeatherNarrativeSheetHeader(
                            label: detail.title,
                            headline: headlineText(state: state, day: day, hours: hours),
                            summary: headerSummaryText(state: state, day: day, hours: hours),
                            accent: detail.accent,
                            headlineTrailing: {
                                WeatherSheetHeadlineValue(value: heroValue(state: state, hours: hours), accent: detail.accent)
                            }
                        )

                        ForecastDayPicker(
                            days: availableDays(in: state),
                            selectedDayID: selectedDayID,
                            accent: detail.accent
                        ) { day in
                            selectedDayID = day.date
                        }

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
                                layoutStyle: .compact,
                                valueDomain: chartDomain,
                                axisLabelOverride: chartAxisLabel,
                                axisValueFormatter: chartAxisValueLabel
                            )
                            .vintageCard()
                        }
                    } else {
                        WeatherNarrativeSheetHeader(
                            label: detail.title,
                            headline: detail.emptyHeadline,
                            summary: detail.subtitle,
                            accent: detail.accent
                        )

                        Text("Noch keine Tagesdetails.")
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

    private var chartAxisLabel: String {
        switch detail {
        case .apparentTemperature:
            return model.temperatureAxisLabel
        case .wind:
            return model.windSpeedAxisLabel
        }
    }

    private func chartAxisValueLabel(_ value: Double) -> String {
        switch detail {
        case .apparentTemperature:
            return model.formattedTemperature(value)
        case .wind:
            let formatted = model.formattedWindSpeed(value)
            return formatted
                .replacingOccurrences(of: " km/h", with: "")
                .replacingOccurrences(of: " m/s", with: "")
        }
    }

    private func headerSummaryText(
        state: WeatherScreenState,
        day: ResolvedDailyForecast,
        hours: [HourlyForecastEntry]
    ) -> String {
        switch detail {
        case .apparentTemperature:
            let referenceHour = summaryReferenceHour(for: day, hours: hours, timeZone: state.snapshot.timeZone)
            let referenceDelta = referenceHour.map { $0.apparentTemperature - $0.temperature } ?? 0
            return apparentTemperatureSummaryText(delta: referenceDelta)
        case .wind:
            let peakWind = hours.max(by: { $0.windSpeed < $1.windSpeed })?.windSpeed ?? state.current.windSpeed
            return windNarrative(for: peakWind)
        }
    }

    private func headlineText(
        state: WeatherScreenState,
        day: ResolvedDailyForecast,
        hours: [HourlyForecastEntry]
    ) -> String {
        switch detail {
        case .apparentTemperature:
            let referenceHour = summaryReferenceHour(for: day, hours: hours, timeZone: state.snapshot.timeZone)
            let referenceDelta = referenceHour.map { $0.apparentTemperature - $0.temperature } ?? 0
            if abs(referenceDelta) <= 1 {
                return "Nahe an der Luft."
            }
            return referenceDelta > 0 ? "Wirkt wärmer." : "Wirkt kühler."
        case .wind:
            let peakWind = hours.max(by: { $0.windSpeed < $1.windSpeed })?.windSpeed ?? state.current.windSpeed
            switch peakWind {
            case ..<10:
                return "Leiser Zug."
            case ..<20:
                return "Leichte Brise."
            case ..<35:
                return "Frischer Lauf."
            default:
                return "Kräftiger Zug."
            }
        }
    }

    private func chartEntries(
        for state: WeatherScreenState,
        hours: [HourlyForecastEntry]
    ) -> [HourlyChartCard.Entry] {
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
                isRangeHighlighted: !isPast || isCurrent
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
            return model.formattedWindSpeed(value)
        }
    }

    private func heroValue(state: WeatherScreenState, hours: [HourlyForecastEntry]) -> String {
        switch detail {
        case .apparentTemperature:
            let value = hours.last(where: { $0.timestamp <= model.clock.now })?.apparentTemperature
                ?? hours.first?.apparentTemperature
                ?? state.current.apparentTemperature
            return formattedTemperature(value)
        case .wind:
            let peakWind = hours.max(by: { $0.windSpeed < $1.windSpeed })?.windSpeed ?? state.current.windSpeed
            return model.formattedWindSpeed(peakWind)
        }
    }

    private func heroDetailText(
        state: WeatherScreenState,
        day: ResolvedDailyForecast,
        hours: [HourlyForecastEntry]
    ) -> String {
        switch detail {
        case .apparentTemperature:
            let referenceHour = summaryReferenceHour(for: day, hours: hours, timeZone: state.snapshot.timeZone)
            let delta = referenceHour.map { $0.apparentTemperature - $0.temperature } ?? (state.current.apparentTemperature - state.current.temperature)
            return apparentTemperatureSummaryText(delta: delta)
        case .wind:
            let peakWind = hours.max(by: { $0.windSpeed < $1.windSpeed })?.windSpeed ?? state.current.windSpeed
            return windNarrative(for: peakWind)
        }
    }

    private func footnoteText(state: WeatherScreenState, hours: [HourlyForecastEntry]) -> String {
        switch detail {
        case .apparentTemperature:
            let currentDelta = state.current.apparentTemperature - state.current.temperature
            if abs(currentDelta) <= 0.5 {
                return "Gefühlte und gemessene Luft liegen aktuell eng beieinander."
            }
            if currentDelta > 0 {
                return "Sonne oder stehende Luft legen aktuell etwa \(model.formattedTemperatureDelta(currentDelta)) drauf."
            }
            return "Wind oder Feuchte ziehen aktuell etwa \(model.formattedTemperatureDelta(currentDelta)) ab."
        case .wind:
            guard let peakHour = hours.max(by: { $0.windSpeed < $1.windSpeed }) else {
                return "Noch kein stündlicher Höhepunkt aufgelöst."
            }
            return "Stärkste Phase um \(hourLabel(for: peakHour.timestamp, timeZone: state.snapshot.timeZone)) Uhr."
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

    private func comparisonChartDomain(for state: WeatherScreenState) -> ClosedRange<Double>? {
        HourlyChartCard.valueDomain(
            for: availableDays(in: state).map { day in
                chartEntries(for: state, hours: dayHours(for: day, in: state))
            }
        )
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

    private func hourLabel(for date: Date, timeZone: TimeZone) -> String {
        return WeatherDateFormatting.string(from: date, format: "HH", timeZone: timeZone)
    }

    private func formattedTemperature(_ value: Double) -> String {
        model.formattedTemperature(value)
    }

    private func apparentTemperatureSummaryText(delta: Double) -> String {
        if abs(delta) <= 1 {
            return "Die gefühlte Temperatur liegt nah an der gemessenen Luft."
        }

        if delta > 0 {
            return "Sonne oder ruhigere Luft lassen es etwa \(model.formattedTemperatureDelta(delta)) wärmer wirken als gemessen."
        }

        return "Wind oder Feuchte drücken das Gefühl um etwa \(model.formattedTemperatureDelta(delta)) unter die Lufttemperatur."
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

private struct WeatherAlertSheet: View {
    @Bindable var model: AppModel

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.clear)
                .paperBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    if let state = model.weatherState {
                        let summary = makeWeatherAlertSummary(for: state, model: model)

                        WeatherNarrativeSheetHeader(
                            label: "Warnungen",
                            headline: summary.headline,
                            summary: summary.detail,
                            accent: summary.tint,
                            headlineTrailing: {
                                WeatherSheetHeadlineValue(value: summary.primarySeverity.title, accent: summary.tint)
                            }
                        )

                        WeatherAlertOverviewCard(
                            summary: summary,
                            windowText: alertWindowText(for: state),
                            updatedText: updatedText(for: state)
                        )

                        WeatherAlertScanGrid(summary: summary)

                        if summary.items.isEmpty {
                            WeatherAlertStatusCard(
                                title: "Ruhige Wetterlage",
                                detail: "Alle geprüften Werte bleiben unter den lokalen Schwellen. Für die nächsten Stunden gibt es keinen markanten Treffer.",
                                symbolName: "checkmark.seal",
                                tint: DesignTokens.wind
                            )
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("AKTIVE HINWEISE")
                                    .font(DesignTokens.mono(size: 10, weight: .medium))
                                    .foregroundStyle(DesignTokens.secondaryText)
                                    .tracking(1.6)

                                ForEach(summary.items) { item in
                                    WeatherAlertRow(item: item)
                                }
                            }
                        }
                    } else {
                        WeatherNarrativeSheetHeader(
                            label: "Warnungen",
                            headline: "Noch keine Wetterlage.",
                            summary: "Warnungen erscheinen, sobald ein Forecast geladen wurde.",
                            accent: DesignTokens.secondaryText
                        )

                        Text("Noch keine Warnbasis.")
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
    }

    private func alertWindowText(for state: WeatherScreenState) -> String {
        let now = model.clock.now
        let end = now.addingTimeInterval(12 * 3_600)

        return "\(WeatherDateFormatting.time(now, timeZone: state.snapshot.timeZone)) bis \(WeatherDateFormatting.time(end, timeZone: state.snapshot.timeZone))"
    }

    private func updatedText(for state: WeatherScreenState) -> String {
        WeatherDateFormatting.time(state.snapshot.fetchedAt, timeZone: state.snapshot.timeZone)
    }
}

private struct WeatherAlertOverviewCard: View {
    let summary: WeatherAlertSummary
    let windowText: String
    let updatedText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(summary.tint.opacity(0.16))
                        .frame(width: 44, height: 44)

                    Image(systemName: summary.symbolName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(summary.tint)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("LAGEBILD")
                        .font(DesignTokens.mono(size: 9, weight: .medium))
                        .foregroundStyle(summary.tint)
                        .tracking(1.4)

                    Text(overviewTitle)
                        .font(DesignTokens.serif(size: 22, weight: .bold))
                        .foregroundStyle(DesignTokens.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(overviewDetail)
                        .font(DesignTokens.mono(size: 10))
                        .foregroundStyle(DesignTokens.tertiaryText)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                WeatherAlertSeverityMeter(severity: summary.primarySeverity, tint: summary.tint)
            }

            HStack(spacing: 8) {
                WeatherAlertSummaryMetric(title: "Fenster", value: "12 h", detail: windowText)
                WeatherAlertSummaryMetric(title: "Treffer", value: itemCountText, detail: itemCountDetail)
                WeatherAlertSummaryMetric(title: "Stand", value: updatedText, detail: "Forecast")
            }
        }
        .vintageCard()
    }

    private var overviewTitle: String {
        if summary.items.isEmpty {
            return "Keine Treffer."
        }

        if summary.severeCount > 0 {
            return "\(summary.severeCount) markante Warnung\(summary.severeCount == 1 ? "" : "en")."
        }

        return "Hinweise vorhanden."
    }

    private var overviewDetail: String {
        if summary.items.isEmpty {
            return "Das Sheet prüft Gewitter, Regen, Wind, Temperatur, UV und Pollen im kurzfristigen Forecast."
        }

        if summary.severeCount > 0 && summary.elevatedCount > 0 {
            return "\(summary.severeCount) Warnung\(summary.severeCount == 1 ? "" : "en") und \(summary.elevatedCount) Hinweis\(summary.elevatedCount == 1 ? "" : "e") brauchen Aufmerksamkeit."
        }

        return "Die stärksten Signale stehen oben und behalten ihre Messwerte direkt an der Karte."
    }

    private var itemCountText: String {
        summary.items.isEmpty ? "klar" : "\(summary.items.count)"
    }

    private var itemCountDetail: String {
        summary.items.count == 1 ? "Eintrag" : "Einträge"
    }
}

private struct WeatherAlertSummaryMetric: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(DesignTokens.mono(size: 7.5, weight: .medium))
                .foregroundStyle(DesignTokens.secondaryText)
                .tracking(1)

            Text(value)
                .font(DesignTokens.serif(size: 17, weight: .bold))
                .foregroundStyle(DesignTokens.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(detail)
                .font(DesignTokens.mono(size: 8))
                .foregroundStyle(DesignTokens.tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .background(DesignTokens.chromeFill.opacity(0.56), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(DesignTokens.border.opacity(0.46), lineWidth: 0.7)
        )
    }
}

private struct WeatherAlertSeverityMeter: View {
    let severity: WeatherAlertSeverity
    let tint: Color

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            ForEach(WeatherAlertSeverity.allCases.reversed(), id: \.rawValue) { level in
                Capsule()
                    .fill(level.rawValue <= severity.rawValue ? tint.opacity(level == severity ? 0.95 : 0.38) : DesignTokens.border.opacity(0.42))
                    .frame(width: level == severity ? 28 : 18, height: 4)
            }
        }
        .frame(width: 32, alignment: .trailing)
        .accessibilityHidden(true)
    }
}

private struct WeatherAlertScanGrid: View {
    let summary: WeatherAlertSummary

    private var scanItems: [WeatherAlertScanItem] {
        [
            WeatherAlertScanItem(
                title: "Gewitter",
                symbolName: "cloud.bolt.rain.fill",
                tint: DesignTokens.storm,
                isActive: summary.containsAlert(with: ["thunderstorm"])
            ),
            WeatherAlertScanItem(
                title: "Regen",
                symbolName: "cloud.rain.fill",
                tint: DesignTokens.rain,
                isActive: summary.containsAlert(with: ["heavy-rain", "rain"])
            ),
            WeatherAlertScanItem(
                title: "Wind",
                symbolName: "wind",
                tint: DesignTokens.wind,
                isActive: summary.containsAlert(with: ["storm", "wind"])
            ),
            WeatherAlertScanItem(
                title: "Temperatur",
                symbolName: "thermometer",
                tint: DesignTokens.uv,
                isActive: summary.containsAlert(with: ["heat", "warm", "hard-frost", "frost"])
            ),
            WeatherAlertScanItem(
                title: "UV",
                symbolName: "sun.max.fill",
                tint: DesignTokens.uv,
                isActive: summary.containsAlert(with: ["uv-high", "uv"])
            ),
            WeatherAlertScanItem(
                title: "Pollen",
                symbolName: "leaf.fill",
                tint: DesignTokens.airQualityGood,
                isActive: summary.items.contains { $0.id.hasPrefix("pollen-") }
            ),
        ]
    }

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("GEPRÜFT")
                .font(DesignTokens.mono(size: 10, weight: .medium))
                .foregroundStyle(DesignTokens.secondaryText)
                .tracking(1.6)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(scanItems) { item in
                    WeatherAlertScanPill(item: item)
                }
            }
        }
    }
}

private struct WeatherAlertScanItem: Identifiable {
    let title: String
    let symbolName: String
    let tint: Color
    let isActive: Bool

    var id: String { title }
}

private struct WeatherAlertScanPill: View {
    let item: WeatherAlertScanItem

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: item.symbolName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(item.isActive ? item.tint : DesignTokens.secondaryText)
                .frame(width: 16)

            Text(item.title)
                .font(DesignTokens.mono(size: 9, weight: .medium))
                .foregroundStyle(item.isActive ? DesignTokens.ink : DesignTokens.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.76)

            Spacer(minLength: 0)

            Image(systemName: item.isActive ? "exclamationmark" : "checkmark")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(item.isActive ? item.tint : DesignTokens.wind)
                .frame(width: 16, height: 16)
                .background((item.isActive ? item.tint : DesignTokens.wind).opacity(0.12), in: Circle())
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 10)
        .background(DesignTokens.chromeFill.opacity(item.isActive ? 0.78 : 0.48), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke((item.isActive ? item.tint : DesignTokens.border).opacity(item.isActive ? 0.58 : 0.42), lineWidth: 0.7)
        )
    }
}

private struct WeatherAlertStatusCard: View {
    let title: String
    let detail: String
    let symbolName: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: symbolName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(DesignTokens.serif(size: 18, weight: .semibold))
                    .foregroundStyle(DesignTokens.ink)

                Text(detail)
                    .font(DesignTokens.mono(size: 10))
                    .foregroundStyle(DesignTokens.secondaryText)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .vintageCard()
    }
}

private struct WeatherAlertRow: View {
    let item: WeatherAlertItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(item.tint)
                .frame(width: 3)
                .padding(.vertical, 2)

            ZStack {
                Circle()
                    .fill(item.tint.opacity(0.14))
                    .frame(width: 34, height: 34)

                Image(systemName: item.symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(item.tint)
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.title)
                        .font(DesignTokens.serif(size: 18, weight: .semibold))
                        .foregroundStyle(DesignTokens.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)

                    Text(item.severity.title.uppercased())
                        .font(DesignTokens.mono(size: 7.5, weight: .bold))
                        .foregroundStyle(item.tint)
                        .lineLimit(1)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 7)
                        .background(item.tint.opacity(0.11), in: Capsule())
                }

                Text(item.detail)
                    .font(DesignTokens.mono(size: 10))
                    .foregroundStyle(DesignTokens.secondaryText)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 6)

            VStack(alignment: .trailing, spacing: 2) {
                Text(item.metric)
                    .font(DesignTokens.serif(size: 20, weight: .bold))
                    .foregroundStyle(item.tint)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .minimumScaleFactor(0.62)

                Text("WERT")
                    .font(DesignTokens.mono(size: 7.5, weight: .medium))
                    .foregroundStyle(DesignTokens.tertiaryText)
                    .tracking(1)
            }
            .frame(width: 76, alignment: .trailing)
        }
        .vintageCard()
    }
}

private struct RainNowcastSheet: View {
    @Bindable var model: AppModel

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.clear)
                .paperBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    if let state = model.weatherState,
                       let summary = RainNowcastResolver.summary(for: state, now: model.clock.now) {
                        WeatherNarrativeSheetHeader(
                            label: "Regen",
                            headline: headline(for: summary),
                            summary: detail(for: summary),
                            accent: DesignTokens.rain,
                            headlineTrailing: {
                                WeatherSheetHeadlineValue(
                                    value: model.formattedPrecipitation(summary.totalPrecipitation),
                                    accent: DesignTokens.rain
                                )
                            }
                        )

                        RainNowcastTimelineCard(
                            samples: summary.samples,
                            windowLabel: summary.windowLabel,
                            timeZone: summary.timeZone,
                            valueFormatter: model.formattedPrecipitation
                        )
                        .vintageCard()
                    } else {
                        WeatherNarrativeSheetHeader(
                            label: "Regen",
                            headline: "Noch kein Kurzfristblick.",
                            summary: "Die Kurzfristdaten werden beim nächsten Wetterabruf geladen.",
                            accent: DesignTokens.rain
                        )

                        Text("Noch keine Kurzfristwerte.")
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
    }

    private func headline(for summary: RainNowcastSummary) -> String {
        guard let firstWetSample = summary.firstWetSample else {
            return "Trocken für \(summary.windowLabel)."
        }
        let minutes = max(0, Int((firstWetSample.timestamp.timeIntervalSince(summary.now) / 60.0).rounded()))

        if minutes <= 2 {
            return "Es Regnet."
        }

        return "in \(minutes) Minuten."
    }

    private func detail(for summary: RainNowcastSummary) -> String {
        "5-Minuten-Säulen aus dem Kurzfristforecast."
    }
}

private struct RainNowcastTimelineCard: View {
    let samples: [RainNowcastSample]
    let windowLabel: String
    let timeZone: TimeZone
    let valueFormatter: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("NÄCHSTE \(windowLabel.uppercased())")
                    .font(DesignTokens.mono(size: 10, weight: .medium))
                    .foregroundStyle(DesignTokens.rain)
                    .tracking(1.2)

                Spacer(minLength: 12)

                Text("MM / 5 MIN")
                    .font(DesignTokens.mono(size: 8, weight: .medium))
                    .foregroundStyle(DesignTokens.secondaryText)
                    .tracking(1)
            }

            VStack(spacing: 8) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(axisLabel(for: 1))
                            .font(axisFont)
                            .foregroundStyle(DesignTokens.tertiaryText)

                        Spacer(minLength: 0)

                        Text(axisLabel(for: 0.5))
                            .font(axisFont)
                            .foregroundStyle(DesignTokens.tertiaryText)

                        Spacer(minLength: 0)

                        Text(axisLabel(for: 0))
                            .font(axisFont)
                            .foregroundStyle(DesignTokens.tertiaryText)
                    }
                    .frame(width: 38, height: chartHeight)

                    GeometryReader { proxy in
                        ZStack(alignment: .bottomLeading) {
                            chartGrid

                            HStack(alignment: .bottom, spacing: barSpacing(for: proxy.size.width)) {
                                ForEach(samples) { sample in
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .fill(barFill(for: sample))
                                        .frame(
                                            width: barWidth(for: proxy.size.width),
                                            height: barHeight(for: sample, totalHeight: chartHeight)
                                        )
                                        .overlay(alignment: .top) {
                                            if sample.isCurrent {
                                                Capsule()
                                                    .fill(DesignTokens.ink.opacity(0.7))
                                                    .frame(height: 2)
                                                    .offset(y: -5)
                                            }
                                        }
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        }
                    }
                    .frame(height: chartHeight)
                }

                HStack(spacing: 10) {
                    Spacer()
                        .frame(width: 38)

                    HStack {
                        ForEach(Array(timeTicks.enumerated()), id: \.offset) { index, tick in
                            Text(timeLabel(for: tick))
                                .font(DesignTokens.mono(size: 8, weight: .medium))
                                .foregroundStyle(isCurrentTick(tick) ? DesignTokens.ink : DesignTokens.secondaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)

                            if index < timeTicks.count - 1 {
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
            }
        }
    }

    private var chartHeight: CGFloat { 136 }

    private var axisFont: Font {
        DesignTokens.mono(size: 7.5, weight: .medium)
    }

    private var axisLevels: [Double] {
        [1, 0.5, 0]
    }

    private var peakAmount: Double {
        max(samples.map(\.wetAmount).max() ?? 0, 0.05)
    }

    private var timeTicks: [Date] {
        guard !samples.isEmpty else { return [] }
        let desiredCount = min(5, max(2, samples.count / 6 + 1))
        let step = max(1, (samples.count - 1) / max(1, desiredCount - 1))
        var ticks = stride(from: 0, to: samples.count, by: step).map { samples[$0].timestamp }

        if let last = samples.last?.timestamp, ticks.last != last {
            ticks.append(last)
        }

        return ticks
    }

    private var chartGrid: some View {
        VStack {
            ForEach(axisLevels, id: \.self) { level in
                Rectangle()
                    .fill(level == 0 ? DesignTokens.border.opacity(0.74) : DesignTokens.border.opacity(0.34))
                    .frame(height: level == 0 ? 1 : 0.7)

                if level != axisLevels.last {
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func barHeight(for sample: RainNowcastSample, totalHeight: CGFloat) -> CGFloat {
        guard sample.wetAmount > 0 else { return 3 }
        let ratio = min(max(sample.wetAmount / peakAmount, 0.04), 1)
        return totalHeight * CGFloat(ratio)
    }

    private func barSpacing(for width: CGFloat) -> CGFloat {
        samples.count > 30 || width < 320 ? 2 : 3
    }

    private func barWidth(for width: CGFloat) -> CGFloat {
        guard !samples.isEmpty else { return 0 }
        let spacing = barSpacing(for: width)
        let totalSpacing = spacing * CGFloat(max(samples.count - 1, 0))
        return max(3, (width - totalSpacing) / CGFloat(samples.count))
    }

    private func barFill(for sample: RainNowcastSample) -> Color {
        sample.isWet ? DesignTokens.rain : DesignTokens.border.opacity(0.44)
    }

    private func axisLabel(for level: Double) -> String {
        valueFormatter(peakAmount * level)
    }

    private func isCurrentTick(_ date: Date) -> Bool {
        samples.first(where: { $0.timestamp == date })?.isCurrent == true
    }

    private func timeLabel(for date: Date) -> String {
        WeatherDateFormatting.string(from: date, format: "HH:mm", timeZone: timeZone)
    }
}

private struct SettingsSheet: View {
    @Bindable var model: AppModel
    @Environment(\.weatherPaperPalette) private var palette

    var body: some View {
        NavigationStack {
            ZStack {
                Rectangle()
                    .fill(.clear)
                    .paperBackground()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        SettingsGeneralSection(model: model)
                        SettingsHeroThemesSection(model: model)
                            .environment(\.weatherPaperPalette, palette)
                        SettingsUnitsSection(model: model)
                        SettingsWidgetSection(model: model)
                        SettingsPollenSection(model: model)
                        SettingsLocationSection(model: model)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 36)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Einstellungen")
                .font(DesignTokens.serif(size: 26, weight: .semibold))
                .foregroundStyle(DesignTokens.ink)

            Text("Wetterblatt")
                .font(DesignTokens.mono(size: 9, weight: .medium))
                .foregroundStyle(DesignTokens.secondaryText)
        }
    }
}

private struct SettingsGeneralSection: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsSectionTitle("ALLGEMEIN")

            SettingsToggleRow(
                title: "Haptisches Feedback",
                detail: nil,
                providesHapticFeedback: false,
                isOn: Binding(
                    get: { model.isHapticsEnabled },
                    set: { model.setHapticsEnabled($0) }
                )
            )

            SettingsToggleRow(
                title: "Reduzierte Bewegung",
                detail: "Deaktiviert Hero-Tilt und Wetteranimationen in der App.",
                isOn: Binding(
                    get: { model.reducesMotionEffects },
                    set: { model.setReducesMotionEffects($0) }
                )
            )
        }
        .vintageCard()
    }
}

private struct SettingsHeroThemesSection: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsSectionTitle("HERO")

            NavigationLink {
                HeroThemesSettingsView(model: model)
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Themen")
                            .font(DesignTokens.serif(size: 16, weight: .regular))
                            .foregroundStyle(DesignTokens.ink)

                        Text(themeCountText)
                            .font(DesignTokens.mono(size: 10))
                            .foregroundStyle(DesignTokens.tertiaryText)
                    }

                    Spacer(minLength: 12)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DesignTokens.secondaryText)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .vintageCard()
    }

    private var themeCountText: String {
        switch model.heroThemes.count {
        case 0:
            return "Keine eigenen Pillen."
        case 1:
            return "1 eigene Pille."
        default:
            return "\(model.heroThemes.count) eigene Pillen."
        }
    }
}

private struct HeroThemesSettingsView: View {
    @Bindable var model: AppModel
    @Environment(\.weatherPaperPalette) private var palette
    @State private var isAddSheetPresented = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.clear)
                .paperBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    if model.heroThemes.isEmpty {
                        heroThemeEmptyState
                    } else {
                        ForEach(model.heroThemes) { theme in
                            HeroThemeSettingsRow(theme: theme) {
                                HapticManager.lightImpact()
                                model.removeHeroTheme(theme)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 36)
            }
        }
        .navigationTitle("Themen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    HapticManager.lightImpact()
                    isAddSheetPresented = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddSheetPresented) {
            HeroThemeEditorSheet(model: model)
                .weatherSheetChrome(palette)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
    }

    private var heroThemeEmptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Noch keine Themen")
                .font(DesignTokens.serif(size: 20, weight: .semibold))
                .foregroundStyle(DesignTokens.ink)

            Text("Neue Themen erscheinen als Hero-Pillen, sobald ihre Wetterkriterien stimmen.")
                .font(DesignTokens.mono(size: 10))
                .foregroundStyle(DesignTokens.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .vintageCard()
    }
}

private struct HeroThemeSettingsRow: View {
    let theme: HeroThemeRule
    let deleteAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(theme.color.color)
                .frame(width: 14, height: 14)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 7) {
                Text(theme.title)
                    .font(DesignTokens.serif(size: 17, weight: .regular))
                    .foregroundStyle(DesignTokens.ink)

                Text(summary)
                    .font(DesignTokens.mono(size: 9))
                    .foregroundStyle(DesignTokens.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button(action: deleteAction) {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DesignTokens.airQualityVeryPoor)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .vintageCard()
    }

    private var summary: String {
        let mode = theme.matchMode == .all ? "Alle" : "Eine"
        let criteria = theme.criteria
            .map { "\($0.isNegated ? "nicht " : "")\($0.criterion.title)" }
            .joined(separator: " · ")
        return "\(mode): \(criteria)"
    }
}

private struct HeroThemeEditorSheet: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var color = HeroThemeColor.default.color
    @State private var matchMode: HeroThemeMatchMode = .all
    @State private var activeCriteria: Set<HeroThemeCriterion> = []
    @State private var negatedCriteria: Set<HeroThemeCriterion> = []

    var body: some View {
        NavigationStack {
            ZStack {
                Rectangle()
                    .fill(.clear)
                    .paperBackground()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        titleAndColor
                            .vintageCard()

                        combinationBlock
                            .vintageCard()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 36)
                }
            }
            .navigationTitle("Thema")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        saveTheme()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var titleAndColor: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsSectionTitle("PILLE")

            HStack(alignment: .center, spacing: 12) {
                TextField("Titel", text: $title)
                    .font(DesignTokens.serif(size: 18, weight: .regular))
                    .foregroundStyle(DesignTokens.ink)
                    .textInputAutocapitalization(.sentences)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(DesignTokens.chromeFill.opacity(0.62))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(DesignTokens.border.opacity(0.54), lineWidth: 0.8)
                    )

                ColorPicker("Farbe", selection: $color, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 44, height: 44)
            }
        }
    }

    private var combinationBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsSectionTitle("KRITERIEN")

            Picker("Verknüpfung", selection: $matchMode) {
                ForEach(HeroThemeMatchMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            VStack(spacing: 12) {
                ForEach(HeroThemeCriterion.allCases) { criterion in
                    HeroThemeCriterionRow(
                        criterion: criterion,
                        isActive: bindingForCriterion(criterion),
                        isNegated: bindingForNegation(criterion)
                    )
                }
            }
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !activeCriteria.isEmpty
    }

    private func bindingForCriterion(_ criterion: HeroThemeCriterion) -> Binding<Bool> {
        Binding(
            get: { activeCriteria.contains(criterion) },
            set: { isActive in
                if isActive {
                    activeCriteria.insert(criterion)
                } else {
                    activeCriteria.remove(criterion)
                    negatedCriteria.remove(criterion)
                }
            }
        )
    }

    private func bindingForNegation(_ criterion: HeroThemeCriterion) -> Binding<Bool> {
        Binding(
            get: { negatedCriteria.contains(criterion) },
            set: { isNegated in
                if isNegated {
                    activeCriteria.insert(criterion)
                    negatedCriteria.insert(criterion)
                } else {
                    negatedCriteria.remove(criterion)
                }
            }
        )
    }

    private func saveTheme() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let selections = HeroThemeCriterion.allCases.compactMap { criterion -> HeroThemeCriterionSelection? in
            guard activeCriteria.contains(criterion) else { return nil }
            return HeroThemeCriterionSelection(
                criterion: criterion,
                isNegated: negatedCriteria.contains(criterion)
            )
        }

        guard !trimmedTitle.isEmpty, !selections.isEmpty else { return }

        model.addHeroTheme(
            HeroThemeRule(
                title: trimmedTitle,
                color: HeroThemeColor(color: color),
                matchMode: matchMode,
                criteria: selections
            )
        )
        HapticManager.success()
        dismiss()
    }
}

private struct HeroThemeCriterionRow: View {
    let criterion: HeroThemeCriterion
    @Binding var isActive: Bool
    @Binding var isNegated: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Toggle("", isOn: $isActive)
                .labelsHidden()
                .tint(DesignTokens.toggleAccent)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Image(systemName: criterion.symbolName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isActive ? DesignTokens.toggleAccent : DesignTokens.secondaryText)
                        .frame(width: 16)

                    Text(criterion.title)
                        .font(DesignTokens.serif(size: 16, weight: .regular))
                        .foregroundStyle(DesignTokens.ink)
                }

                Text(criterion.detail)
                    .font(DesignTokens.mono(size: 9))
                    .foregroundStyle(DesignTokens.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button {
                isActive = true
                isNegated.toggle()
                HapticManager.selectionChanged()
            } label: {
                Text("NICHT")
                    .font(DesignTokens.mono(size: 8, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(isNegated ? DesignTokens.ink : DesignTokens.secondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(isNegated ? DesignTokens.airQualityVeryPoor.opacity(0.18) : DesignTokens.chromeFill.opacity(0.5))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(
                                isNegated ? DesignTokens.airQualityVeryPoor.opacity(0.7) : DesignTokens.border.opacity(0.54),
                                lineWidth: 0.8
                            )
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

private struct SettingsUnitsSection: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSectionTitle("EINHEITEN")

            SettingsPickerBlock(title: "Temperatur", detail: "Anzeige in Forecasts und Hero.") {
                Picker("Temperatur", selection: Binding(
                    get: { model.temperatureUnit },
                    set: { model.setTemperatureUnit($0) }
                )) {
                    ForEach(TemperatureUnitPreference.allCases) { unit in
                        Text(unit.shortTitle).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
            }

            SettingsPickerBlock(title: "Wind", detail: "Windkarten und Warnwerte.") {
                Picker("Wind", selection: Binding(
                    get: { model.windSpeedUnit },
                    set: { model.setWindSpeedUnit($0) }
                )) {
                    ForEach(WindSpeedUnitPreference.allCases) { unit in
                        Text(unit.title).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
            }

            SettingsPickerBlock(title: "Niederschlag", detail: "Regenkarten und Kurzfristblick.") {
                Picker("Niederschlag", selection: Binding(
                    get: { model.precipitationUnit },
                    set: { model.setPrecipitationUnit($0) }
                )) {
                    ForEach(PrecipitationUnitPreference.allCases) { unit in
                        Text(unit.title).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .vintageCard()
    }
}

private struct SettingsWidgetSection: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsSectionTitle("WIDGET")

            SettingsSelectionRow(
                title: "App-Auswahl",
                detail: "Widgets folgen dem bevorzugten Ort der App.",
                isSelected: model.widgetPlaceSelection.kind == .followActivePlace
            ) {
                HapticManager.selectionChanged()
                model.setWidgetPlaceSelection(.default)
            }

            SettingsSelectionRow(
                title: "Aktueller Standort",
                detail: "Widgets nutzen den zuletzt bekannten aktuellen Ort.",
                isSelected: model.widgetPlaceSelection.kind == .currentLocation
            ) {
                HapticManager.selectionChanged()
                model.setWidgetPlaceSelection(WidgetPlaceSelection(kind: .currentLocation, savedPlaceID: nil))
            }

            ForEach(model.savedPlaces) { place in
                SettingsSelectionRow(
                    title: place.name,
                    detail: place.subtitle,
                    isSelected: model.widgetPlaceSelection.kind == .savedPlace
                        && model.widgetPlaceSelection.savedPlaceID == place.id
                ) {
                    HapticManager.selectionChanged()
                    model.setWidgetPlaceSelection(WidgetPlaceSelection(kind: .savedPlace, savedPlaceID: place.id))
                }
            }
        }
        .vintageCard()
    }
}

private struct SettingsPollenSection: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsSectionTitle("POLLEN")

            SettingsToggleRow(
                title: "Pollen anzeigen",
                detail: nil,
                isOn: Binding(
                    get: { model.showsPollen },
                    set: { model.setPollenVisibilityEnabled($0) }
                )
            )

            if model.showsPollen {
                ForEach(PollenType.allCases) { type in
                    SettingsToggleRow(
                        title: type.title,
                        detail: type.settingsDetail,
                        isOn: Binding(
                            get: { model.isPollenTypeEnabled(type) },
                            set: { model.setPollenTypeEnabled(type, isEnabled: $0) }
                        )
                    )
                }
            }
        }
        .vintageCard()
    }
}

private struct SettingsLocationSection: View {
    @Bindable var model: AppModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsSectionTitle("STANDORT")

            SettingsStatusRow(
                title: "Zugriff",
                value: model.locationAuthorization.settingsTitle,
                detail: model.locationAuthorization.settingsDetail,
                systemImage: model.locationAuthorization.settingsSystemImage,
                accent: model.locationAuthorization.settingsTint
            )

            if let locationActionTitle {
                SettingsActionButton(title: locationActionTitle) {
                    HapticManager.lightImpact()
                    performLocationAction()
                }
            }
        }
        .vintageCard()
    }

    private var locationActionTitle: String? {
        switch model.locationAuthorization {
        case .notDetermined:
            return "Standortzugriff anfragen"
        case .authorizedAlways, .authorizedWhenInUse:
            return "Standort aktualisieren"
        case .denied, .restricted:
            return "In iOS-Einstellungen"
        @unknown default:
            return nil
        }
    }

    private func performLocationAction() {
        switch model.locationAuthorization {
        case .notDetermined, .authorizedAlways, .authorizedWhenInUse:
            model.requestLocationAccessAndRefresh()
        case .denied, .restricted:
            openSystemSettings()
        @unknown default:
            break
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

private struct SettingsSectionTitle: View {
    private let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(DesignTokens.mono(size: 9, weight: .medium))
            .foregroundStyle(DesignTokens.secondaryText)
    }
}

private struct SettingsPickerBlock<Control: View>: View {
    let title: String
    let detail: String?
    let control: () -> Control

    init(
        title: String,
        detail: String?,
        @ViewBuilder control: @escaping () -> Control
    ) {
        self.title = title
        self.detail = detail
        self.control = control
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(DesignTokens.serif(size: 16, weight: .regular))
                    .foregroundStyle(DesignTokens.ink)

                if let detail {
                    Text(detail)
                        .font(DesignTokens.mono(size: 10))
                        .foregroundStyle(DesignTokens.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            control()
        }
    }
}

private struct SettingsSelectionRow: View {
    let title: String
    let detail: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected ? DesignTokens.toggleAccent : DesignTokens.secondaryText)
                    .frame(width: 20, height: 20)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(DesignTokens.serif(size: 16, weight: .regular))
                        .foregroundStyle(DesignTokens.ink)

                    if let detail, !detail.isEmpty {
                        Text(detail)
                            .font(DesignTokens.mono(size: 10))
                            .foregroundStyle(DesignTokens.tertiaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsStatusRow: View {
    let title: String
    let value: String
    let detail: String?
    let systemImage: String
    let accent: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 18, height: 18)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text(title.uppercased())
                    .font(DesignTokens.mono(size: 9, weight: .medium))
                    .foregroundStyle(DesignTokens.secondaryText)

                Text(value)
                    .font(DesignTokens.serif(size: 16, weight: .regular))
                    .foregroundStyle(DesignTokens.ink)

                if let detail {
                    Text(detail)
                        .font(DesignTokens.mono(size: 10))
                        .foregroundStyle(DesignTokens.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
    }
}

private struct SettingsToggleRow: View {
    let title: String
    let detail: String?
    let providesHapticFeedback: Bool
    @Binding var isOn: Bool

    init(
        title: String,
        detail: String?,
        providesHapticFeedback: Bool = true,
        isOn: Binding<Bool>
    ) {
        self.title = title
        self.detail = detail
        self.providesHapticFeedback = providesHapticFeedback
        self._isOn = isOn
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(DesignTokens.serif(size: 16, weight: .regular))
                    .foregroundStyle(DesignTokens.ink)

                if let detail {
                    Text(detail)
                        .font(DesignTokens.mono(size: 10))
                        .foregroundStyle(DesignTokens.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 12)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(DesignTokens.toggleAccent)
        }
        .onChange(of: isOn) { oldValue, newValue in
            guard providesHapticFeedback, oldValue != newValue else { return }
            HapticManager.selectionChanged()
        }
    }
}

private struct SettingsActionButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DesignTokens.mono(size: 9, weight: .medium))
                .foregroundStyle(DesignTokens.ink)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(DesignTokens.chromeFill)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(DesignTokens.border, lineWidth: 0.8)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct ShakeResponder: UIViewRepresentable {
    var onShake: () -> Void

    func makeUIView(context: Context) -> ShakeResponderView {
        let view = ShakeResponderView()
        view.onShake = onShake
        return view
    }

    func updateUIView(_ uiView: ShakeResponderView, context: Context) {
        uiView.onShake = onShake
        uiView.becomeFirstResponderIfPossible()
    }

    final class ShakeResponderView: UIView {
        var onShake: (() -> Void)?

        override var canBecomeFirstResponder: Bool { true }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            becomeFirstResponderIfPossible()
        }

        func becomeFirstResponderIfPossible() {
            guard window != nil, !isFirstResponder else { return }
            becomeFirstResponder()
        }

        override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
            guard motion == .motionShake else {
                super.motionEnded(motion, with: event)
                return
            }

            onShake?()
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

private extension CLAuthorizationStatus {
    var settingsTitle: String {
        switch self {
        case .authorizedAlways, .authorizedWhenInUse:
            return "Erlaubt"
        case .notDetermined:
            return "Noch nicht gefragt"
        case .denied:
            return "Deaktiviert"
        case .restricted:
            return "Beschraenkt"
        @unknown default:
            return "Unklar"
        }
    }

    var settingsDetail: String? {
        switch self {
        case .authorizedAlways, .authorizedWhenInUse:
            return nil
        case .notDetermined:
            return "Zugriff kann hier angefragt werden."
        case .denied:
            return "In iOS aktivieren."
        case .restricted:
            return "Systemseitig eingeschraenkt."
        @unknown default:
            return nil
        }
    }

    var settingsSystemImage: String {
        switch self {
        case .authorizedAlways, .authorizedWhenInUse:
            return "location.fill"
        case .notDetermined:
            return "location"
        case .denied, .restricted:
            return "location.slash"
        @unknown default:
            return "location"
        }
    }

    var settingsTint: Color {
        switch self {
        case .authorizedAlways, .authorizedWhenInUse:
            return DesignTokens.sun
        case .notDetermined:
            return DesignTokens.secondaryText
        case .denied, .restricted:
            return DesignTokens.rain
        @unknown default:
            return DesignTokens.secondaryText
        }
    }
}

private extension HomeMetricDetail {
    var accent: Color {
        switch self {
        case .apparentTemperature:
            return DesignTokens.sun
        case .wind:
            return DesignTokens.wind
        }
    }

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

    var emptyHeadline: String {
        switch self {
        case .apparentTemperature:
            return "Gefühl noch offen."
        case .wind:
            return "Wind noch offen."
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

@MainActor
private struct HomeViewSheetPreviewHost<Content: View>: View {
    @State private var model = HomeViewSheetPreviewData.makeModel()
    private let title: String
    private let subtitle: String
    private let sheetContent: (AppModel) -> Content

    init(
        title: String,
        subtitle: String,
        @ViewBuilder sheetContent: @escaping (AppModel) -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.sheetContent = sheetContent
    }

    @State private var isPresented = true

    var body: some View {
        let paperPalette = DesignTokens.defaultWeatherPaperPalette

        ZStack {
            Rectangle()
                .fill(.clear)
                .paperBackground()
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                Text("HOMEVIEW PREVIEW")
                    .font(DesignTokens.mono(size: 10, weight: .medium))
                    .foregroundStyle(DesignTokens.secondaryText)

                Text(title)
                    .font(DesignTokens.serif(size: 28, weight: .bold))
                    .foregroundStyle(DesignTokens.ink)

                Text(subtitle)
                    .font(DesignTokens.mono(size: 11))
                    .foregroundStyle(DesignTokens.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(DesignTokens.chromeFill.opacity(0.75))
                    .frame(height: 160)
                    .overlay(alignment: .topLeading) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Dummy View")
                                .font(DesignTokens.mono(size: 10, weight: .medium))
                                .foregroundStyle(DesignTokens.secondaryText)

                            Text("Das eigentliche Sheet wird hier im Preview modally präsentiert.")
                                .font(DesignTokens.mono(size: 11))
                                .foregroundStyle(DesignTokens.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(DesignTokens.border, lineWidth: 0.8)
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(24)
        }
        .sheet(isPresented: $isPresented) {
            sheetContent(model)
                .weatherSheetChrome(paperPalette)
                .presentationDragIndicator(.hidden)
        }
    }
}

@MainActor
private enum HomeViewSheetPreviewData {
    static let timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
    static let now = Calendar.weatherCalendar(timeZone: timeZone).date(from: DateComponents(
        timeZone: timeZone,
        year: 2026,
        month: 4,
        day: 27,
        hour: 11
    )) ?? Date()

    static func makeModel() -> AppModel {
        let repository = WeatherRepository(
            weatherService: WeatherService(),
            cacheStore: ForecastCacheStore()
        )
        let clock = WeatherClock()
        clock.now = now

        let model = AppModel(
            repository: repository,
            placesStore: PlacesStore(),
            settingsStore: SettingsStore(),
            locationService: LocationService(),
            geocodingService: GeocodingService(),
            reachability: ReachabilityMonitor(),
            clock: clock
        )

        let place = SavedPlace.berlin.forecastPlace
        let snapshot = makeSnapshot(for: place)
        let state = makeState(snapshot: snapshot, place: place, now: now)

        model.savedPlaces = [SavedPlace.berlin]
        model.currentLocationPlace = place
        model.activePlaceSelection = .saved(SavedPlace.berlin.id)
        model.weatherState = state
        model.placeSummaries[place.cacheKey] = PlaceWeatherSummary(
            place: place,
            temperature: state.current.temperature,
            weatherCode: state.current.weatherCode,
            isDay: state.current.isDay,
            freshness: state.freshness,
            fetchedAt: snapshot.fetchedAt,
            isConnected: true
        )
        model.isBootstrapping = false
        model.locationAuthorization = .authorizedWhenInUse
        model.hasLiveCurrentLocationFix = true

        return model
    }

    private static func makeState(snapshot: WeatherSnapshot, place: ForecastPlace, now: Date) -> WeatherScreenState {
        let timelineResolver = ForecastTimelineResolver()
        let airQualityResolver = AirQualityResolver()

        return WeatherScreenState(
            place: place,
            snapshot: snapshot,
            freshness: ForecastFreshnessPolicy().freshness(for: snapshot, now: now),
            current: CurrentWeatherResolver().resolve(snapshot: snapshot, now: now),
            airQualityCurrent: airQualityResolver.resolveCurrent(snapshot: snapshot, now: now),
            airQualityHourly: airQualityResolver.resolveHourly(snapshot: snapshot, now: now),
            hourly: timelineResolver.resolveHourly(snapshot: snapshot, now: now),
            daily: timelineResolver.resolveDaily(snapshot: snapshot, now: now),
            nextSunEvent: timelineResolver.nextSunEvent(snapshot: snapshot, now: now),
            isConnected: true
        )
    }

    private static func makeSnapshot(for place: ForecastPlace) -> WeatherSnapshot {
        let calendar = Calendar.weatherCalendar(timeZone: timeZone)
        let startOfToday = calendar.startOfDay(for: now)
        let uvPeaks = [6.8, 4.2, 5.5, 7.4, 3.8, 6.1, 5.0, 6.6, 4.9, 5.7]

        let hourly = (0..<(10 * 24)).compactMap { offset -> HourlyForecastEntry? in
            guard let timestamp = calendar.date(byAdding: .hour, value: offset, to: startOfToday) else {
                return nil
            }

            let dayIndex = offset / 24
            let hour = calendar.component(.hour, from: timestamp)
            let daylightProgress = max(0, 1 - abs(Double(hour) - 13) / 6)
            let temperature = 11.5 + Double(dayIndex) * 0.6 + sin((Double(hour) - 6) / 24 * .pi * 2) * 6.4
            let windSpeed = 7 + Double((dayIndex + 1) * 2) + (1 - daylightProgress) * 8 + Double((hour + dayIndex) % 5)
            let uvIndex = daylightProgress > 0 ? uvPeaks[dayIndex] * daylightProgress : 0

            let afternoonRain = (dayIndex == 1 || dayIndex == 4 || dayIndex == 8) && (13...18).contains(hour)
            let morningShowers = dayIndex == 6 && (6...10).contains(hour)
            let precipitationProbability: Double
            let precipitation: Double

            if afternoonRain {
                precipitationProbability = 54 + Double((hour - 13) * 7)
                precipitation = 0.7 + Double(hour - 13) * 0.22
            } else if morningShowers {
                precipitationProbability = 36 + Double((10 - hour) * 5)
                precipitation = 0.3 + Double(10 - hour) * 0.16
            } else {
                let dryProbabilityBase = Double(18 - abs(13 - hour) * 2)
                let dayAdjustment = Double(dayIndex % 3) * 3
                precipitationProbability = max(4, dryProbabilityBase + dayAdjustment)
                precipitation = precipitationProbability >= 22 ? 0.1 : 0
            }

            let isDay = (6...20).contains(hour)
            let weatherCode: Int
            if precipitationProbability >= 60 {
                weatherCode = 63
            } else if precipitationProbability >= 35 {
                weatherCode = 61
            } else if isDay && uvIndex > 5.5 {
                weatherCode = 1
            } else if isDay {
                weatherCode = 2
            } else {
                weatherCode = 3
            }

            return HourlyForecastEntry(
                timestamp: timestamp,
                temperature: temperature,
                apparentTemperature: temperature - max((windSpeed - 14) * 0.12, 0) + uvIndex * 0.08,
                precipitationProbability: min(precipitationProbability, 95),
                precipitation: precipitation,
                uvIndex: uvIndex,
                windSpeed: windSpeed,
                weatherCode: weatherCode,
                isDay: isDay,
                relativeHumidity: 52 + (1 - daylightProgress) * 22
            )
        }

        let daily = (0..<10).compactMap { dayIndex -> DailyForecastEntry? in
            guard let date = calendar.date(byAdding: .day, value: dayIndex, to: startOfToday) else {
                return nil
            }

            let dayHours = hourly.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
            guard !dayHours.isEmpty else { return nil }

            let sunriseMinutes = 6 * 60 + 4 + dayIndex
            let sunsetMinutes = 20 * 60 + 18 + dayIndex
            let middayHour = dayHours.first(where: { calendar.component(.hour, from: $0.timestamp) == 13 }) ?? dayHours[12]

            return DailyForecastEntry(
                date: date,
                temperatureMin: dayHours.map(\.temperature).min() ?? 0,
                temperatureMax: dayHours.map(\.temperature).max() ?? 0,
                sunrise: calendar.date(byAdding: .minute, value: sunriseMinutes, to: date),
                sunset: calendar.date(byAdding: .minute, value: sunsetMinutes, to: date),
                uvIndexMax: dayHours.compactMap(\.uvIndex).max(),
                weatherCode: middayHour.weatherCode,
                precipitationProbabilityMax: dayHours.map(\.precipitationProbability).max() ?? 0
            )
        }

        let currentHour = hourly.first(where: { calendar.isDate($0.timestamp, equalTo: now, toGranularity: .hour) }) ?? hourly[11]
        let minutely15 = (0...12).compactMap { offset -> MinutelyForecastEntry? in
            guard let timestamp = calendar.date(byAdding: .minute, value: offset * 15, to: now) else {
                return nil
            }

            let precipitation = (5...8).contains(offset) ? 0.18 + Double(offset - 5) * 0.05 : 0
            return MinutelyForecastEntry(
                timestamp: timestamp,
                precipitation: precipitation,
                rain: precipitation,
                weatherCode: precipitation > 0 ? 61 : 2,
                isDay: true
            )
        }
        let airQualityHours = hourly.prefix(96).enumerated().map { offset, hour in
            let dayIndex = offset / 24
            let daytimeBoost = max((hour.uvIndex ?? 0) * 2.1, 0)
            let pm2_5 = 7 + Double((offset + dayIndex) % 6) + daytimeBoost * 0.35
            let pm10 = pm2_5 + 5 + Double((offset + 2) % 7)

            let birchBase = dayIndex < 2 ? 18.0 : max(4.0, 14.0 - Double(dayIndex) * 2.8)
            let grassBase = 4.0 + Double(dayIndex) * 2.4 + max(Double(calendar.component(.hour, from: hour.timestamp) - 10), 0) * 0.18
            let mugwortBase = dayIndex > 1 ? 2.5 + Double(dayIndex - 1) * 1.4 : 0.4

            return AirQualityHourlyEntry(
                timestamp: hour.timestamp,
                europeanAQI: min(72, pm10 + 12),
                pm2_5: pm2_5,
                pm10: pm10,
                alderPollen: dayIndex == 0 ? max(0, birchBase * 0.45 - 3) : max(0, birchBase * 0.18 - 1),
                birchPollen: max(0, birchBase + daytimeBoost * 0.8),
                grassPollen: max(0, grassBase + daytimeBoost * 0.6),
                mugwortPollen: max(0, mugwortBase + daytimeBoost * 0.24),
                olivePollen: dayIndex >= 2 ? max(0, 1.0 + Double(dayIndex - 2) * 1.5) : 0,
                ragweedPollen: dayIndex >= 3 ? max(0, 0.5 + Double(dayIndex - 3) * 1.2) : 0
            )
        }
        let currentAirQuality = airQualityHours.first(where: {
            calendar.isDate($0.timestamp, equalTo: now, toGranularity: .hour)
        }) ?? airQualityHours[11]

        return WeatherSnapshot(
            placeName: place.name,
            latitude: place.latitude,
            longitude: place.longitude,
            timezoneIdentifier: timeZone.identifier,
            utcOffsetSeconds: timeZone.secondsFromGMT(for: now),
            fetchedAt: now.addingTimeInterval(-300),
            current: CurrentWeatherSnapshot(
                time: now,
                temperature: currentHour.temperature,
                apparentTemperature: currentHour.apparentTemperature,
                relativeHumidity: currentHour.relativeHumidity,
                uvIndex: currentHour.uvIndex,
                windSpeed: currentHour.windSpeed,
                weatherCode: currentHour.weatherCode,
                isDay: currentHour.isDay
            ),
            hourly: hourly,
            daily: daily,
            airQuality: AirQualitySnapshot(
                current: AirQualityCurrentSnapshot(
                    time: now,
                    europeanAQI: currentAirQuality.europeanAQI,
                    pm2_5: currentAirQuality.pm2_5,
                    pm10: currentAirQuality.pm10,
                    alderPollen: currentAirQuality.alderPollen,
                    birchPollen: currentAirQuality.birchPollen,
                    grassPollen: currentAirQuality.grassPollen,
                    mugwortPollen: currentAirQuality.mugwortPollen,
                    olivePollen: currentAirQuality.olivePollen,
                    ragweedPollen: currentAirQuality.ragweedPollen
                ),
                hourly: airQualityHours
            ),
            minutely15: minutely15
        )
    }
}

@MainActor
private struct HomeViewHeroPreviewHost: View {
    @State private var model = HomeViewSheetPreviewData.makeModel()

    var body: some View {
        HomeView(model: model)
            .preferredColorScheme(.light)
    }
}

#Preview("HomeView Hero") {
    HomeViewHeroPreviewHost()
}
/*
#Preview("Zukunft Sheet") {
    HomeViewSheetPreviewHost(
        title: "Zukunft",
        subtitle: "Preview der Wochenansicht als echtes Sheet mit derselben Höhe wie in HomeView."
    ) { model in
        WeekView(model: model)
            .presentationDetents([.fraction(0.75)])
            .presentationDragIndicator(.hidden)
    }
}

#Preview("Niederschlag Sheet") {
    HomeViewSheetPreviewHost(
        title: "Niederschlag",
        subtitle: "Preview des Niederschlags-Sheets mit identischer Detent-Konfiguration."
    ) { model in
        PrecipitationSheet(model: model)
            .presentationDetents([.fraction(0.75)])
            .presentationDragIndicator(.hidden)
    }
}

#Preview("UV Sheet") {
    HomeViewSheetPreviewHost(
        title: "UV",
        subtitle: "Preview des UV-Sheets als modales Sheet inklusive Scroll-Interaktion."
    ) { model in
        UVSheet(model: model)
            .presentationDetents([.fraction(0.65)])
            .presentationContentInteraction(.scrolls)
            .presentationDragIndicator(.hidden)
    }
}

#Preview("Sonne Sheet") {
    HomeViewSheetPreviewHost(
        title: "Sonne",
        subtitle: "Preview des Sonnen-Sheets mit denselben Präsentationsgrößen wie im Home-Screen."
    ) { model in
        SunSheet(model: model)
            .presentationDetents([.fraction(0.65)])
            .presentationContentInteraction(.scrolls)
            .presentationDragIndicator(.hidden)
    }
}

#Preview("Mond Sheet") {
    HomeViewSheetPreviewHost(
        title: "Mond",
        subtitle: "Preview des Mond-Sheets mit der höheren 0.8-Detent aus HomeView."
    ) { model in
        MoonSheet(model: model)
            .presentationDetents([.fraction(0.8)])
            .presentationContentInteraction(.scrolls)
            .presentationDragIndicator(.hidden)
    }
}

#Preview("Gefühlt Sheet") {
    HomeViewSheetPreviewHost(
        title: "Gefühlte Temperatur",
        subtitle: "Preview des Detail-Sheets für die gefühlte Temperatur als modales Sheet."
    ) { model in
        HomeMetricDetailSheet(model: model, detail: .apparentTemperature)
            .presentationDetents([.fraction(0.65)])
            .presentationDragIndicator(.hidden)
    }
}

#Preview("Wind Sheet") {
    HomeViewSheetPreviewHost(
        title: "Wind",
        subtitle: "Preview des Detail-Sheets für Wind mit derselben Höhe wie im HomeView."
    ) { model in
        HomeMetricDetailSheet(model: model, detail: .wind)
            .presentationDetents([.fraction(0.65)])
            .presentationDragIndicator(.hidden)
    }
}
*/
