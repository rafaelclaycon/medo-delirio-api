import Fluent

struct CreateWeeklyHighlightLog: AsyncMigration {

    func prepare(on database: Database) async throws {
        try await database.schema("WeeklyHighlightLog")
            .id()
            .field("weekNumber", .int, .required)
            .field("notificationType", .string, .required)
            .field("topContentName", .string, .required)
            .field("sentCount", .int, .required)
            .field("dateTime", .string, .required)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("WeeklyHighlightLog").delete()
    }
}
