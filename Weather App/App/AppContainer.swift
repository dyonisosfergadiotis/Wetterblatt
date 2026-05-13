import Foundation

@MainActor
final class AppContainer {
    let repository: WeatherRepository
    let placesStore: PlacesStore
    let settingsStore: SettingsStore
    let locationService: LocationService
    let geocodingService: GeocodingService
    let reachability: ReachabilityMonitor
    let clock: WeatherClock

    init() {
        let cacheStore = ForecastCacheStore()
        let weatherService = WeatherService()

        self.repository = WeatherRepository(weatherService: weatherService, cacheStore: cacheStore)
        self.placesStore = PlacesStore()
        self.settingsStore = SettingsStore()
        self.locationService = LocationService()
        self.geocodingService = GeocodingService()
        self.reachability = ReachabilityMonitor()
        self.clock = WeatherClock()
    }

    func makeAppModel() -> AppModel {
        AppModel(
            repository: repository,
            placesStore: placesStore,
            settingsStore: settingsStore,
            locationService: locationService,
            geocodingService: geocodingService,
            reachability: reachability,
            clock: clock
        )
    }
}
