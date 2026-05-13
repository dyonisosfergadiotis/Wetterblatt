import Foundation

struct WeatherService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchForecast(for place: ForecastPlace) async throws -> WeatherSnapshot {
        async let weatherResponse = fetchWeatherResponse(for: place)
        async let airQualitySnapshot = fetchAirQualitySnapshot(for: place)

        let response = try await weatherResponse
        return try response.snapshot(
            placeName: place.name,
            airQuality: await airQualitySnapshot
        )
    }

    private func coordinateString(_ value: Double) -> String {
        String(format: "%.4f", value)
    }

    private func fetchWeatherResponse(for place: ForecastPlace) async throws -> ForecastResponse {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.open-meteo.com"
        components.path = "/v1/forecast"
        components.queryItems = [
            URLQueryItem(name: "latitude", value: coordinateString(place.latitude)),
            URLQueryItem(name: "longitude", value: coordinateString(place.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,apparent_temperature,relative_humidity_2m,uv_index,weather_code,is_day,wind_speed_10m"),
            URLQueryItem(name: "hourly", value: "temperature_2m,apparent_temperature,relative_humidity_2m,precipitation_probability,precipitation,uv_index,weather_code,wind_speed_10m,is_day"),
            URLQueryItem(name: "minutely_15", value: "precipitation,rain,weather_code,is_day"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max,precipitation_probability_max"),
            URLQueryItem(name: "forecast_days", value: "10"),
            URLQueryItem(name: "forecast_minutely_15", value: "12"),
            URLQueryItem(name: "past_minutely_15", value: "1"),
            URLQueryItem(name: "past_days", value: "1"),
            URLQueryItem(name: "timezone", value: "auto"),
        ]

        guard let url = components.url else {
            throw WeatherServiceError.invalidURL
        }

        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(ForecastResponse.self, from: data)
    }

    private func fetchAirQualitySnapshot(for place: ForecastPlace) async -> AirQualitySnapshot? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "air-quality-api.open-meteo.com"
        components.path = "/v1/air-quality"
        components.queryItems = [
            URLQueryItem(name: "latitude", value: coordinateString(place.latitude)),
            URLQueryItem(name: "longitude", value: coordinateString(place.longitude)),
            URLQueryItem(
                name: "current",
                value: "european_aqi,pm2_5,pm10,alder_pollen,birch_pollen,grass_pollen,mugwort_pollen,olive_pollen,ragweed_pollen"
            ),
            URLQueryItem(
                name: "hourly",
                value: "european_aqi,pm2_5,pm10,alder_pollen,birch_pollen,grass_pollen,mugwort_pollen,olive_pollen,ragweed_pollen"
            ),
            URLQueryItem(name: "forecast_days", value: "4"),
            URLQueryItem(name: "timezone", value: "auto"),
        ]

        do {
            guard let url = components.url else {
                throw WeatherServiceError.invalidURL
            }

            let (data, _) = try await session.data(from: url)
            let response = try JSONDecoder().decode(AirQualityResponse.self, from: data)
            return try response.snapshot()
        } catch {
            return nil
        }
    }
}

private struct ForecastResponse: Decodable {
    var latitude: Double
    var longitude: Double
    var timezone: String
    var utcOffsetSeconds: Int
    var current: CurrentBlock?
    var hourly: HourlyBlock
    var minutely15: Minutely15Block?
    var daily: DailyBlock

    enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
        case timezone
        case current
        case hourly
        case minutely15 = "minutely_15"
        case daily
        case utcOffsetSeconds = "utc_offset_seconds"
    }

    func snapshot(placeName: String, airQuality: AirQualitySnapshot?) throws -> WeatherSnapshot {
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
        let minutelyEntries = try minutely15?.entries(dateFormatter: hourlyDateTime)
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
            daily: dailyEntries,
            airQuality: airQuality,
            minutely15: minutelyEntries
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
            guard let temperature = temperature2m[safe: index],
                  let apparentTemperature = apparentTemperature[safe: index],
                  let precipitationProbability = precipitationProbability[safe: index],
                  let precipitation = precipitation[safe: index],
                  let weatherCode = weatherCode[safe: index],
                  let windSpeed = windSpeed10m[safe: index],
                  let isDay = isDay[safe: index] else {
                throw WeatherServiceError.invalidResponse
            }

            result.append(
                HourlyForecastEntry(
                    timestamp: date,
                    temperature: temperature,
                    apparentTemperature: apparentTemperature,
                    precipitationProbability: precipitationProbability,
                    precipitation: precipitation,
                    uvIndex: uvIndex?[safe: index],
                    windSpeed: windSpeed,
                    weatherCode: weatherCode,
                    isDay: isDay == 1,
                    relativeHumidity: relativeHumidity2m?[safe: index]
                )
            )
        }

        return result
    }
}

private struct Minutely15Block: Decodable {
    var time: [String]
    var precipitation: [Double]
    var rain: [Double]?
    var weatherCode: [Int]
    var isDay: [Int]

    enum CodingKeys: String, CodingKey {
        case time
        case precipitation
        case rain
        case weatherCode = "weather_code"
        case isDay = "is_day"
    }

    func entries(dateFormatter: DateFormatter) throws -> [MinutelyForecastEntry] {
        let count = time.count
        var result: [MinutelyForecastEntry] = []
        result.reserveCapacity(count)

        for index in 0..<count {
            guard let date = dateFormatter.date(from: time[index]) else {
                throw WeatherServiceError.invalidDate
            }
            guard let precipitation = precipitation[safe: index],
                  let weatherCode = weatherCode[safe: index],
                  let isDay = isDay[safe: index] else {
                throw WeatherServiceError.invalidResponse
            }

            result.append(
                MinutelyForecastEntry(
                    timestamp: date,
                    precipitation: precipitation,
                    rain: rain?[safe: index],
                    weatherCode: weatherCode,
                    isDay: isDay == 1
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
            guard let temperatureMin = temperature2mMin[safe: index],
                  let temperatureMax = temperature2mMax[safe: index],
                  let weatherCode = weatherCode[safe: index],
                  let precipitationProbabilityMax = precipitationProbabilityMax[safe: index] else {
                throw WeatherServiceError.invalidResponse
            }

            result.append(
                DailyForecastEntry(
                    date: date,
                    temperatureMin: temperatureMin,
                    temperatureMax: temperatureMax,
                    sunrise: sunrise?[safe: index].flatMap { dateFormatter.date(from: $0) },
                    sunset: sunset?[safe: index].flatMap { dateFormatter.date(from: $0) },
                    uvIndexMax: uvIndexMax?[safe: index],
                    weatherCode: weatherCode,
                    precipitationProbabilityMax: precipitationProbabilityMax
                )
            )
        }

        return result
    }
}

private struct AirQualityResponse: Decodable {
    var timezone: String
    var utcOffsetSeconds: Int
    var current: AirQualityCurrentBlock?
    var hourly: AirQualityHourlyBlock

    enum CodingKeys: String, CodingKey {
        case timezone
        case current
        case hourly
        case utcOffsetSeconds = "utc_offset_seconds"
    }

    func snapshot() throws -> AirQualitySnapshot {
        let timeZone = TimeZone(identifier: timezone)
            ?? TimeZone(secondsFromGMT: utcOffsetSeconds)
            ?? .current

        let hourlyDateTime = DateFormatter()
        hourlyDateTime.locale = Locale(identifier: "en_US_POSIX")
        hourlyDateTime.timeZone = timeZone
        hourlyDateTime.dateFormat = "yyyy-MM-dd'T'HH:mm"

        return AirQualitySnapshot(
            current: try current?.snapshot(dateFormatter: hourlyDateTime),
            hourly: try hourly.entries(dateFormatter: hourlyDateTime)
        )
    }
}

private struct AirQualityCurrentBlock: Decodable {
    var time: String
    var europeanAQI: Double?
    var pm2_5: Double?
    var pm10: Double?
    var alderPollen: Double?
    var birchPollen: Double?
    var grassPollen: Double?
    var mugwortPollen: Double?
    var olivePollen: Double?
    var ragweedPollen: Double?

    enum CodingKeys: String, CodingKey {
        case time
        case europeanAQI = "european_aqi"
        case pm2_5
        case pm10
        case alderPollen = "alder_pollen"
        case birchPollen = "birch_pollen"
        case grassPollen = "grass_pollen"
        case mugwortPollen = "mugwort_pollen"
        case olivePollen = "olive_pollen"
        case ragweedPollen = "ragweed_pollen"
    }

    func snapshot(dateFormatter: DateFormatter) throws -> AirQualityCurrentSnapshot {
        guard let date = dateFormatter.date(from: time) else {
            throw WeatherServiceError.invalidDate
        }

        return AirQualityCurrentSnapshot(
            time: date,
            europeanAQI: europeanAQI,
            pm2_5: pm2_5,
            pm10: pm10,
            alderPollen: alderPollen,
            birchPollen: birchPollen,
            grassPollen: grassPollen,
            mugwortPollen: mugwortPollen,
            olivePollen: olivePollen,
            ragweedPollen: ragweedPollen
        )
    }
}

private struct AirQualityHourlyBlock: Decodable {
    var time: [String]
    var europeanAQI: [Double?]?
    var pm2_5: [Double?]?
    var pm10: [Double?]?
    var alderPollen: [Double?]?
    var birchPollen: [Double?]?
    var grassPollen: [Double?]?
    var mugwortPollen: [Double?]?
    var olivePollen: [Double?]?
    var ragweedPollen: [Double?]?

    enum CodingKeys: String, CodingKey {
        case time
        case europeanAQI = "european_aqi"
        case pm2_5
        case pm10
        case alderPollen = "alder_pollen"
        case birchPollen = "birch_pollen"
        case grassPollen = "grass_pollen"
        case mugwortPollen = "mugwort_pollen"
        case olivePollen = "olive_pollen"
        case ragweedPollen = "ragweed_pollen"
    }

    func entries(dateFormatter: DateFormatter) throws -> [AirQualityHourlyEntry] {
        let count = time.count
        var result: [AirQualityHourlyEntry] = []
        result.reserveCapacity(count)

        for index in 0..<count {
            guard let date = dateFormatter.date(from: time[index]) else {
                throw WeatherServiceError.invalidDate
            }

            result.append(
                AirQualityHourlyEntry(
                    timestamp: date,
                    europeanAQI: europeanAQI?[safe: index] ?? nil,
                    pm2_5: pm2_5?[safe: index] ?? nil,
                    pm10: pm10?[safe: index] ?? nil,
                    alderPollen: alderPollen?[safe: index] ?? nil,
                    birchPollen: birchPollen?[safe: index] ?? nil,
                    grassPollen: grassPollen?[safe: index] ?? nil,
                    mugwortPollen: mugwortPollen?[safe: index] ?? nil,
                    olivePollen: olivePollen?[safe: index] ?? nil,
                    ragweedPollen: ragweedPollen?[safe: index] ?? nil
                )
            )
        }

        return result
    }
}

private enum WeatherServiceError: Error {
    case invalidURL
    case invalidDate
    case invalidResponse
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
