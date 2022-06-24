import Fluent

struct CreateStillAliveSignal: AsyncMigration {

    func prepare(on database: Database) async throws {
        try await database.schema("StillAliveSignal")
            .id()
            .field("systemName", .string, .required)
            .field("systemVersion", .string, .required)
            .field("currentTimeZone", .string, .required)
            .field("dateTime", .datetime, .required)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("StillAliveSignal").delete()
    }

}
