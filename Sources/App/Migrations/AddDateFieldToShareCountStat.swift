import Fluent

struct AddDateFieldToShareCountStat: AsyncMigration {

    func prepare(on database: Database) async throws {
        try await database.schema("ShareCountStat")
            .field("date", .datetime)
            .update()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("ShareCountStat")
            .deleteField("date")
            .update()
    }

}
