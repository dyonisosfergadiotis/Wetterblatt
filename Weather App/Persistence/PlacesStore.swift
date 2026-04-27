import Foundation

struct PersistedPlacesDocument: Codable, Sendable {
    var savedPlaces: [SavedPlace]
    var preferredSavedPlaceID: UUID?
    var prefersCurrentLocation: Bool

    static let `default` = PersistedPlacesDocument(
        savedPlaces: [SavedPlace.berlin],
        preferredSavedPlaceID: SavedPlace.berlin.id,
        prefersCurrentLocation: true
    )
}

@MainActor
final class PlacesStore {
    private let fileManager: FileManager
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let directory = SharedStoreSupport.sharedRoot(fileManager: fileManager)
        self.fileURL = directory.appendingPathComponent("places.json")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        self.decoder = JSONDecoder()

        migrateLegacyFileIfNeeded()
    }

    func load() -> PersistedPlacesDocument {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return .default
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(PersistedPlacesDocument.self, from: data)
        } catch {
            return .default
        }
    }

    func save(_ document: PersistedPlacesDocument) {
        do {
            let data = try encoder.encode(document)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Persist best-effort; UI continues to function with in-memory state.
        }
    }

    private func migrateLegacyFileIfNeeded() {
        guard !fileManager.fileExists(atPath: fileURL.path) else { return }

        let legacyURL = SharedStoreSupport.legacyRoot(fileManager: fileManager)
            .appendingPathComponent("places.json")
        guard fileManager.fileExists(atPath: legacyURL.path) else { return }

        try? fileManager.copyItem(at: legacyURL, to: fileURL)
    }
}
