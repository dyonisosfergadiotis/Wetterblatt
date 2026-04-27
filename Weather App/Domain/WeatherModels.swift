import Foundation

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
