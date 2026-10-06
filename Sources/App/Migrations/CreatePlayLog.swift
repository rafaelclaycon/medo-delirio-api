//
//  CreatePlayLog.swift
//  medo-delirio-api
//
//  Created by Rafael Claycon Schmitt on 06/10/26.
//

import Fluent
import SQLKit

struct CreatePlayLog: AsyncMigration {

    func prepare(on database: Database) async throws {
        try await database.schema("PlayLog")
            .id()
            .field("installId", .string, .required)
            .field("contentId", .string, .required)
            .field("contentType", .int, .required)
            .field("dateTime", .string, .required)
            .field("isAutoplay", .bool, .required)
            .field("appVersion", .string, .required)
            .create()

        // Plays are expected to outnumber every other table here by far, so the ranking
        // queries (by date, per content) get their indexes from day one rather than after
        // the table is already slow, as happened with UsageMetric.
        guard let sql = database as? SQLDatabase else {
            return
        }

        try await sql.raw("CREATE INDEX IF NOT EXISTS idx_PlayLog_dateTime ON PlayLog(dateTime)").run()
        try await sql.raw("CREATE INDEX IF NOT EXISTS idx_PlayLog_contentId ON PlayLog(contentId)").run()
    }

    func revert(on database: Database) async throws {
        try await database.schema("PlayLog").delete()
    }
}
