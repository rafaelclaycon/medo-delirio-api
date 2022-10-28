import Fluent

struct CreateStillAliveSignal: AsyncMigration {

    func prepare(on database: Database) async throws {
        try await database.schema("StillAliveSignal")
            .id()
            .field("installId", .string, .required)
            .field("modelName", .string, .required)
            .field("systemName", .string, .required)
            .field("systemVersion", .string, .required)
            .field("isiOSAppOnMac", .bool, .required)
            .field("appVersion", .string, .required)
            .field("currentTimeZone", .string, .required)
            .field("dateTime", .string, .required)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("StillAliveSignal").delete()
    }

}
