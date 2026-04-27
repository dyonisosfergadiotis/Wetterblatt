import Foundation

struct WeatherService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchForecast(for place: ForecastPlace) async throws -> WeatherSnapshot {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: coordinateString(place.latitude)),
            URLQueryItem(name: "longitude", value: coordinateString(place.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,apparent_temperature,relative_humidity_2m,uv_index,weather_code,is_day,wind_speed_10m"),
            URLQueryItem(name: "hourly", value: "temperature_2m,apparent_temperature,relative_humidity_2m,precipitation_probability,precipitation,uv_index,weather_code,wind_speed_10m,is_day"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max,precipitation_probability_max"),
            URLQueryItem(name: "forecast_days", value: "10"),
            URLQueryItem(name: "past_days", value: "1"),
            URLQueryItem(name: "timezone", value: "auto"),
        ]

        let (data, _) = try await session.data(from: components.url!)
        let response = try JSONDecoder().decode(ForecastResponse.self, from: data)
        return try response.snapshot(placeName: place.name)
    }

    private func coordinateString(_ value: Double) -> String {
        String(format: "%.4f", value)
    }
}

private struct ForecastResponse: Decodable {
    var latitude: Double
    var longitude: Double
    var timezone: String
    var utcOffsetSeconds: Int
    var current: CurrentBlock?
    var hourly: HourlyBlock
    var daily: DailyBlock

    enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
        case timezone
        case current
        case hourly
        case daily
        case utcOffsetSeconds = "utc_offset_seconds"
    }

    func snapshot(placeName: String) throws -> WeatherSnapshot {
        let timeZone = TimeZone(identifier: timezone)
            ?? TimeZone(secondsFromGMT: utcOffsetSeconds)
            ?? .current

        let hourlyDateTime = DateFormatter()
        hourlyDateTime.locale = Locale(identifier: "en_US_POSIX")
        hourlyDateTime.timeZone = timeZone
        hourlyDateTime.dateFormat = "yyyy-MM-dd'T'HH:mm"

        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.timeZone = timeZone
        dayFormatter.dateFormat = "yyyy-MM-dd"

        let currentSnapshot = try current?.snapshot(dateFormatter: hourlyDateTime)
        let hourlyEntries = try hourly.entries(dateFormatter: hourlyDateTime)
        let dailyEntries = try daily.entries(dayFormatter: dayFormatter, dateFormatter: hourlyDateTime)

        return WeatherSnapshot(
            placeName: placeName,
            latitude: latitude,
            longitude: longitude,
            timezoneIdentifier: timezone,
            utcOffsetSeconds: utcOffsetSeconds,
            fetchedAt: Date(),
            current: currentSnapshot,
            hourly: hourlyEntries,
            daily: dailyEntries
        )
    }
}

private struct CurrentBlock: Decodable {
    var time: String
    var temperature2m: Double
    var apparentTemperature: Double
    var relativeHumidity2m: Double?
    var uvIndex: Double?
    var weatherCode: Int
    var isDay: Int
    var windSpeed10m: Double

    enum CodingKeys: String, CodingKey {
        case time
        case temperature2m = "temperature_2m"
        case apparentTemperature = "apparent_temperature"
        case relativeHumidity2m = "relative_humidity_2m"
        case uvIndex = "uv_index"
        case weatherCode = "weather_code"
        case isDay = "is_day"
        case windSpeed10m = "wind_speed_10m"
    }

    func snapshot(dateFormatter: DateFormatter) throws -> CurrentWeatherSnapshot {
        guard let date = dateFormatter.date(from: time) else {
            throw WeatherServiceError.invalidDate
        }

        return CurrentWeatherSnapshot(
            time: date,
            temperature: temperature2m,
            apparentTemperature: apparentTemperature,
            relativeHumidity: relativeHumidity2m,
            uvIndex: uvIndex,
            windSpeed: windSpeed10m,
            weatherCode: weatherCode,
            isDay: isDay == 1
        )
    }
}

private struct HourlyBlock: Decodable {
    var time: [String]
    var temperature2m: [Double]
    var apparentTemperature: [Double]
    var relativeHumidity2m: [Double]?
    var precipitationProbability: [Double]
    var precipitation: [Double]
    var uvIndex: [Double]?
    var weatherCode: [Int]
    var windSpeed10m: [Double]
    var isDay: [Int]

    enum CodingKeys: String, CodingKey {
        case time
        case temperature2m = "temperature_2m"
        case apparentTemperature = "apparent_temperature"
        case relativeHumidity2m = "relative_humidity_2m"
        case precipitationProbability = "precipitation_probability"
        case precipitation
        case uvIndex = "uv_index"
        case weatherCode = "weather_code"
        case windSpeed10m = "wind_speed_10m"
        case isDay = "is_day"
    }

    func entries(dateFormatter: DateFormatter) throws -> [HourlyForecastEntry] {
        let count = time.count
        var result: [HourlyForecastEntry] = []
        result.reserveCapacity(count)

        for index in 0..<count {
            guard let date = dateFormatter.date(from: time[index]) else {
                throw WeatherServiceError.invalidDate
            }

            result.append(
                HourlyForecastEntry(
                    timestamp: date,
                    temperature: temperature2m[index],
                    apparentTemperature: apparentTemperature[index],
                    precipitationProbability: precipitationProbability[index],
                    precipitation: precipitation[index],
                    uvIndex: uvIndex?[safe: index],
                    windSpeed: windSpeed10m[index],
                    weatherCode: weatherCode[index],
                    isDay: isDay[index] == 1,
                    relativeHumidity: relativeHumidity2m?[safe: index]
                )
            )
        }

        return result
    }
}

private struct DailyBlock: Decodable {
    var time: [String]
    var weatherCode: [Int]
    var temperature2mMax: [Double]
    var temperature2mMin: [Double]
    var sunrise: [String]?
    var sunset: [String]?
    var uvIndexMax: [Double]?
    var precipitationProbabilityMax: [Double]

    enum CodingKeys: String, CodingKey {
        case time
        case weatherCode = "weather_code"
        case temperature2mMax = "temperature_2m_max"
        case temperature2mMin = "temperature_2m_min"
        case sunrise
        case sunset
        case uvIndexMax = "uv_index_max"
        case precipitationProbabilityMax = "precipitation_probability_max"
    }

    func entries(dayFormatter: DateFormatter, dateFormatter: DateFormatter) throws -> [DailyForecastEntry] {
        let count = time.count
        var result: [DailyForecastEntry] = []
        result.reserveCapacity(count)

        for index in 0..<count {
            guard let date = dayFormatter.date(from: time[index]) else {
                throw WeatherServiceError.invalidDate
            }

            result.append(
                DailyForecastEntry(
                    date: date,
                    temperatureMin: temperature2mMin[index],
                    temperatureMax: temperature2mMax[index],
                    sunrise: sunrise?[safe: index].flatMap { dateFormatter.date(from: $0) },
                    sunset: sunset?[safe: index].flatMap { dateFormatter.date(from: $0) },
                    uvIndexMax: uvIndexMax?[safe: index],
                    weatherCode: weatherCode[index],
                    precipitationProbabilityMax: precipitationProbabilityMax[index]
                )
            )
        }

        return result
    }
}

private enum WeatherServiceError: Error {
    case invalidDate
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
