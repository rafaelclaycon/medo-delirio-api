import Fluent
import SQLKit

struct AddUniqueConstraintToInstallId: AsyncMigration {

    func prepare(on database: Database) async throws {
        // SQLite doesn't support ALTER TABLE ADD CONSTRAINT
        // We need to: 1) create new table, 2) copy data, 3) drop old, 4) rename new
        guard let sql = database as? SQLDatabase else {
            // For non-SQLite databases, use standard approach
            try await database.schema("PushDevice")
                .unique(on: "installId")
                .update()
            return
        }
        
        // Create new table with unique constraint
        try await sql.raw("""
            CREATE TABLE PushDevice_new (
                id TEXT PRIMARY KEY,
                installId TEXT NOT NULL UNIQUE,
                pushToken TEXT NOT NULL
            )
            """).run()
        
        // Copy existing data (keeping only the latest token per installId)
        try await sql.raw("""
            INSERT OR REPLACE INTO PushDevice_new (id, installId, pushToken)
            SELECT id, installId, pushToken FROM PushDevice
            GROUP BY installId
            """).run()
        
        // Drop old table
        try await sql.raw("DROP TABLE PushDevice").run()
        
        // Rename new table
        try await sql.raw("ALTER TABLE PushDevice_new RENAME TO PushDevice").run()
    }

    func revert(on database: Database) async throws {
        guard let sql = database as? SQLDatabase else {
            try await database.schema("PushDevice")
                .deleteUnique(on: "installId")
                .update()
            return
        }
        
        // Recreate table without unique constraint
        try await sql.raw("""
            CREATE TABLE PushDevice_new (
                id TEXT PRIMARY KEY,
                installId TEXT NOT NULL,
                pushToken TEXT NOT NULL
            )
            """).run()
        
        try await sql.raw("""
            INSERT INTO PushDevice_new (id, installId, pushToken)
            SELECT id, installId, pushToken FROM PushDevice
            """).run()
        
        try await sql.raw("DROP TABLE PushDevice").run()
        
        try await sql.raw("ALTER TABLE PushDevice_new RENAME TO PushDevice").run()
    }

}

