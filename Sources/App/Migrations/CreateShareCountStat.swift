import Fluent

struct CreateShareCountStat: AsyncMigration {

    func prepare(on database: Database) async throws {
        try await database.schema("ShareCountStat")
            .id()
            .field("installId", .string, .required)
            .field("contentId", .string, .required)
            .field("contentType", .int, .required)
            .field("shareCount", .int, .required)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("ShareCountStat").delete()
    }

}
