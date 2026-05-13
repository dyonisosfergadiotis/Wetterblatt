import Foundation

struct PersistedSettingsDocument: Codable, Sendable {
    var isHapticsEnabled: Bool
    var showsPollen: Bool
    var selectedPollenTypes: [PollenType]
    var temperatureUnit: TemperatureUnitPreference
    var windSpeedUnit: WindSpeedUnitPreference
    var precipitationUnit: PrecipitationUnitPreference
    var reducesMotionEffects: Bool
    var widgetPlaceSelection: WidgetPlaceSelection
    var heroThemes: [HeroThemeRule]

    static let `default` = PersistedSettingsDocument(
        isHapticsEnabled: true,
        showsPollen: true,
        selectedPollenTypes: PollenType.allCases,
        temperatureUnit: .celsius,
        windSpeedUnit: .kilometersPerHour,
        precipitationUnit: .millimeters,
        reducesMotionEffects: false,
        widgetPlaceSelection: .default,
        heroThemes: []
    )

    init(
        isHapticsEnabled: Bool,
        showsPollen: Bool,
        selectedPollenTypes: [PollenType],
        temperatureUnit: TemperatureUnitPreference,
        windSpeedUnit: WindSpeedUnitPreference,
        precipitationUnit: PrecipitationUnitPreference,
        reducesMotionEffects: Bool,
        widgetPlaceSelection: WidgetPlaceSelection,
        heroThemes: [HeroThemeRule]
    ) {
        self.isHapticsEnabled = isHapticsEnabled
        self.showsPollen = showsPollen
        self.selectedPollenTypes = selectedPollenTypes
        self.temperatureUnit = temperatureUnit
        self.windSpeedUnit = windSpeedUnit
        self.precipitationUnit = precipitationUnit
        self.reducesMotionEffects = reducesMotionEffects
        self.widgetPlaceSelection = widgetPlaceSelection
        self.heroThemes = heroThemes
    }

    enum CodingKeys: String, CodingKey {
        case isHapticsEnabled
        case showsPollen
        case selectedPollenTypes
        case temperatureUnit
        case windSpeedUnit
        case precipitationUnit
        case reducesMotionEffects
        case widgetPlaceSelection
        case heroThemes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isHapticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .isHapticsEnabled) ?? true
        showsPollen = try container.decodeIfPresent(Bool.self, forKey: .showsPollen) ?? true
        selectedPollenTypes = try container.decodeIfPresent([PollenType].self, forKey: .selectedPollenTypes) ?? PollenType.allCases
        temperatureUnit = try container.decodeIfPresent(TemperatureUnitPreference.self, forKey: .temperatureUnit) ?? .celsius
        windSpeedUnit = try container.decodeIfPresent(WindSpeedUnitPreference.self, forKey: .windSpeedUnit) ?? .kilometersPerHour
        precipitationUnit = try container.decodeIfPresent(PrecipitationUnitPreference.self, forKey: .precipitationUnit) ?? .millimeters
        reducesMotionEffects = try container.decodeIfPresent(Bool.self, forKey: .reducesMotionEffects) ?? false
        widgetPlaceSelection = try container.decodeIfPresent(WidgetPlaceSelection.self, forKey: .widgetPlaceSelection) ?? .default
        heroThemes = try container.decodeIfPresent([HeroThemeRule].self, forKey: .heroThemes) ?? []
    }
}

@MainActor
final class SettingsStore {
    private let fileManager: FileManager
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let directory = SharedStoreSupport.sharedRoot(fileManager: fileManager)
        self.fileURL = directory.appendingPathComponent("settings.json")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        self.decoder = JSONDecoder()
    }

    func load() -> PersistedSettingsDocument {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return .default
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(PersistedSettingsDocument.self, from: data)
        } catch {
            return .default
        }
    }

    func save(_ document: PersistedSettingsDocument) {
        do {
            let data = try encoder.encode(document)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Persist best-effort; the in-memory settings remain active.
        }
    }
}
