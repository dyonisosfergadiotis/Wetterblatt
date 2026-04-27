import CoreLocation
import Foundation
import Observation
import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
@Observable
final class AppModel {
    static let foregroundAutoRefreshInterval: TimeInterval = 1_200
    static let foregroundAutoRefreshMinutes = 20
    private static let autoRefreshRetryInterval: TimeInterval = 300
    private static let currentLocationResetDistance: CLLocationDistance = 25_000

    private let repository: WeatherRepository
    private let placesStore: PlacesStore
    private let locationService: LocationService
    private let geocodingService: GeocodingService

    let reachability: ReachabilityMonitor
    let clock: WeatherClock

    var savedPlaces: [SavedPlace] = []
    var currentLocationPlace: ForecastPlace?
    var activePlaceSelection: ActivePlaceSelection = .currentLocation
    var weatherState: WeatherScreenState?
    var placeSummaries: [String: PlaceWeatherSummary] = [:]
    var isRefreshing = false
    var isBootstrapping = true
    var searchText = ""
    var searchResults: [PlaceSearchResult] = []
    var isSearching = false
    var locationAuthorization: CLAuthorizationStatus = .notDetermined
    var hasLiveCurrentLocationFix = false

    private var didStart = false
    private var isSceneActive = false
    private var snapshotsByKey: [String: WeatherSnapshot] = [:]
    private var lastAutoRefreshAttemptByKey: [String: Date] = [:]

    init(
        repository: WeatherRepository,
        placesStore: PlacesStore,
        locationService: LocationService,
        geocodingService: GeocodingService,
        reachability: ReachabilityMonitor,
        clock: WeatherClock
    ) {
        self.repository = repository
        self.placesStore = placesStore
        self.locationService = locationService
        self.geocodingService = geocodingService
        self.reachability = reachability
        self.clock = clock
        self.locationAuthorization = locationService.authorizationStatus
    }

    var selectedPlace: ForecastPlace? {
        switch activePlaceSelection {
        case .currentLocation:
            return currentLocationPlace
        case .saved(let id):
            return savedPlaces.first(where: { $0.id == id })?.forecastPlace
        }
    }

    var isWaitingForCurrentLocation: Bool {
        activePlaceSelection == .currentLocation
        && currentLocationPlace == nil
        && !hasLiveCurrentLocationFix
        && locationAuthorization != .denied
        && locationAuthorization != .restricted
    }

    var currentSummary: PlaceWeatherSummary? {
        guard let selectedPlace else { return nil }
        return placeSummaries[selectedPlace.cacheKey]
    }

    var savedPlaceCards: [PlaceWeatherSummary] {
        savedPlaces.compactMap { placeSummaries[$0.forecastPlace.cacheKey] }
    }

    func start() async {
        guard !didStart else { return }
        didStart = true
        isSceneActive = true

        bindServices()
        clock.start()

        let persisted = placesStore.load()
        savedPlaces = persisted.savedPlaces
        activePlaceSelection = persisted.prefersCurrentLocation
            ? .currentLocation
            : .saved(persisted.preferredSavedPlaceID ?? savedPlaces.first?.id ?? SavedPlace.berlin.id)

        await hydrateCachedSnapshots()
        await loadSelectedPlaceIfNeeded(forceRefresh: false, showsFeedback: false)

        locationService.requestAccessAndLocation()
        isBootstrapping = false
    }

    func handleScenePhase(_ phase: ScenePhase) async {
        isSceneActive = phase == .active
        guard phase == .active else { return }
        locationService.requestLocation()
        await loadSelectedPlaceIfNeeded(forceRefresh: false, showsFeedback: false)
    }

    func refreshSelectedPlace(force: Bool = true) async {
        await loadSelectedPlaceIfNeeded(forceRefresh: force, showsFeedback: true)
    }

    func selectSavedPlace(_ place: SavedPlace) async {
        activePlaceSelection = .saved(place.id)
        await persistPlaces(prefersCurrentLocation: false, preferredSavedPlaceID: place.id)
        await loadSelectedPlaceIfNeeded(forceRefresh: false, showsFeedback: false)
    }

    func useCurrentLocation() async {
        activePlaceSelection = .currentLocation
        if currentLocationPlace == nil && !hasLiveCurrentLocationFix {
            weatherState = nil
        }
        await persistPlaces(prefersCurrentLocation: true, preferredSavedPlaceID: nil)
        locationService.requestAccessAndLocation()
        await loadSelectedPlaceIfNeeded(forceRefresh: false, showsFeedback: false)
    }

    func removePlace(_ place: SavedPlace) async {
        savedPlaces.removeAll { $0.id == place.id }
        placeSummaries.removeValue(forKey: place.forecastPlace.cacheKey)
        snapshotsByKey.removeValue(forKey: place.forecastPlace.cacheKey)

        if case .saved(let selectedID) = activePlaceSelection, selectedID == place.id {
            activePlaceSelection = .currentLocation
        }

        await persistPlaces(prefersCurrentLocation: activePlaceSelection == .currentLocation, preferredSavedPlaceID: savedPlaces.first?.id)
        await loadSelectedPlaceIfNeeded(forceRefresh: false, showsFeedback: false)
    }

    func searchPlacesIfNeeded() async {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            searchResults = []
            return
        }

        isSearching = true
        defer { isSearching = false }

        do {
            searchResults = try await geocodingService.search(query: trimmed)
        } catch {
            searchResults = []
        }
    }

    func addPlace(from result: PlaceSearchResult) async {
        let duplicate = savedPlaces.contains {
            abs($0.latitude - result.latitude) < 0.01
            && abs($0.longitude - result.longitude) < 0.01
            && $0.name == result.name
        }

        guard !duplicate else { return }

        let place = result.savedPlace
        savedPlaces.append(place)
        searchText = ""
        searchResults = []

        await persistPlaces(prefersCurrentLocation: false, preferredSavedPlaceID: place.id)
        await selectSavedPlace(place)
    }

    func nextAutoRefreshDate(for snapshot: WeatherSnapshot) -> Date {
        snapshot.fetchedAt.addingTimeInterval(Self.foregroundAutoRefreshInterval)
    }

    private func bindServices() {
        locationService.onAuthorizationChange = { [weak self] status in
            Task { @MainActor in
                self?.locationAuthorization = status
            }
        }

        locationService.onLocationUpdate = { [weak self] location in
            Task { @MainActor in
                await self?.handleLocationUpdate(location)
            }
        }

        reachability.onChange = { [weak self] connected in
            Task { @MainActor in
                self?.recomputeAllStates()
                if connected {
                    await self?.loadSelectedPlaceIfNeeded(forceRefresh: false, showsFeedback: false)
                }
            }
        }

        clock.onTick = { [weak self] now in
            Task { @MainActor in
                self?.recomputeAllStates()
                await self?.autoRefreshIfNeeded(now: now)
            }
        }
    }

    private func loadSelectedPlaceIfNeeded(forceRefresh: Bool, showsFeedback: Bool) async {
        guard let place = selectedPlace else { return }

        let cachedSnapshot: WeatherSnapshot?
        if let inMemory = snapshotsByKey[place.cacheKey] {
            cachedSnapshot = inMemory
        } else {
            cachedSnapshot = await repository.cachedSnapshot(for: place.cacheKey)
        }

        if let cached = cachedSnapshot {
            snapshotsByKey[place.cacheKey] = cached
            apply(snapshot: cached, to: place)
        }

        guard reachability.isConnected else {
            recomputeAllStates()
            if showsFeedback {
                HapticManager.warning()
            }
            return
        }

        let existing = snapshotsByKey[place.cacheKey]
        let shouldRefresh = forceRefresh || existing == nil || weatherState?.freshness != .fresh
        guard shouldRefresh else { return }

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let snapshot = try await repository.refreshForecast(for: place, existing: existing)
            snapshotsByKey[place.cacheKey] = snapshot
            apply(snapshot: snapshot, to: place)
            if showsFeedback {
                HapticManager.success()
            }
        } catch {
            recomputeAllStates()
            if showsFeedback {
                HapticManager.error()
            }
        }
    }

    private func autoRefreshIfNeeded(now: Date) async {
        guard isSceneActive,
              reachability.isConnected,
              !isRefreshing,
              let place = selectedPlace,
              let snapshot = snapshotsByKey[place.cacheKey]
        else {
            return
        }

        let freshness = placeSummaries[place.cacheKey]?.freshness
            ?? repository.summary(
                snapshot: snapshot,
                place: place,
                now: now,
                isConnected: reachability.isConnected
            ).freshness

        guard freshness != .fresh else { return }

        if let lastAttempt = lastAutoRefreshAttemptByKey[place.cacheKey],
           now.timeIntervalSince(lastAttempt) < Self.autoRefreshRetryInterval {
            return
        }

        lastAutoRefreshAttemptByKey[place.cacheKey] = now
        await loadSelectedPlaceIfNeeded(forceRefresh: false, showsFeedback: false)
    }

    private func apply(snapshot: WeatherSnapshot, to place: ForecastPlace) {
        let state = repository.resolveState(
            snapshot: snapshot,
            place: place,
            now: clock.now,
            isConnected: reachability.isConnected
        )

        weatherState = state
        placeSummaries[place.cacheKey] = repository.summary(
            snapshot: snapshot,
            place: place,
            now: clock.now,
            isConnected: reachability.isConnected
        )
        reloadWidgets()
    }

    private func hydrateCachedSnapshots() async {
        for place in savedPlaces {
            if let snapshot = await repository.cachedSnapshot(for: place.forecastPlace.cacheKey) {
                snapshotsByKey[place.forecastPlace.cacheKey] = snapshot
                placeSummaries[place.forecastPlace.cacheKey] = repository.summary(
                    snapshot: snapshot,
                    place: place.forecastPlace,
                    now: clock.now,
                    isConnected: reachability.isConnected
                )
            }
        }

        if let snapshot = await repository.cachedSnapshot(for: ForecastPlace.currentLocationCacheKey) {
            let place = ForecastPlace.currentLocation(
                name: normalizedLocationName(from: snapshot.placeName) ?? "Aktueller Ort",
                subtitle: "",
                latitude: snapshot.latitude,
                longitude: snapshot.longitude,
                timezoneIdentifier: snapshot.timezoneIdentifier
            )
            currentLocationPlace = place
            snapshotsByKey[place.cacheKey] = snapshot
            placeSummaries[place.cacheKey] = repository.summary(
                snapshot: snapshot,
                place: place,
                now: clock.now,
                isConnected: reachability.isConnected
            )
        }
    }

    private func handleLocationUpdate(_ location: CLLocation) async {
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        let reverse = try? await geocodingService.reverseGeocode(latitude: latitude, longitude: longitude)
        let cachedName = snapshotsByKey[ForecastPlace.currentLocationCacheKey]?.placeName
        let previousName = currentLocationPlace?.name
        let resolvedSubtitle = reverse?.subtitle ?? currentLocationPlace?.subtitle ?? ""
        let didResetSnapshot = resetCurrentLocationSnapshotIfNeeded(for: location.coordinate)
        let resolvedName = normalizedLocationName(from: reverse?.name)
            ?? (didResetSnapshot ? nil : normalizedLocationName(from: previousName))
            ?? (didResetSnapshot ? nil : normalizedLocationName(from: cachedName))
            ?? "Aktueller Ort"

        let place = ForecastPlace.currentLocation(
            name: resolvedName,
            subtitle: resolvedSubtitle,
            latitude: latitude,
            longitude: longitude,
            timezoneIdentifier: reverse?.timezoneIdentifier ?? currentLocationPlace?.timezoneIdentifier
        )

        currentLocationPlace = place
        hasLiveCurrentLocationFix = true

        if activePlaceSelection == .currentLocation {
            await loadSelectedPlaceIfNeeded(forceRefresh: true, showsFeedback: false)
        }
    }

    private func recomputeAllStates() {
        for (key, snapshot) in snapshotsByKey {
            let place = key == ForecastPlace.currentLocationCacheKey
                ? (currentLocationPlace ?? ForecastPlace.currentLocation(
                    name: normalizedLocationName(from: snapshot.placeName) ?? "Aktueller Ort",
                    subtitle: "",
                    latitude: snapshot.latitude,
                    longitude: snapshot.longitude,
                    timezoneIdentifier: snapshot.timezoneIdentifier
                ))
                : (savedPlaces.first { $0.forecastPlace.cacheKey == key }?.forecastPlace)

            guard let place else { continue }

            placeSummaries[key] = repository.summary(
                snapshot: snapshot,
                place: place,
                now: clock.now,
                isConnected: reachability.isConnected
            )

            if place.cacheKey == selectedPlace?.cacheKey {
                weatherState = repository.resolveState(
                    snapshot: snapshot,
                    place: place,
                    now: clock.now,
                    isConnected: reachability.isConnected
                )
            }
        }
    }

    private func persistPlaces(prefersCurrentLocation: Bool, preferredSavedPlaceID: UUID?) async {
        let document = PersistedPlacesDocument(
            savedPlaces: savedPlaces,
            preferredSavedPlaceID: preferredSavedPlaceID ?? savedPlaces.first?.id,
            prefersCurrentLocation: prefersCurrentLocation
        )
        placesStore.save(document)
        reloadWidgets()
    }

    private func reloadWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    private func normalizedLocationName(from rawValue: String?) -> String? {
        guard let trimmed = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }

        let placeholders = [
            "aktueller ort",
            "aktueller standort",
            "mein standort",
            "standort",
            "current location",
            "zuhause",
            "home",
            "ort",
        ]

        guard !placeholders.contains(trimmed.lowercased()) else { return nil }
        return trimmed
    }

    private func resetCurrentLocationSnapshotIfNeeded(for coordinate: CLLocationCoordinate2D) -> Bool {
        guard let snapshot = snapshotsByKey[ForecastPlace.currentLocationCacheKey] else { return false }

        let cachedLocation = CLLocation(latitude: snapshot.latitude, longitude: snapshot.longitude)
        let liveLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let distance = cachedLocation.distance(from: liveLocation)

        guard distance > Self.currentLocationResetDistance else { return false }

        snapshotsByKey.removeValue(forKey: ForecastPlace.currentLocationCacheKey)
        placeSummaries.removeValue(forKey: ForecastPlace.currentLocationCacheKey)

        if weatherState?.place.cacheKey == ForecastPlace.currentLocationCacheKey {
            weatherState = nil
        }

        return true
    }
}
