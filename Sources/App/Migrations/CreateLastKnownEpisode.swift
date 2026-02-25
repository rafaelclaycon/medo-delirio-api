import Fluent

struct CreateLastKnownEpisode: AsyncMigration {

    func prepare(on database: Database) async throws {
        try await database.schema("LastKnownEpisode")
            .id()
            .field("feedURL", .string, .required)
            .field("episodeGUID", .string, .required)
            .field("episodeTitle", .string, .required)
            .field("checkCount", .int, .required)
            .field("checkedAt", .datetime, .required)
            .field("episodeChangedAt", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("LastKnownEpisode").delete()
    }
}
