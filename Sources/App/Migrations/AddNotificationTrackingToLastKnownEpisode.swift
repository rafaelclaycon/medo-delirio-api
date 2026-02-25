import Fluent

struct AddNotificationTrackingToLastKnownEpisode: AsyncMigration {

    func prepare(on database: Database) async throws {
        try await database.schema("LastKnownEpisode")
            .field("lastNotificationSentCount", .int)
            .field("lastNotifiedDeviceIds", .string)
            .field("lastNotifiedAt", .datetime)
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema("LastKnownEpisode")
            .deleteField("lastNotificationSentCount")
            .deleteField("lastNotifiedDeviceIds")
            .deleteField("lastNotifiedAt")
            .update()
    }
}
