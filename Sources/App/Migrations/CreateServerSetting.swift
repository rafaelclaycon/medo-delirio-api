import Fluent

struct CreateServerSetting: AsyncMigration {

    func prepare(on database: Database) async throws {
        try await database.schema("ServerSetting")
            .id()
            .field("key", .string, .required)
            .field("value", .string, .required)
            .unique(on: "key")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("ServerSetting").delete()
    }
}
