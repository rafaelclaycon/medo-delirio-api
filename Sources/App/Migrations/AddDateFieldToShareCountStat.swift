import Fluent

struct AddDateFieldToShareCountStat: AsyncMigration {

    func prepare(on database: Database) async throws {
        try await database.schema("ShareCountStat")
            .field("dateTime", .datetime)
            .update()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("ShareCountStat")
            .deleteField("dateTime")
            .update()
    }

}
