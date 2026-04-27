import Foundation

nonisolated enum SharedStoreSupport {
    static let appGroupIdentifier = "group.DyonisosFergadiotis.Wetterblatt"

    static func sharedRoot(fileManager: FileManager = .default) -> URL {
        if let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            let root = containerURL.appendingPathComponent("WetterblattShared", isDirectory: true)
            ensureDirectory(root, fileManager: fileManager)
            return root
        }

        return legacyRoot(fileManager: fileManager)
    }

    static func legacyRoot(fileManager: FileManager = .default) -> URL {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let root = support.appendingPathComponent("Wetterblatt", isDirectory: true)
        ensureDirectory(root, fileManager: fileManager)
        return root
    }

    static func ensureDirectory(_ url: URL, fileManager: FileManager = .default) {
        guard !fileManager.fileExists(atPath: url.path) else { return }
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
