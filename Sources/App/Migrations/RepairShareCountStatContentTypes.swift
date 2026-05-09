import Fluent
import SQLKit

/// Repairs `ShareCountStat.contentType` from `MedoContent.contentType` while preserving regular vs video share events.
struct RepairShareCountStatContentTypes: AsyncMigration {

    func prepare(on database: Database) async throws {
        guard let sql = database as? SQLDatabase else {
            return
        }

        try await sql.raw("""
            UPDATE ShareCountStat
            SET contentType = CASE
                WHEN (
                    SELECT c.contentType
                    FROM MedoContent c
                    WHERE c.id = ShareCountStat.contentId
                ) = 0 THEN
                    CASE WHEN ShareCountStat.contentType IN (2, 3, 4) THEN 2 ELSE 0 END
                WHEN (
                    SELECT c.contentType
                    FROM MedoContent c
                    WHERE c.id = ShareCountStat.contentId
                ) = 1 THEN
                    CASE WHEN ShareCountStat.contentType IN (2, 3, 4) THEN 3 ELSE 1 END
                ELSE ShareCountStat.contentType
            END
            WHERE (
                (
                    SELECT c.contentType
                    FROM MedoContent c
                    WHERE c.id = ShareCountStat.contentId
                ) = 0
                AND ShareCountStat.contentType IN (1, 3, 4)
            ) OR (
                (
                    SELECT c.contentType
                    FROM MedoContent c
                    WHERE c.id = ShareCountStat.contentId
                ) = 1
                AND ShareCountStat.contentType IN (0, 2, 4)
            )
            """).run()
    }

    func revert(on database: Database) async throws {
        // Irreversible data repair; no-op revert.
    }
}
