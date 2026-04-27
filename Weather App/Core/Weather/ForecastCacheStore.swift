import Foundation

actor ForecastCacheStore {
    private let fileManager: FileManager
    private let directoryURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.directoryURL = SharedStoreSupport.sharedRoot(fileManager: fileManager)
            .appendingPathComponent("ForecastCache", isDirectory: true)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        SharedStoreSupport.ensureDirectory(directoryURL, fileManager: fileManager)
        Self.migrateLegacyDirectoryIfNeeded(fileManager: fileManager, directoryURL: directoryURL)
    }

    func loadSnapshot(for cacheKey: String) -> WeatherSnapshot? {
        let url = fileURL(for: cacheKey)
        guard fileManager.fileExists(atPath: url.path) else { return nil }

        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(WeatherSnapshot.self, from: data)
        } catch {
            return nil
        }
    }

    func saveSnapshot(_ snapshot: WeatherSnapshot, for cacheKey: String) {
        do {
            let data = try encoder.encode(snapshot)
            try data.write(to: fileURL(for: cacheKey), options: .atomic)
        } catch {
            // Cache writes are best-effort.
        }
    }

    private func fileURL(for cacheKey: String) -> URL {
        let safeKey = cacheKey.replacingOccurrences(of: "/", with: "-")
        return directoryURL.appendingPathComponent("\(safeKey).json")
    }

    private static func migrateLegacyDirectoryIfNeeded(fileManager: FileManager, directoryURL: URL) {
        let legacyDirectory = SharedStoreSupport.legacyRoot(fileManager: fileManager)
            .appendingPathComponent("ForecastCache", isDirectory: true)

        guard fileManager.fileExists(atPath: legacyDirectory.path) else { return }
        let hasExistingFiles = ((try? fileManager.contentsOfDirectory(atPath: directoryURL.path)) ?? []).isEmpty == false
        guard !hasExistingFiles else { return }

        let urls = (try? fileManager.contentsOfDirectory(
            at: legacyDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []

        for url in urls {
            let target = directoryURL.appendingPathComponent(url.lastPathComponent)
            guard !fileManager.fileExists(atPath: target.path) else { continue }
            try? fileManager.copyItem(at: url, to: target)
        }
    }
}
