import Fluent
import SQLKit

struct MakePushTokenOptional: AsyncMigration {

    func prepare(on database: Database) async throws {
        guard let sql = database as? SQLDatabase else {
            try await database.schema("PushDevice")
                .updateField("pushToken", .string)
                .update()
            return
        }

        try await sql.raw("""
            CREATE TABLE PushDevice_new (
                id TEXT PRIMARY KEY,
                installId TEXT NOT NULL UNIQUE,
                pushToken TEXT
            )
            """).run()

        try await sql.raw("""
            INSERT INTO PushDevice_new (id, installId, pushToken)
            SELECT id, installId, pushToken FROM PushDevice
            """).run()

        try await sql.raw("DROP TABLE PushDevice").run()

        try await sql.raw("ALTER TABLE PushDevice_new RENAME TO PushDevice").run()
    }

    func revert(on database: Database) async throws {
        guard let sql = database as? SQLDatabase else {
            try await database.schema("PushDevice")
                .field("pushToken", .string, .required)
                .update()
            return
        }

        try await sql.raw("""
            CREATE TABLE PushDevice_new (
                id TEXT PRIMARY KEY,
                installId TEXT NOT NULL UNIQUE,
                pushToken TEXT NOT NULL
            )
            """).run()

        try await sql.raw("""
            INSERT INTO PushDevice_new (id, installId, pushToken)
            SELECT id, installId, COALESCE(pushToken, '') FROM PushDevice
            """).run()

        try await sql.raw("DROP TABLE PushDevice").run()

        try await sql.raw("ALTER TABLE PushDevice_new RENAME TO PushDevice").run()
    }
}
