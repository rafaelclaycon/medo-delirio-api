import Fluent

struct CreateDeviceChannel: AsyncMigration {

    func prepare(on database: Database) async throws {
        try await database.schema("PushDevice+PushChannel")
            .id()
            .field("deviceId", .uuid, .required, .references("PushDevice", "id", onDelete: .cascade))
            .field("channelId", .uuid, .required, .references("PushChannel", "id", onDelete: .cascade))
            .unique(on: "deviceId", "channelId")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("PushDevice+PushChannel").delete()
    }
}
