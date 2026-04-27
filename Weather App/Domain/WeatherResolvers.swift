import Foundation

struct ForecastFreshnessPolicy {
    func freshness(for snapshot: WeatherSnapshot, now: Date) -> ForecastFreshness {
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
}

struct SnapshotMerger {
    func merge(existing: WeatherSnapshot?, incoming: WeatherSnapshot) -> WeatherSnapshot {
        guard let existing else { return incoming }

        let mergedHourly = mergeHourly(existing.hourly, incoming.hourly)
        let mergedDaily = mergeDaily(existing.daily, incoming.daily)

        return WeatherSnapshot(
            placeName: incoming.placeName,
            latitude: incoming.latitude,
            longitude: incoming.longitude,
            timezoneIdentifier: incoming.timezoneIdentifier,
            utcOffsetSeconds: incoming.utcOffsetSeconds,
            fetchedAt: incoming.fetchedAt,
            current: incoming.current ?? existing.current,
            hourly: mergedHourly,
            daily: mergedDaily
        )
    }

    private func mergeHourly(_ existing: [HourlyForecastEntry], _ incoming: [HourlyForecastEntry]) -> [HourlyForecastEntry] {
        var merged = Dictionary(uniqueKeysWithValues: existing.map { ($0.timestamp, $0) })
        for item in incoming {
            merged[item.timestamp] = item
        }

        return merged.values.sorted { $0.timestamp < $1.timestamp }
    }

    private func mergeDaily(_ existing: [DailyForecastEntry], _ incoming: [DailyForecastEntry]) -> [DailyForecastEntry] {
        var merged = Dictionary(uniqueKeysWithValues: existing.map { ($0.date, $0) })
        for item in incoming {
            merged[item.date] = item
        }

        return merged.values.sorted { $0.date < $1.date }
    }
}

struct CurrentWeatherResolver {
    private let freshnessPolicy = ForecastFreshnessPolicy()

    func resolve(snapshot: WeatherSnapshot, now: Date) -> ResolvedCurrentWeather {
        if let current = snapshot.current {
            let delta = abs(current.time.timeIntervalSince(now))
            if delta <= 5_400 {
                return ResolvedCurrentWeather(
                    timestamp: current.time,
                    temperature: current.temperature,
                    apparentTemperature: current.apparentTemperature,
                    relativeHumidity: current.relativeHumidity,
                    uvIndex: current.uvIndex,
                    windSpeed: current.windSpeed,
                    weatherCode: current.weatherCode,
                    isDay: current.isDay,
                    source: .liveCurrent
                )
            }
        }

        let fallback = snapshot.hourly.last(where: { $0.timestamp <= now }) ?? snapshot.hourly.first
        let freshness = freshnessPolicy.freshness(for: snapshot, now: now)

        guard let fallback else {
            return ResolvedCurrentWeather(
                timestamp: snapshot.fetchedAt,
                temperature: snapshot.current?.temperature ?? 0,
                apparentTemperature: snapshot.current?.apparentTemperature ?? 0,
                relativeHumidity: snapshot.current?.relativeHumidity,
                uvIndex: snapshot.current?.uvIndex,
                windSpeed: snapshot.current?.windSpeed ?? 0,
                weatherCode: snapshot.current?.weatherCode ?? 3,
                isDay: snapshot.current?.isDay ?? true,
                source: freshness == .stale ? .staleForecast : .hourlyFallback
            )
        }

        return ResolvedCurrentWeather(
            timestamp: fallback.timestamp,
            temperature: fallback.temperature,
            apparentTemperature: fallback.apparentTemperature,
            relativeHumidity: fallback.relativeHumidity,
            uvIndex: fallback.uvIndex,
            windSpeed: fallback.windSpeed,
            weatherCode: fallback.weatherCode,
            isDay: fallback.isDay,
            source: freshness == .stale ? .staleForecast : .hourlyFallback
        )
    }
}

struct ForecastTimelineResolver {
    func resolveHourly(snapshot: WeatherSnapshot, now: Date, maxCount: Int = 18) -> [ResolvedHourlyForecast] {
        let sorted = snapshot.hourly.sorted { $0.timestamp < $1.timestamp }
        guard !sorted.isEmpty else { return [] }

        let activeIndex = sorted.lastIndex(where: { $0.timestamp <= now }) ?? 0
        let startIndex = activeIndex
        let endIndex = min(startIndex + maxCount, sorted.count)
        let window = Array(sorted[startIndex..<endIndex])
        let activeTimestamp = sorted[activeIndex].timestamp
        let calendar = Calendar.weatherCalendar(timeZone: snapshot.timeZone)

        return window.map { item in
            ResolvedHourlyForecast(
                timestamp: item.timestamp,
                temperature: item.temperature,
                apparentTemperature: item.apparentTemperature,
                precipitationProbability: item.precipitationProbability,
                precipitation: item.precipitation,
                uvIndex: item.uvIndex,
                windSpeed: item.windSpeed,
                weatherCode: item.weatherCode,
                isDay: item.isDay,
                relativeHumidity: item.relativeHumidity,
                isPast: item.timestamp < activeTimestamp,
                isCurrentHour: calendar.isDate(item.timestamp, equalTo: activeTimestamp, toGranularity: .hour),
                displayLabel: hourlyLabel(for: item.timestamp, activeTimestamp: activeTimestamp, timeZone: snapshot.timeZone)
            )
        }
    }

    func resolveDaily(snapshot: WeatherSnapshot, now: Date) -> [ResolvedDailyForecast] {
        let calendar = Calendar.weatherCalendar(timeZone: snapshot.timeZone)
        let startOfToday = calendar.startOfDay(for: now)

        return snapshot.daily
            .sorted { $0.date < $1.date }
            .filter { $0.date >= startOfToday }
            .map { item in
                ResolvedDailyForecast(
                    date: item.date,
                    temperatureMin: item.temperatureMin,
                    temperatureMax: item.temperatureMax,
                    sunrise: item.sunrise,
                    sunset: item.sunset,
                    uvIndexMax: item.uvIndexMax,
                    weatherCode: item.weatherCode,
                    precipitationProbabilityMax: item.precipitationProbabilityMax,
                    displayLabel: dailyLabel(for: item.date, now: now, timeZone: snapshot.timeZone),
                    isToday: calendar.isDate(item.date, inSameDayAs: now)
                )
            }
    }

    func nextSunEvent(snapshot: WeatherSnapshot, now: Date) -> ResolvedSunEvent? {
        let calendar = Calendar.weatherCalendar(timeZone: snapshot.timeZone)
        let sortedDaily = snapshot.daily.sorted { $0.date < $1.date }

        for day in sortedDaily {
            if let sunrise = day.sunrise, sunrise > now {
                return ResolvedSunEvent(kind: .sunrise, date: sunrise, relativeDescription: relativeDescription(for: sunrise, now: now, timeZone: snapshot.timeZone))
            }

            if let sunset = day.sunset, sunset > now {
                return ResolvedSunEvent(kind: .sunset, date: sunset, relativeDescription: relativeDescription(for: sunset, now: now, timeZone: snapshot.timeZone))
            }

            if calendar.isDate(day.date, inSameDayAs: now) {
                continue
            }
        }

        return nil
    }

    private func hourlyLabel(for date: Date, activeTimestamp: Date, timeZone: TimeZone) -> String {
        WeatherDateFormatting.hourLabel(for: date, relativeTo: activeTimestamp, timeZone: timeZone)
    }

    private func dailyLabel(for date: Date, now: Date, timeZone: TimeZone) -> String {
        let calendar = Calendar.weatherCalendar(timeZone: timeZone)
        if calendar.isDate(date, inSameDayAs: now) {
            return "Heute"
        }

        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Morgen"
        }

        return WeatherDateFormatting.shortWeekday(date, timeZone: timeZone)
    }

    private func relativeDescription(for date: Date, now: Date, timeZone: TimeZone) -> String {
        let minutes = max(Int(date.timeIntervalSince(now) / 60), 0)

        if minutes < 60 {
            return "in \(minutes) Min."
        }

        let hours = minutes / 60
        let restMinutes = minutes % 60

        if restMinutes == 0 {
            return "in \(hours) Std."
        }

        return "um \(WeatherDateFormatting.time(date, timeZone: timeZone))"
    }
}

extension Calendar {
    static func weatherCalendar(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = WeatherDateFormatting.germanLocale
        calendar.timeZone = timeZone
        return calendar
    }
}
