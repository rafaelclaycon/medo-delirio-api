import Fluent

struct CreateChannelSubscriptionEvent: AsyncMigration {

    func prepare(on database: Database) async throws {
        try await database.schema("ChannelSubscriptionEvent")
            .id()
            .field("installId", .string, .required)
            .field("channelId", .string, .required)
            .field("action", .string, .required)
            .field("dateTime", .string, .required)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("ChannelSubscriptionEvent").delete()
    }
}
