import Fluent
import SQLKit

/// Statistics queries filter `UsageMetric` by `dateTime`, and without an index each one
/// scans the whole table, every event since 2022. Matters most for the public
/// popular-episodes endpoint the app calls on launch.
struct AddUsageMetricDateTimeIndex: AsyncMigration {

    func prepare(on database: Database) async throws {
        guard let sql = database as? SQLDatabase else {
            return
        }

        try await sql.raw("CREATE INDEX IF NOT EXISTS idx_UsageMetric_dateTime ON UsageMetric(dateTime)").run()
    }

    func revert(on database: Database) async throws {
        guard let sql = database as? SQLDatabase else {
            return
        }

        try await sql.raw("DROP INDEX IF EXISTS idx_UsageMetric_dateTime").run()
    }
}
