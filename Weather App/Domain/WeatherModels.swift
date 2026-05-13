import Foundation

enum MoonPhaseKind: Sendable {
    case newMoon
    case waxingCrescent
    case firstQuarter
    case waxingGibbous
    case fullMoon
    case waningGibbous
    case lastQuarter
    case waningCrescent
}

struct MoonPhaseInfo: Sendable {
    let kind: MoonPhaseKind
    let title: String
    let detail: String
    let age: Double
    let illuminationFraction: Double
    let isWaxing: Bool
}

enum MoonPhaseResolver {
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

nonisolated struct SavedPlace: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var subtitle: String
    var latitude: Double
    var longitude: Double
    var timezoneIdentifier: String?

    var forecastPlace: ForecastPlace {
        ForecastPlace(
            id: id.uuidString,
            name: name,
            subtitle: subtitle,
            latitude: latitude,
            longitude: longitude,
            timezoneIdentifier: timezoneIdentifier,
            kind: .saved
        )
    }

    static let berlin = SavedPlace(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        name: "Berlin",
        subtitle: "Deutschland",
        latitude: 52.52,
        longitude: 13.41,
        timezoneIdentifier: "Europe/Berlin"
    )
}

nonisolated struct ForecastPlace: Identifiable, Hashable, Sendable {
    nonisolated enum Kind: String, Sendable {
        case currentLocation
        case saved
    }

    static let currentLocationCacheKey = "current-location"

    let id: String
    var name: String
    var subtitle: String
    var latitude: Double
    var longitude: Double
    var timezoneIdentifier: String?
    var kind: Kind

    var cacheKey: String { id }

    static func currentLocation(
        name: String,
        subtitle: String,
        latitude: Double,
        longitude: Double,
        timezoneIdentifier: String?
    ) -> ForecastPlace {
        ForecastPlace(
            id: currentLocationCacheKey,
            name: name,
            subtitle: subtitle,
            latitude: latitude,
            longitude: longitude,
            timezoneIdentifier: timezoneIdentifier,
            kind: .currentLocation
        )
    }
}

nonisolated enum ActivePlaceSelection: Hashable, Sendable {
    case currentLocation
    case saved(UUID)
}

nonisolated enum TemperatureUnitPreference: String, Codable, CaseIterable, Identifiable, Sendable {
    case celsius
    case fahrenheit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .celsius:
            return "Celsius"
        case .fahrenheit:
            return "Fahrenheit"
        }
    }

    var shortTitle: String {
        switch self {
        case .celsius:
            return "°C"
        case .fahrenheit:
            return "°F"
        }
    }
}

nonisolated enum WindSpeedUnitPreference: String, Codable, CaseIterable, Identifiable, Sendable {
    case kilometersPerHour
    case metersPerSecond

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kilometersPerHour:
            return "km/h"
        case .metersPerSecond:
            return "m/s"
        }
    }
}

nonisolated enum PrecipitationUnitPreference: String, Codable, CaseIterable, Identifiable, Sendable {
    case millimeters
    case inches

    var id: String { rawValue }

    var title: String {
        switch self {
        case .millimeters:
            return "mm"
        case .inches:
            return "inch"
        }
    }
}

nonisolated enum HeroThemeMatchMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case all
    case any

    var id: String { rawValue }
}

nonisolated enum HeroThemeCriterion: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case rain
    case heavyRain
    case thunderstorm
    case strongWind
    case heat
    case frost
    case highUV
    case poorAir
    case pollen
    case fog
    case snow

    var id: String { rawValue }
}

nonisolated struct HeroThemeCriterionSelection: Codable, Identifiable, Hashable, Sendable {
    var criterion: HeroThemeCriterion
    var isNegated: Bool

    var id: String {
        "\(criterion.rawValue)-\(isNegated ? "not" : "yes")"
    }

    init(criterion: HeroThemeCriterion, isNegated: Bool = false) {
        self.criterion = criterion
        self.isNegated = isNegated
    }
}

nonisolated struct HeroThemeColor: Codable, Hashable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    static let `default` = HeroThemeColor(red: 0.64, green: 0.43, blue: 0.14, alpha: 1)
}

nonisolated struct HeroThemeRule: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var title: String
    var color: HeroThemeColor
    var matchMode: HeroThemeMatchMode
    var criteria: [HeroThemeCriterionSelection]

    init(
        id: UUID = UUID(),
        title: String,
        color: HeroThemeColor = .default,
        matchMode: HeroThemeMatchMode = .all,
        criteria: [HeroThemeCriterionSelection]
    ) {
        self.id = id
        self.title = title
        self.color = color
        self.matchMode = matchMode
        self.criteria = criteria
    }
}

nonisolated enum WidgetPlaceSelectionKind: String, Codable, Sendable {
    case followActivePlace
    case currentLocation
    case savedPlace
}

nonisolated struct WidgetPlaceSelection: Codable, Hashable, Sendable {
    var kind: WidgetPlaceSelectionKind
    var savedPlaceID: UUID?

    static let `default` = WidgetPlaceSelection(kind: .followActivePlace, savedPlaceID: nil)
}

nonisolated struct PlaceSearchResult: Identifiable, Hashable, Sendable {
    let id: String
    var name: String
    var subtitle: String
    var latitude: Double
    var longitude: Double
    var timezoneIdentifier: String?

    init(
        name: String,
        subtitle: String,
        latitude: Double,
        longitude: Double,
        timezoneIdentifier: String?
    ) {
        self.id = "\(name)-\(latitude)-\(longitude)"
        self.name = name
        self.subtitle = subtitle
        self.latitude = latitude
        self.longitude = longitude
        self.timezoneIdentifier = timezoneIdentifier
    }

    var savedPlace: SavedPlace {
        SavedPlace(
            id: UUID(),
            name: name,
            subtitle: subtitle,
            latitude: latitude,
            longitude: longitude,
            timezoneIdentifier: timezoneIdentifier
        )
    }
}

nonisolated enum ForecastFreshness: String, Codable, Sendable {
    case fresh
    case aging
    case stale
}

nonisolated enum CurrentWeatherSource: String, Sendable {
    case liveCurrent
    case hourlyFallback
    case staleForecast
}

nonisolated enum SunEventKind: String, Sendable {
    case sunrise
    case sunset
}

nonisolated enum PollenType: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case alder
    case birch
    case grass
    case mugwort
    case olive
    case ragweed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .alder:
            return "Erle"
        case .birch:
            return "Birke"
        case .grass:
            return "Gräser"
        case .mugwort:
            return "Beifuß"
        case .olive:
            return "Olive"
        case .ragweed:
            return "Ragweed"
        }
    }

    var settingsDetail: String {
        switch self {
        case .alder:
            return "Frühe Baumpollen, oft schon vor dem eigentlichen Frühling."
        case .birch:
            return "Klassischer Frühlingspollen mit oft deutlicher Belastung."
        case .grass:
            return "Typisch ab spätem Frühjahr, oft lang anhaltend."
        case .mugwort:
            return "Sommer- bis Spätsommerpollen mit trockenem Charakter."
        case .olive:
            return "Vor allem relevant bei Reisen oder mediterranen Lagen."
        case .ragweed:
            return "Spätsommerpollen, für viele sehr reizstark."
        }
    }

    func severity(for value: Double?) -> PollenSeverity {
        guard let value else { return .unavailable }

        switch self {
        case .alder, .birch, .olive:
            switch value {
            case ..<1:
                return .none
            case ..<10:
                return .low
            case ..<50:
                return .medium
            default:
                return .high
            }
        case .grass, .mugwort:
            switch value {
            case ..<1:
                return .none
            case ..<5:
                return .low
            case ..<25:
                return .medium
            default:
                return .high
            }
        case .ragweed:
            switch value {
            case ..<1:
                return .none
            case ..<5:
                return .low
            case ..<15:
                return .medium
            default:
                return .high
            }
        }
    }
}

nonisolated enum PollenSeverity: Int, Codable, Comparable, Sendable {
    case unavailable
    case none
    case low
    case medium
    case high

    static func < (lhs: PollenSeverity, rhs: PollenSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var isActive: Bool {
        switch self {
        case .low, .medium, .high:
            return true
        case .unavailable, .none:
            return false
        }
    }

    var title: String {
        switch self {
        case .unavailable:
            return "Unklar"
        case .none:
            return "Ruhe"
        case .low:
            return "Leicht"
        case .medium:
            return "Mittel"
        case .high:
            return "Stark"
        }
    }

    var detailTitle: String {
        switch self {
        case .unavailable:
            return "Keine Daten"
        case .none:
            return "Ruhig"
        case .low:
            return "Leicht"
        case .medium:
            return "Mittel"
        case .high:
            return "Stark"
        }
    }
}

nonisolated enum EuropeanAQICategory: String, CaseIterable, Codable, Sendable {
    case good
    case fair
    case moderate
    case poor
    case veryPoor
    case extremelyPoor

    init(value: Double) {
        switch value {
        case ..<20:
            self = .good
        case ..<40:
            self = .fair
        case ..<60:
            self = .moderate
        case ..<80:
            self = .poor
        case ..<100:
            self = .veryPoor
        default:
            self = .extremelyPoor
        }
    }

    var title: String {
        switch self {
        case .good:
            return "Gut"
        case .fair:
            return "Mäßig"
        case .moderate:
            return "Erhöht"
        case .poor:
            return "Schlecht"
        case .veryPoor:
            return "Sehr schlecht"
        case .extremelyPoor:
            return "Extrem schlecht"
        }
    }

    var scalePosition: Int {
        switch self {
        case .good:
            return 1
        case .fair:
            return 2
        case .moderate:
            return 3
        case .poor:
            return 4
        case .veryPoor:
            return 5
        case .extremelyPoor:
            return 6
        }
    }

    static var scaleCount: Int {
        allCases.count
    }

    var rangeDescription: String {
        switch self {
        case .good:
            return "0-19"
        case .fair:
            return "20-39"
        case .moderate:
            return "40-59"
        case .poor:
            return "60-79"
        case .veryPoor:
            return "80-99"
        case .extremelyPoor:
            return "100+"
        }
    }

    var scaleDescription: String {
        "Stufe \(scalePosition)/\(Self.scaleCount)"
    }

    var compactScaleDescription: String {
        "\(scalePosition)/\(Self.scaleCount) · \(rangeDescription)"
    }

    var comparableDescription: String {
        "\(scaleDescription) · EU-AQI \(rangeDescription)"
    }
}

nonisolated struct AirQualitySnapshot: Codable, Sendable {
    var current: AirQualityCurrentSnapshot?
    var hourly: [AirQualityHourlyEntry]
}

nonisolated struct AirQualityCurrentSnapshot: Codable, Sendable {
    var time: Date
    var europeanAQI: Double?
    var pm2_5: Double?
    var pm10: Double?
    var alderPollen: Double?
    var birchPollen: Double?
    var grassPollen: Double?
    var mugwortPollen: Double?
    var olivePollen: Double?
    var ragweedPollen: Double?

    func pollenValue(for type: PollenType) -> Double? {
        switch type {
        case .alder:
            return alderPollen
        case .birch:
            return birchPollen
        case .grass:
            return grassPollen
        case .mugwort:
            return mugwortPollen
        case .olive:
            return olivePollen
        case .ragweed:
            return ragweedPollen
        }
    }
}

nonisolated struct AirQualityHourlyEntry: Codable, Identifiable, Hashable, Sendable {
    var id: Date { timestamp }

    var timestamp: Date
    var europeanAQI: Double?
    var pm2_5: Double?
    var pm10: Double?
    var alderPollen: Double?
    var birchPollen: Double?
    var grassPollen: Double?
    var mugwortPollen: Double?
    var olivePollen: Double?
    var ragweedPollen: Double?

    func pollenValue(for type: PollenType) -> Double? {
        switch type {
        case .alder:
            return alderPollen
        case .birch:
            return birchPollen
        case .grass:
            return grassPollen
        case .mugwort:
            return mugwortPollen
        case .olive:
            return olivePollen
        case .ragweed:
            return ragweedPollen
        }
    }
}

nonisolated struct WeatherSnapshot: Codable, Sendable {
    var placeName: String
    var latitude: Double
    var longitude: Double
    var timezoneIdentifier: String
    var utcOffsetSeconds: Int
    var fetchedAt: Date
    var current: CurrentWeatherSnapshot?
    var hourly: [HourlyForecastEntry]
    var daily: [DailyForecastEntry]
    var airQuality: AirQualitySnapshot?
    var minutely15: [MinutelyForecastEntry]?

    var timeZone: TimeZone {
        TimeZone(identifier: timezoneIdentifier)
            ?? TimeZone(secondsFromGMT: utcOffsetSeconds)
            ?? .current
    }
}

nonisolated struct CurrentWeatherSnapshot: Codable, Sendable {
    var time: Date
    var temperature: Double
    var apparentTemperature: Double
    var relativeHumidity: Double?
    var uvIndex: Double?
    var windSpeed: Double
    var weatherCode: Int
    var isDay: Bool
}

nonisolated struct HourlyForecastEntry: Codable, Identifiable, Hashable, Sendable {
    var id: Date { timestamp }

    var timestamp: Date
    var temperature: Double
    var apparentTemperature: Double
    var precipitationProbability: Double
    var precipitation: Double
    var uvIndex: Double?
    var windSpeed: Double
    var weatherCode: Int
    var isDay: Bool
    var relativeHumidity: Double?
}

nonisolated struct MinutelyForecastEntry: Codable, Identifiable, Hashable, Sendable {
    var id: Date { timestamp }

    var timestamp: Date
    var precipitation: Double
    var rain: Double?
    var weatherCode: Int
    var isDay: Bool
}

nonisolated struct DailyForecastEntry: Codable, Identifiable, Hashable, Sendable {
    var id: Date { date }

    var date: Date
    var temperatureMin: Double
    var temperatureMax: Double
    var sunrise: Date?
    var sunset: Date?
    var uvIndexMax: Double?
    var weatherCode: Int
    var precipitationProbabilityMax: Double
}

nonisolated struct ResolvedCurrentWeather: Sendable {
    var timestamp: Date
    var temperature: Double
    var apparentTemperature: Double
    var relativeHumidity: Double?
    var uvIndex: Double?
    var windSpeed: Double
    var weatherCode: Int
    var isDay: Bool
    var source: CurrentWeatherSource
}

nonisolated struct ResolvedAirQualityMoment: Identifiable, Hashable, Sendable {
    var id: Date { timestamp }

    var timestamp: Date
    var europeanAQI: Double?
    var pm2_5: Double?
    var pm10: Double?
    var alderPollen: Double?
    var birchPollen: Double?
    var grassPollen: Double?
    var mugwortPollen: Double?
    var olivePollen: Double?
    var ragweedPollen: Double?

    func pollenValue(for type: PollenType) -> Double? {
        switch type {
        case .alder:
            return alderPollen
        case .birch:
            return birchPollen
        case .grass:
            return grassPollen
        case .mugwort:
            return mugwortPollen
        case .olive:
            return olivePollen
        case .ragweed:
            return ragweedPollen
        }
    }
}

nonisolated struct ResolvedHourlyForecast: Identifiable, Hashable, Sendable {
    var id: Date { timestamp }

    var timestamp: Date
    var temperature: Double
    var apparentTemperature: Double
    var precipitationProbability: Double
    var precipitation: Double
    var uvIndex: Double?
    var windSpeed: Double
    var weatherCode: Int
    var isDay: Bool
    var relativeHumidity: Double?
    var isPast: Bool
    var isCurrentHour: Bool
    var displayLabel: String
}

nonisolated struct ResolvedDailyForecast: Identifiable, Hashable, Sendable {
    var id: Date { date }

    var date: Date
    var temperatureMin: Double
    var temperatureMax: Double
    var sunrise: Date?
    var sunset: Date?
    var uvIndexMax: Double?
    var weatherCode: Int
    var precipitationProbabilityMax: Double
    var displayLabel: String
    var isToday: Bool
}

nonisolated struct ResolvedSunEvent: Sendable {
    var kind: SunEventKind
    var date: Date
    var relativeDescription: String
}

nonisolated struct WeatherScreenState: Sendable {
    var place: ForecastPlace
    var snapshot: WeatherSnapshot
    var freshness: ForecastFreshness
    var current: ResolvedCurrentWeather
    var airQualityCurrent: ResolvedAirQualityMoment?
    var airQualityHourly: [ResolvedAirQualityMoment]
    var hourly: [ResolvedHourlyForecast]
    var daily: [ResolvedDailyForecast]
    var nextSunEvent: ResolvedSunEvent?
    var isConnected: Bool
}

nonisolated struct PlaceWeatherSummary: Sendable {
    var place: ForecastPlace
    var temperature: Double
    var weatherCode: Int
    var isDay: Bool
    var freshness: ForecastFreshness
    var fetchedAt: Date
    var isConnected: Bool
}

nonisolated struct WeatherConditionDescriptor: Sendable {
    var title: String
    var symbolName: String
}

enum WeatherConditions {
    static func isWetWeatherCode(_ code: Int) -> Bool {
        switch code {
        case 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 71, 73, 75, 77, 80, 81, 82, 85, 86, 95, 96, 99:
            return true
        default:
            return false
        }
    }

    static func descriptor(for code: Int, isDay: Bool) -> WeatherConditionDescriptor {
        switch code {
        case 0:
            return WeatherConditionDescriptor(title: "Klar", symbolName: isDay ? "sun.max.fill" : "moon.stars.fill")
        case 1, 2:
            return WeatherConditionDescriptor(title: "Leicht bewölkt", symbolName: isDay ? "cloud.sun.fill" : "cloud.moon.fill")
        case 3:
            return WeatherConditionDescriptor(title: "Bedeckt", symbolName: "cloud.fill")
        case 45, 48:
            return WeatherConditionDescriptor(title: "Nebel", symbolName: "cloud.fog.fill")
        case 51, 53, 55, 56, 57:
            return WeatherConditionDescriptor(title: "Nieselregen", symbolName: "cloud.drizzle.fill")
        case 61, 63, 65, 66, 67, 80, 81, 82:
            return WeatherConditionDescriptor(title: "Regen", symbolName: "cloud.rain.fill")
        case 71, 73, 75, 77, 85, 86:
            return WeatherConditionDescriptor(title: "Schnee", symbolName: "snowflake")
        case 95, 96, 99:
            return WeatherConditionDescriptor(title: "Gewitter", symbolName: "cloud.bolt.rain.fill")
        default:
            return WeatherConditionDescriptor(title: "Wetter", symbolName: "cloud.fill")
        }
    }
}
