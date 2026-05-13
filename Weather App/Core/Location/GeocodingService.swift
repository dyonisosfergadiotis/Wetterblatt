import CoreLocation
import Foundation
import MapKit

struct GeocodingService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func search(query: String) async throws -> [PlaceSearchResult] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "geocoding-api.open-meteo.com"
        components.path = "/v1/search"
        components.queryItems = [
            URLQueryItem(name: "name", value: query),
            URLQueryItem(name: "count", value: "8"),
            URLQueryItem(name: "language", value: "de"),
            URLQueryItem(name: "format", value: "json"),
        ]

        guard let url = components.url else {
            throw GeocodingServiceError.invalidURL
        }

        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(SearchResponse.self, from: data)

        return response.results?.map {
            PlaceSearchResult(
                name: $0.name,
                subtitle: [$0.admin1, $0.country].compactMap { $0 }.joined(separator: ", "),
                latitude: $0.latitude,
                longitude: $0.longitude,
                timezoneIdentifier: $0.timezone
            )
        } ?? []
    }

    func reverseGeocode(latitude: Double, longitude: Double) async throws -> PlaceSearchResult? {
        if let result = try await reverseGeocodeWithOpenMeteo(latitude: latitude, longitude: longitude),
           !isGenericLocationName(result.name) {
            return result
        }

        if let result = try await reverseGeocodeWithCoreLocation(latitude: latitude, longitude: longitude) {
            return result
        }

        return try await reverseGeocodeWithOpenMeteo(latitude: latitude, longitude: longitude)
    }

    private func reverseGeocodeWithOpenMeteo(latitude: Double, longitude: Double) async throws -> PlaceSearchResult? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "geocoding-api.open-meteo.com"
        components.path = "/v1/reverse"
        components.queryItems = [
            URLQueryItem(name: "latitude", value: coordinateString(latitude)),
            URLQueryItem(name: "longitude", value: coordinateString(longitude)),
            URLQueryItem(name: "language", value: "de"),
            URLQueryItem(name: "format", value: "json"),
        ]

        guard let url = components.url else {
            throw GeocodingServiceError.invalidURL
        }

        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(SearchResponse.self, from: data)
        guard let first = response.results?.first else { return nil }

        return PlaceSearchResult(
            name: first.name,
            subtitle: [first.admin1, first.country].compactMap { $0 }.joined(separator: ", "),
            latitude: first.latitude,
            longitude: first.longitude,
            timezoneIdentifier: first.timezone
        )
    }

    private func reverseGeocodeWithCoreLocation(latitude: Double, longitude: Double) async throws -> PlaceSearchResult? {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let locale = Locale(identifier: "de_DE")

        if #available(iOS 26.0, macOS 26.0, *) {
            guard let request = MKReverseGeocodingRequest(location: location) else {
                return nil
            }

            request.preferredLocale = locale
            let mapItems = try await request.mapItems

            guard let item = mapItems.first,
                  let name = resolvedPlaceName(from: item) else {
                return nil
            }

            return PlaceSearchResult(
                name: name,
                subtitle: resolvedSubtitle(from: item, name: name),
                latitude: latitude,
                longitude: longitude,
                timezoneIdentifier: item.timeZone?.identifier
            )
        } else {
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(
                location,
                preferredLocale: locale
            )

            guard let placemark = placemarks.first,
                  let name = resolvedPlaceName(from: placemark) else {
                return nil
            }

            return PlaceSearchResult(
                name: name,
                subtitle: resolvedSubtitle(from: placemark),
                latitude: latitude,
                longitude: longitude,
                timezoneIdentifier: placemark.timeZone?.identifier
            )
        }
    }

    private func coordinateString(_ value: Double) -> String {
        String(format: "%.4f", value)
    }

    private func resolvedPlaceName(from placemark: CLPlacemark) -> String? {
        let candidates = [
            placemark.locality,
        ]

        return candidates
            .compactMap(normalizedComponent)
            .first(where: { !isGenericLocationName($0) })
    }

    @available(iOS 26.0, macOS 26.0, *)
    private func resolvedPlaceName(from item: MKMapItem) -> String? {
        let candidates = [
            item.addressRepresentations?.cityName,
            cityName(fromContext: item.addressRepresentations?.cityWithContext),
        ]

        return candidates
            .compactMap(normalizedComponent)
            .first(where: { !isGenericLocationName($0) })
    }

    private func cityName(fromContext value: String?) -> String? {
        normalizedComponent(value)?
            .components(separatedBy: ",")
            .first
            .flatMap(normalizedComponent)
    }

    private func resolvedSubtitle(from placemark: CLPlacemark) -> String {
        let components = [
            normalizedComponent(placemark.administrativeArea),
            normalizedComponent(placemark.country),
        ].compactMap { $0 }

        var uniqueComponents: [String] = []
        for component in components where !uniqueComponents.contains(component) {
            uniqueComponents.append(component)
        }

        return uniqueComponents.joined(separator: ", ")
    }

    @available(iOS 26.0, macOS 26.0, *)
    private func resolvedSubtitle(from item: MKMapItem, name: String) -> String {
        let components = [
            normalizedComponent(item.addressRepresentations?.cityWithContext),
            normalizedComponent(item.addressRepresentations?.regionName),
            normalizedComponent(item.address?.shortAddress),
        ].compactMap { $0 }

        var uniqueComponents: [String] = []
        for component in components where component != name && !uniqueComponents.contains(component) {
            uniqueComponents.append(component)
        }

        return uniqueComponents.joined(separator: ", ")
    }

    private func normalizedComponent(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }

        return trimmed
    }

    private func isGenericLocationName(_ value: String) -> Bool {
        let placeholders = [
            "aktueller ort",
            "aktueller standort",
            "mein standort",
            "standort",
            "current location",
            "home",
            "ort",
        ]

        return placeholders.contains(value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }
}

private struct SearchResponse: Decodable {
    var results: [SearchResultDTO]?
}

private struct SearchResultDTO: Decodable {
    var name: String
    var latitude: Double
    var longitude: Double
    var country: String?
    var admin1: String?
    var timezone: String?
}

private enum GeocodingServiceError: Error {
    case invalidURL
}
