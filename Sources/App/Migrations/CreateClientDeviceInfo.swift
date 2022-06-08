import Fluent

struct CreateClientDeviceInfo: AsyncMigration {

    func prepare(on database: Database) async throws {
        try await database.schema("ClientDeviceInfo")
            .id()
            .field("installId", .string, .required)
            .field("modelName", .string, .required)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("ClientDeviceInfo").delete()
    }

}
