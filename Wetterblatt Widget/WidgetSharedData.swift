import Foundation

enum WidgetSharedStore {
    static let appGroupIdentifier = "group.DyonisosFergadiotis.Wetterblatt"
    static let rootFolderName = "WetterblattShared"

    static func rootURL(fileManager: FileManager = .default) -> URL? {
        fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(rootFolderName, isDirectory: true)
    }
}

struct WidgetSavedPlace: Decodable, Identifiable {
    let id: UUID
    var name: String
    var subtitle: String
}

struct WidgetPersistedPlacesDocument: Decodable {
    var savedPlaces: [WidgetSavedPlace]
    var preferredSavedPlaceID: UUID?
    var prefersCurrentLocation: Bool

    static let fallback = WidgetPersistedPlacesDocument(
        savedPlaces: [],
        preferredSavedPlaceID: nil,
        prefersCurrentLocation: true
    )
}

struct WidgetWeatherSnapshot: Decodable {
    var placeName: String
    var latitude: Double
    var longitude: Double
    var timezoneIdentifier: String
    var utcOffsetSeconds: Int
    var fetchedAt: Date
    var current: WidgetCurrentWeatherSnapshot?
    var hourly: [WidgetHourlyForecastEntry]
    var daily: [WidgetDailyForecastEntry]

    var timeZone: TimeZone {
        TimeZone(identifier: timezoneIdentifier)
            ?? TimeZone(secondsFromGMT: utcOffsetSeconds)
            ?? .current
    }
}

struct WidgetCurrentWeatherSnapshot: Decodable {
    var time: Date
    var temperature: Double
    var apparentTemperature: Double
    var relativeHumidity: Double?
    var windSpeed: Double
    var weatherCode: Int
    var isDay: Bool
}

struct WidgetHourlyForecastEntry: Decodable, Identifiable {
    var id: Date { timestamp }

    var timestamp: Date
    var temperature: Double
    var apparentTemperature: Double
    var precipitationProbability: Double
    var precipitation: Double
    var windSpeed: Double
    var weatherCode: Int
    var isDay: Bool
    var relativeHumidity: Double?
}

struct WidgetDailyForecastEntry: Decodable, Identifiable {
    var id: Date { date }

    var date: Date
    var temperatureMin: Double
    var temperatureMax: Double
    var sunrise: Date?
    var sunset: Date?
    var weatherCode: Int
    var precipitationProbabilityMax: Double
}

enum WidgetForecastFreshness {
    case fresh
    case aging
    case stale

    var label: String {
        switch self {
        case .fresh:
            return "Frisch"
        case .aging:
            return "Älter"
        case .stale:
            return "Archiv"
        }
    }
}

struct WidgetConditionDescriptor {
    var title: String
    var symbolName: String
}

enum WidgetSunEventKind {
    case sunrise
    case sunset
}

struct WidgetResolvedSunEvent {
    var kind: WidgetSunEventKind
    var date: Date
    var label: String
}

struct WidgetResolvedCurrentWeather {
    var timestamp: Date
    var temperature: Double
    var apparentTemperature: Double
    var relativeHumidity: Double?
    var windSpeed: Double
    var weatherCode: Int
    var isDay: Bool
}

struct WidgetResolvedHour: Identifiable {
    var id: Date { timestamp }

    var timestamp: Date
    var label: String
    var shortLabel: String
    var temperature: Double
    var precipitationProbability: Double
    var precipitation: Double
    var weatherCode: Int
    var isDay: Bool
    var isCurrentHour: Bool
}

struct WidgetResolvedDay: Identifiable {
    var id: Date { date }

    var date: Date
    var label: String
    var shortLabel: String
    var temperatureMin: Double
    var temperatureMax: Double
    var weatherCode: Int
    var precipitationProbabilityMax: Double
    var isToday: Bool
}

struct WidgetWeatherDisplayState {
    var placeName: String
    var subtitle: String
    var timeZone: TimeZone
    var fetchedAt: Date
    var freshness: WidgetForecastFreshness
    var current: WidgetResolvedCurrentWeather
    var hourly: [WidgetResolvedHour]
    var daily: [WidgetResolvedDay]
    var today: WidgetDailyForecastEntry?
    var nextSunEvent: WidgetResolvedSunEvent?

    var descriptor: WidgetConditionDescriptor {
        WidgetWeatherConditions.descriptor(for: current.weatherCode, isDay: current.isDay)
    }

    var temperatureText: String {
        "\(Int(current.temperature.rounded()))°"
    }

    var apparentText: String {
        "\(Int(current.apparentTemperature.rounded()))°"
    }

    var windText: String {
        "\(Int(current.windSpeed.rounded())) km/h"
    }

    var humidityText: String {
        guard let relativeHumidity = current.relativeHumidity else { return "—" }
        return "\(Int(relativeHumidity.rounded())) %"
    }

    var stampText: String {
        "Stand \(WidgetFormatters.time.string(from: fetchedAt, timeZone: timeZone))"
    }

    var highLowText: String {
        guard let today else { return "—" }
        return "\(Int(today.temperatureMin.rounded()))° / \(Int(today.temperatureMax.rounded()))°"
    }

    var rainChanceText: String {
        guard let today else { return "—" }
        return "\(Int(today.precipitationProbabilityMax.rounded())) %"
    }

    var nextSunText: String {
        guard let nextSunEvent else { return "—" }
        return WidgetFormatters.time.string(from: nextSunEvent.date, timeZone: timeZone)
    }

    var nextSunLabel: String {
        guard let nextSunEvent else { return "Licht" }
        return nextSunEvent.label
    }

    var nextWetHour: WidgetResolvedHour? {
        hourly.first {
            $0.precipitationProbability >= 25 || $0.precipitation >= 0.2
        }
    }

    var peakRainHour: WidgetResolvedHour? {
        hourly.max { lhs, rhs in
            if lhs.precipitationProbability == rhs.precipitationProbability {
                return lhs.precipitation < rhs.precipitation
            }

            return lhs.precipitationProbability < rhs.precipitationProbability
        }
    }

    var rainLeadText: String {
        if let nextWetHour {
            return "\(Int(nextWetHour.precipitationProbability.rounded())) % ab \(WidgetFormatters.time.string(from: nextWetHour.timestamp, timeZone: timeZone))"
        }

        if let peakRainHour {
            return "\(Int(peakRainHour.precipitationProbability.rounded())) % heute"
        }

        return "Trocken in Sicht"
    }

    var precipitationAmountText: String {
        let total = hourly.reduce(0) { $0 + $1.precipitation }
        if total < 0.1 {
            return "0 mm"
        }

        if total < 1 {
            return String(format: "%.1f mm", locale: Locale(identifier: "de_DE"), total)
        }

        return "\(Int(total.rounded())) mm"
    }

    var weeklyTemperatureRange: ClosedRange<Double> {
        let minimum = daily.map(\.temperatureMin).min() ?? current.temperature
        let maximum = max(daily.map(\.temperatureMax).max() ?? current.temperature, minimum + 1)
        return minimum...maximum
    }

    var rectangularMetaText: String {
        if nextSunEvent != nil {
            return "\(nextSunLabel) \(nextSunText)"
        }

        return "Spanne \(highLowText)"
    }
}

enum WidgetWeatherConditions {
    static func descriptor(for code: Int, isDay: Bool) -> WidgetConditionDescriptor {
        switch code {
        case 0:
            return WidgetConditionDescriptor(title: "Klar", symbolName: isDay ? "sun.max.fill" : "moon.stars.fill")
        case 1, 2:
            return WidgetConditionDescriptor(title: "Leicht bewölkt", symbolName: isDay ? "cloud.sun.fill" : "cloud.moon.fill")
        case 3:
            return WidgetConditionDescriptor(title: "Bedeckt", symbolName: "cloud.fill")
        case 45, 48:
            return WidgetConditionDescriptor(title: "Nebel", symbolName: "cloud.fog.fill")
        case 51, 53, 55, 56, 57:
            return WidgetConditionDescriptor(title: "Nieselregen", symbolName: "cloud.drizzle.fill")
        case 61, 63, 65, 66, 67, 80, 81, 82:
            return WidgetConditionDescriptor(title: "Regen", symbolName: "cloud.rain.fill")
        case 71, 73, 75, 77, 85, 86:
            return WidgetConditionDescriptor(title: "Schnee", symbolName: "snowflake")
        case 95, 96, 99:
            return WidgetConditionDescriptor(title: "Gewitter", symbolName: "cloud.bolt.rain.fill")
        default:
            return WidgetConditionDescriptor(title: "Wetter", symbolName: "cloud.fill")
        }
    }
}

enum WidgetFormatters {
    static let time = WidgetTimeFormatter(dateFormat: "HH:mm")
    static let weekday = WidgetTimeFormatter(dateFormat: "EEE")
    static let dayAndMonth = WidgetTimeFormatter(dateFormat: "d. MMM")
}

struct WidgetTimeFormatter {
    private let dateFormat: String

    init(dateFormat: String) {
        self.dateFormat = dateFormat
    }

    func string(from date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = timeZone
        formatter.dateFormat = dateFormat
        return formatter.string(from: date)
    }
}

struct WidgetDataSelection {
    var placeName: String
    var subtitle: String
    var snapshot: WidgetWeatherSnapshot
}

struct WidgetSharedDataSource {
    private let fileManager: FileManager
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func loadSelection() -> WidgetDataSelection? {
        guard let rootURL = WidgetSharedStore.rootURL(fileManager: fileManager) else { return nil }

        let document = loadPlacesDocument(rootURL: rootURL)
        let cacheDirectory = rootURL.appendingPathComponent("ForecastCache", isDirectory: true)

        if document.prefersCurrentLocation,
           let snapshot = loadSnapshot(for: "current-location", cacheDirectory: cacheDirectory) {
            return WidgetDataSelection(
                placeName: snapshot.placeName,
                subtitle: "Zuletzt bekannter Ort",
                snapshot: snapshot
            )
        }

        if let preferredID = document.preferredSavedPlaceID,
           let preferredPlace = document.savedPlaces.first(where: { $0.id == preferredID }),
           let snapshot = loadSnapshot(for: preferredID.uuidString, cacheDirectory: cacheDirectory) {
            return WidgetDataSelection(
                placeName: preferredPlace.name,
                subtitle: preferredPlace.subtitle,
                snapshot: snapshot
            )
        }

        for place in document.savedPlaces {
            if let snapshot = loadSnapshot(for: place.id.uuidString, cacheDirectory: cacheDirectory) {
                return WidgetDataSelection(
                    placeName: place.name,
                    subtitle: place.subtitle,
                    snapshot: snapshot
                )
            }
        }

        if let snapshot = loadSnapshot(for: "current-location", cacheDirectory: cacheDirectory) {
            return WidgetDataSelection(
                placeName: snapshot.placeName,
                subtitle: "Zuletzt bekannter Ort",
                snapshot: snapshot
            )
        }

        return nil
    }

    func makeState(selection: WidgetDataSelection, now: Date) -> WidgetWeatherDisplayState {
        let snapshot = selection.snapshot
        let freshness = freshness(for: snapshot, now: now)
        let current = resolveCurrent(snapshot: snapshot, now: now)

        return WidgetWeatherDisplayState(
            placeName: selection.placeName,
            subtitle: selection.subtitle,
            timeZone: snapshot.timeZone,
            fetchedAt: snapshot.fetchedAt,
            freshness: freshness,
            current: current,
            hourly: resolveHourly(snapshot: snapshot, now: now),
            daily: resolveDaily(snapshot: snapshot, now: now),
            today: resolveToday(snapshot: snapshot, now: now),
            nextSunEvent: resolveNextSunEvent(snapshot: snapshot, now: now)
        )
    }

    private func loadPlacesDocument(rootURL: URL) -> WidgetPersistedPlacesDocument {
        let fileURL = rootURL.appendingPathComponent("places.json")
        guard let data = try? Data(contentsOf: fileURL),
              let document = try? decoder.decode(WidgetPersistedPlacesDocument.self, from: data) else {
            return .fallback
        }

        return document
    }

    private func loadSnapshot(for cacheKey: String, cacheDirectory: URL) -> WidgetWeatherSnapshot? {
        let safeKey = cacheKey.replacingOccurrences(of: "/", with: "-")
        let fileURL = cacheDirectory.appendingPathComponent("\(safeKey).json")

        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? decoder.decode(WidgetWeatherSnapshot.self, from: data) else {
            return nil
        }

        return snapshot
    }

    private func freshness(for snapshot: WidgetWeatherSnapshot, now: Date) -> WidgetForecastFreshness {
        let age = now.timeIntervalSince(snapshot.fetchedAt)

        switch age {
        case ..<1_200:
            return .fresh
        case ..<5_400:
            return .aging
        default:
            return .stale
        }
    }

    private func resolveCurrent(snapshot: WidgetWeatherSnapshot, now: Date) -> WidgetResolvedCurrentWeather {
        if let current = snapshot.current {
            let delta = abs(current.time.timeIntervalSince(now))
            if delta <= 5_400 {
                return WidgetResolvedCurrentWeather(
                    timestamp: current.time,
                    temperature: current.temperature,
                    apparentTemperature: current.apparentTemperature,
                    relativeHumidity: current.relativeHumidity,
                    windSpeed: current.windSpeed,
                    weatherCode: current.weatherCode,
                    isDay: current.isDay
                )
            }
        }

        let fallback = snapshot.hourly.last(where: { $0.timestamp <= now }) ?? snapshot.hourly.first

        if let fallback {
            return WidgetResolvedCurrentWeather(
                timestamp: fallback.timestamp,
                temperature: fallback.temperature,
                apparentTemperature: fallback.apparentTemperature,
                relativeHumidity: fallback.relativeHumidity,
                windSpeed: fallback.windSpeed,
                weatherCode: fallback.weatherCode,
                isDay: fallback.isDay
            )
        }

        return WidgetResolvedCurrentWeather(
            timestamp: snapshot.fetchedAt,
            temperature: snapshot.current?.temperature ?? 0,
            apparentTemperature: snapshot.current?.apparentTemperature ?? 0,
            relativeHumidity: snapshot.current?.relativeHumidity,
            windSpeed: snapshot.current?.windSpeed ?? 0,
            weatherCode: snapshot.current?.weatherCode ?? 3,
            isDay: snapshot.current?.isDay ?? true
        )
    }

    private func resolveHourly(snapshot: WidgetWeatherSnapshot, now: Date) -> [WidgetResolvedHour] {
        let sorted = snapshot.hourly.sorted { $0.timestamp < $1.timestamp }
        guard !sorted.isEmpty else { return [] }

        let activeIndex = sorted.lastIndex(where: { $0.timestamp <= now }) ?? 0
        let endIndex = min(activeIndex + 6, sorted.count)
        let window = Array(sorted[activeIndex..<endIndex])
        let activeTimestamp = sorted[activeIndex].timestamp
        let calendar = Calendar.widgetCalendar(timeZone: snapshot.timeZone)

        return window.map { item in
            WidgetResolvedHour(
                timestamp: item.timestamp,
                label: hourlyLabel(for: item.timestamp, activeTimestamp: activeTimestamp, timeZone: snapshot.timeZone),
                shortLabel: shortHourlyLabel(for: item.timestamp, activeTimestamp: activeTimestamp, timeZone: snapshot.timeZone),
                temperature: item.temperature,
                precipitationProbability: item.precipitationProbability,
                precipitation: item.precipitation,
                weatherCode: item.weatherCode,
                isDay: item.isDay,
                isCurrentHour: calendar.isDate(item.timestamp, equalTo: activeTimestamp, toGranularity: .hour)
            )
        }
    }

    private func resolveDaily(snapshot: WidgetWeatherSnapshot, now: Date) -> [WidgetResolvedDay] {
        let calendar = Calendar.widgetCalendar(timeZone: snapshot.timeZone)

        return snapshot.daily
            .sorted { $0.date < $1.date }
            .prefix(6)
            .map { day in
                WidgetResolvedDay(
                    date: day.date,
                    label: dayLabel(for: day.date, relativeTo: now, timeZone: snapshot.timeZone),
                    shortLabel: shortDayLabel(for: day.date, relativeTo: now, timeZone: snapshot.timeZone),
                    temperatureMin: day.temperatureMin,
                    temperatureMax: day.temperatureMax,
                    weatherCode: day.weatherCode,
                    precipitationProbabilityMax: day.precipitationProbabilityMax,
                    isToday: calendar.isDate(day.date, inSameDayAs: now)
                )
            }
    }

    private func resolveToday(snapshot: WidgetWeatherSnapshot, now: Date) -> WidgetDailyForecastEntry? {
        let calendar = Calendar.widgetCalendar(timeZone: snapshot.timeZone)
        return snapshot.daily.first { calendar.isDate($0.date, inSameDayAs: now) }
            ?? snapshot.daily.sorted { $0.date < $1.date }.first
    }

    private func resolveNextSunEvent(snapshot: WidgetWeatherSnapshot, now: Date) -> WidgetResolvedSunEvent? {
        let sortedDaily = snapshot.daily.sorted { $0.date < $1.date }

        for day in sortedDaily {
            if let sunrise = day.sunrise, sunrise > now {
                return WidgetResolvedSunEvent(kind: .sunrise, date: sunrise, label: "Aufgang")
            }

            if let sunset = day.sunset, sunset > now {
                return WidgetResolvedSunEvent(kind: .sunset, date: sunset, label: "Untergang")
            }
        }

        return nil
    }

    private func hourlyLabel(for date: Date, activeTimestamp: Date, timeZone: TimeZone) -> String {
        if Calendar.widgetCalendar(timeZone: timeZone).isDate(date, equalTo: activeTimestamp, toGranularity: .hour) {
            return "Jetzt"
        }

        return WidgetFormatters.time.string(from: date, timeZone: timeZone)
    }

    private func shortHourlyLabel(for date: Date, activeTimestamp: Date, timeZone: TimeZone) -> String {
        if Calendar.widgetCalendar(timeZone: timeZone).isDate(date, equalTo: activeTimestamp, toGranularity: .hour) {
            return "Jetzt"
        }

        return String(WidgetFormatters.time.string(from: date, timeZone: timeZone).prefix(2))
    }

    private func dayLabel(for date: Date, relativeTo now: Date, timeZone: TimeZone) -> String {
        let calendar = Calendar.widgetCalendar(timeZone: timeZone)
        if calendar.isDate(date, inSameDayAs: now) {
            return "Heute"
        }

        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Morgen"
        }

        return WidgetFormatters.weekday.string(from: date, timeZone: timeZone).capitalized
    }

    private func shortDayLabel(for date: Date, relativeTo now: Date, timeZone: TimeZone) -> String {
        let calendar = Calendar.widgetCalendar(timeZone: timeZone)
        if calendar.isDate(date, inSameDayAs: now) {
            return "Heu"
        }

        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Mor"
        }

        return String(WidgetFormatters.weekday.string(from: date, timeZone: timeZone).prefix(2)).capitalized
    }
}

extension Calendar {
    static func widgetCalendar(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "de_DE")
        calendar.timeZone = timeZone
        return calendar
    }
}
