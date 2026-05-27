import Fluent

struct ServerSettingRepository {

    static func get(key: String, db: Database) async throws -> String? {
        try await ServerSetting.query(on: db)
            .filter(\.$key == key)
            .first()
            .map { $0.value }
    }

    static func set(key: String, value: String, db: Database) async throws {
        if let existing = try await ServerSetting.query(on: db)
            .filter(\.$key == key)
            .first()
        {
            existing.value = value
            try await existing.save(on: db)
        } else {
            try await ServerSetting(key: key, value: value).save(on: db)
        }
    }
}
