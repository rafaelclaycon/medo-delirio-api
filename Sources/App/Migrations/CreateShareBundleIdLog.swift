import Fluent

struct CreateShareBundleIdLog: AsyncMigration {

    func prepare(on database: Database) async throws {
        try await database.schema("ShareBundleIdLog")
            .id()
            .field("bundleId", .string, .required)
            .field("count", .int, .required)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("ShareBundleIdLog").delete()
    }

}
