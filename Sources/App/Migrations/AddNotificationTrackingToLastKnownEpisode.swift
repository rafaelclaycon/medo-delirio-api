import Fluent

struct AddNotificationTrackingToLastKnownEpisode: AsyncMigration {

    func prepare(on database: Database) async throws {
        try await database.schema("LastKnownEpisode")
            .field("lastNotificationSentCount", .int)
            .update()
        try await database.schema("LastKnownEpisode")
            .field("lastNotifiedDeviceIds", .string)
            .update()
        try await database.schema("LastKnownEpisode")
            .field("lastNotifiedAt", .datetime)
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema("LastKnownEpisode")
            .deleteField("lastNotificationSentCount")
            .update()
        try await database.schema("LastKnownEpisode")
            .deleteField("lastNotifiedDeviceIds")
            .update()
        try await database.schema("LastKnownEpisode")
            .deleteField("lastNotifiedAt")
            .update()
    }
}
