import Fluent
import Foundation

struct ElectionSettingsRepository {

    static func load(db: Database) async throws -> ElectionSettings {
        guard let json = try await ServerSettingRepository.get(key: ElectionSettings.settingKey, db: db) else {
            return ElectionSettings()
        }
        return try JSONDecoder().decode(ElectionSettings.self, from: Data(json.utf8))
    }

    static func save(_ settings: ElectionSettings, db: Database) async throws {
        let data = try JSONEncoder().encode(settings)
        try await ServerSettingRepository.set(key: ElectionSettings.settingKey, value: String(decoding: data, as: UTF8.self), db: db)
    }
}
