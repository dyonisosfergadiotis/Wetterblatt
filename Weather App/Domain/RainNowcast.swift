import Foundation

struct RainNowcastSample: Identifiable, Hashable {
    var id: Date { timestamp }

    let timestamp: Date
    let precipitation: Double
    let rain: Double?
    let weatherCode: Int
    let isCurrent: Bool

    var wetAmount: Double {
        max(precipitation, rain ?? 0)
    }

    var isWet: Bool {
        wetAmount >= RainNowcastConfiguration.wetSampleThreshold
            || WeatherConditions.isWetWeatherCode(weatherCode)
    }
}

enum RainNowcastConfiguration {
    static let forecastWindow: TimeInterval = 3 * 3_600
    static let sourceInterval: TimeInterval = 15 * 60
    static let displayInterval: TimeInterval = 5 * 60
    static let pastTolerance: TimeInterval = 60
    static let wetSampleThreshold = 0.01

    static var sourceSliceCount: Int {
        max(1, Int((sourceInterval / displayInterval).rounded()))
    }
}

struct RainNowcastSummary {
    let samples: [RainNowcastSample]
    let now: Date
    let timeZone: TimeZone

    var firstWetSample: RainNowcastSample? {
        samples.first(where: \.isWet)
    }

    var totalPrecipitation: Double {
        samples.reduce(0) { $0 + max(0, $1.precipitation) }
    }

    var peakPrecipitation: Double {
        samples.map(\.wetAmount).max() ?? 0
    }

    var coveredDuration: TimeInterval {
        guard let lastTimestamp = samples.last?.timestamp else {
            return RainNowcastConfiguration.forecastWindow
        }

        return min(
            RainNowcastConfiguration.forecastWindow,
            max(
                RainNowcastConfiguration.displayInterval,
                lastTimestamp
                    .addingTimeInterval(RainNowcastConfiguration.displayInterval)
                    .timeIntervalSince(now)
            )
        )
    }

    var windowLabel: String {
        RainNowcastFormatter.durationLabel(for: coveredDuration)
    }

    var compactWindowLabel: String {
        RainNowcastFormatter.durationLabel(for: coveredDuration, compact: true)
    }

    var isRelevant: Bool {
        firstWetSample != nil || totalPrecipitation >= 0.08
    }
}

enum RainNowcastResolver {
    static func summary(for state: WeatherScreenState, now: Date) -> RainNowcastSummary? {
        guard let minutely = state.snapshot.minutely15, !minutely.isEmpty else {
            return nil
        }

        let cutoff = now.addingTimeInterval(RainNowcastConfiguration.forecastWindow)
        let samples = minutely
            .filter {
                $0.timestamp >= now.addingTimeInterval(-RainNowcastConfiguration.sourceInterval)
                    && $0.timestamp <= cutoff
            }
            .flatMap {
                makeSamples(from: $0, now: now, cutoff: cutoff)
            }
            .filter {
                $0.timestamp >= now.addingTimeInterval(-RainNowcastConfiguration.pastTolerance)
                    && $0.timestamp <= cutoff
            }
            .sorted { $0.timestamp < $1.timestamp }

        guard !samples.isEmpty else { return nil }
        return RainNowcastSummary(samples: samples, now: now, timeZone: state.snapshot.timeZone)
    }

    private static func makeSamples(
        from entry: MinutelyForecastEntry,
        now: Date,
        cutoff: Date
    ) -> [RainNowcastSample] {
        let sliceCount = RainNowcastConfiguration.sourceSliceCount
        let precipitationPerSlice = entry.precipitation / Double(sliceCount)
        let rainPerSlice = entry.rain.map { $0 / Double(sliceCount) }

        return (0..<sliceCount).compactMap { offset -> RainNowcastSample? in
            let timestamp = entry.timestamp.addingTimeInterval(
                Double(offset) * RainNowcastConfiguration.displayInterval
            )
            guard timestamp <= cutoff else { return nil }

            return RainNowcastSample(
                timestamp: timestamp,
                precipitation: precipitationPerSlice,
                rain: rainPerSlice,
                weatherCode: entry.weatherCode,
                isCurrent: abs(timestamp.timeIntervalSince(now)) <= RainNowcastConfiguration.displayInterval / 2
            )
        }
    }
}

enum RainNowcastFormatter {
    static func durationLabel(for duration: TimeInterval, compact: Bool = false) -> String {
        let totalMinutes = max(5, Int((duration / 60).rounded()))
        let roundedMinutes = max(5, Int((Double(totalMinutes) / 5.0).rounded()) * 5)
        let hours = roundedMinutes / 60
        let minutes = roundedMinutes % 60

        if hours == 0 {
            return compact ? "\(roundedMinutes) Min" : "\(roundedMinutes) Minuten"
        }

        if minutes == 0 {
            return compact ? "\(hours) Std." : "\(hours) Stunden"
        }

        return compact ? "\(hours) h \(minutes) min" : "\(hours) Stunden \(minutes) Minuten"
    }
}
