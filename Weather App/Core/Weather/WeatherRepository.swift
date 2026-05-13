import Foundation

struct WeatherRepository {
    private let weatherService: WeatherService
    private let cacheStore: ForecastCacheStore
    private let merger = SnapshotMerger()
    private let currentResolver = CurrentWeatherResolver()
    private let airQualityResolver = AirQualityResolver()
    private let timelineResolver = ForecastTimelineResolver()
    private let freshnessPolicy = ForecastFreshnessPolicy()

    init(weatherService: WeatherService, cacheStore: ForecastCacheStore) {
        self.weatherService = weatherService
        self.cacheStore = cacheStore
    }

    func cachedSnapshot(for cacheKey: String) async -> WeatherSnapshot? {
        await cacheStore.loadSnapshot(for: cacheKey)
    }

    func refreshForecast(for place: ForecastPlace, existing: WeatherSnapshot?) async throws -> WeatherSnapshot {
        let fresh = try await weatherService.fetchForecast(for: place)
        let merged = merger.merge(existing: existing, incoming: fresh)
        await cacheStore.saveSnapshot(merged, for: place.cacheKey)
        return merged
    }

    func resolveState(snapshot: WeatherSnapshot, place: ForecastPlace, now: Date, isConnected: Bool) -> WeatherScreenState {
        let freshness = freshnessPolicy.freshness(for: snapshot, now: now)
        let current = currentResolver.resolve(snapshot: snapshot, now: now)

        return WeatherScreenState(
            place: place,
            snapshot: snapshot,
            freshness: freshness,
            current: current,
            airQualityCurrent: airQualityResolver.resolveCurrent(snapshot: snapshot, now: now),
            airQualityHourly: airQualityResolver.resolveHourly(snapshot: snapshot, now: now),
            hourly: timelineResolver.resolveHourly(snapshot: snapshot, now: now),
            daily: timelineResolver.resolveDaily(snapshot: snapshot, now: now),
            nextSunEvent: timelineResolver.nextSunEvent(snapshot: snapshot, now: now),
            isConnected: isConnected
        )
    }

    func summary(snapshot: WeatherSnapshot, place: ForecastPlace, now: Date, isConnected: Bool) -> PlaceWeatherSummary {
        let freshness = freshnessPolicy.freshness(for: snapshot, now: now)
        let current = currentResolver.resolve(snapshot: snapshot, now: now)

        return PlaceWeatherSummary(
            place: place,
            temperature: current.temperature,
            weatherCode: current.weatherCode,
            isDay: current.isDay,
            freshness: freshness,
            fetchedAt: snapshot.fetchedAt,
            isConnected: isConnected
        )
    }
}
