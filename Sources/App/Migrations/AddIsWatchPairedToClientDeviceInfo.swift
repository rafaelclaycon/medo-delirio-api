import Fluent

struct AddIsWatchPairedToClientDeviceInfo: AsyncMigration {

    func prepare(on database: Database) async throws {
        try await database.schema("ClientDeviceInfo")
            .field("isWatchPaired", .bool)
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema("ClientDeviceInfo")
            .deleteField("isWatchPaired")
            .update()
    }
}
