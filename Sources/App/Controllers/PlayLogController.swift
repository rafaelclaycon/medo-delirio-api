//
//  PlayLogController.swift
//  medo-delirio-api
//
//  Created by Rafael Claycon Schmitt on 06/10/26.
//

import Vapor
import Fluent
import SQLiteNIO

struct PlayLogController {

    /// The app sends 250 at a time. The ceiling also keeps the `IN (...)` lookups below
    /// SQLite's 999-parameter limit on older builds.
    static let maxPlaysPerBatch = 500

    /// Also passed to the route's body collector. Vapor's 16 KB default fits only about a
    /// hundred plays.
    static let maxBodySize: ByteCount = "256kb"

    struct PlayLogBatch: Content {
        let installId: String
        let appVersion: String
        let plays: [Play]
    }

    struct Play: Content {
        let id: String
        let contentId: String
        let dateTime: String
        let isAutoplay: Bool
    }

    struct PlayLogBatchResponse: Content {
        /// Plays in the request.
        let received: Int
        /// Plays new to the server. Repeats, malformed rows and unknown content are left out.
        let stored: Int
    }

    /// Stores a batch of plays.
    ///
    /// Rows that can't be stored are dropped rather than failing the batch: the app keeps
    /// unsent plays until a request succeeds, so rejecting the whole batch for one play of
    /// since-deleted content would block that install's queue forever. A play ID the server
    /// already has is skipped, which makes re-sending a batch harmless.
    func postPlayLogsHandlerV4(req: Request) async throws -> PlayLogBatchResponse {
        let batch = try req.content.decode(PlayLogBatch.self)

        guard !batch.installId.isEmpty else {
            throw Abort(.badRequest, reason: "Missing installId.")
        }
        guard batch.plays.count <= Self.maxPlaysPerBatch else {
            throw Abort(.payloadTooLarge, reason: "At most \(Self.maxPlaysPerBatch) plays per batch.")
        }

        var seenIds = Set<UUID>()
        let candidates: [(id: UUID, contentId: UUID, play: Play)] = batch.plays.compactMap { play in
            guard
                let id = UUID(uuidString: play.id),
                let contentId = UUID(uuidString: play.contentId),
                Self.isValidDateTime(play.dateTime),
                seenIds.insert(id).inserted
            else { return nil }
            return (id, contentId, play)
        }

        guard !candidates.isEmpty else {
            return PlayLogBatchResponse(received: batch.plays.count, stored: 0)
        }

        let contentIds = Array(Set(candidates.map(\.contentId)))
        let contentTypeById = try await MedoContent.query(on: req.db)
            .filter(\.$id ~~ contentIds)
            .all()
            .reduce(into: [UUID: ContentType]()) { result, content in
                if let id = content.id {
                    result[id] = content.contentType
                }
            }

        let alreadyStoredIds = try await Set(
            PlayLog.query(on: req.db)
                .filter(\.$id ~~ candidates.map(\.id))
                .all(\.$id)
        )

        let newLogs: [PlayLog] = candidates.compactMap { candidate in
            guard
                !alreadyStoredIds.contains(candidate.id),
                let contentType = contentTypeById[candidate.contentId]
            else { return nil }

            return PlayLog(
                id: candidate.id,
                installId: batch.installId,
                // Canonical uppercase text, the way `MedoContent.id` is stored, so the two
                // join on plain equality whatever casing the app sent.
                contentId: candidate.contentId.uuidString,
                contentType: contentType.rawValue,
                dateTime: candidate.play.dateTime,
                isAutoplay: candidate.play.isAutoplay,
                appVersion: batch.appVersion
            )
        }

        if !newLogs.isEmpty {
            try await req.db.transaction { transaction in
                for log in newLogs {
                    try await log.create(on: transaction)
                }
            }
        }

        return PlayLogBatchResponse(received: batch.plays.count, stored: newLogs.count)
    }

    private static func isValidDateTime(_ value: String) -> Bool {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) != nil
    }
}

// MARK: - Rankings

/// The most played sounds and songs, with the same periods as the share rankings
/// (`v3/sound-share-count-stats-*`), so the app can build both URLs the same way.
///
/// Only plays someone started count: a playlist advancing on its own says more about what
/// was queued next than about what people want to hear.
extension PlayLogController {

    func getSoundPlayCountStatsAllTimeHandlerV4(req: Request) async throws -> [TopPlayedItem] {
        try await topPlayed(.sound, from: nil, through: nil, on: req)
    }

    func getSoundPlayCountStatsFromHandlerV4(req: Request) async throws -> [TopPlayedItem] {
        guard let date = req.parameters.get("date") else {
            throw Abort(.badRequest, reason: "Missing date parameter.")
        }
        return try await topPlayed(.sound, from: date, through: nil, on: req)
    }

    func getSoundPlayCountStatsFromToHandlerV4(req: Request) async throws -> [TopPlayedItem] {
        guard
            let firstDate = req.parameters.get("firstDate"),
            let secondDate = req.parameters.get("secondDate")
        else {
            throw Abort(.badRequest, reason: "Missing date parameters.")
        }
        return try await topPlayed(.sound, from: firstDate, through: secondDate, on: req)
    }

    func getSongPlayCountStatsAllTimeHandlerV4(req: Request) async throws -> [TopPlayedItem] {
        try await topPlayed(.song, from: nil, through: nil, on: req)
    }

    func getSongPlayCountStatsFromHandlerV4(req: Request) async throws -> [TopPlayedItem] {
        guard let date = req.parameters.get("date") else {
            throw Abort(.badRequest, reason: "Missing date parameter.")
        }
        return try await topPlayed(.song, from: date, through: nil, on: req)
    }

    func getSongPlayCountStatsFromToHandlerV4(req: Request) async throws -> [TopPlayedItem] {
        guard
            let firstDate = req.parameters.get("firstDate"),
            let secondDate = req.parameters.get("secondDate")
        else {
            throw Abort(.badRequest, reason: "Missing date parameters.")
        }
        return try await topPlayed(.song, from: firstDate, through: secondDate, on: req)
    }

    /// The top 10 of one content type, by plays and then by how many installs played it.
    ///
    /// `through` includes the whole of its last day: `2026-12-31` keeps plays from that
    /// afternoon, which a plain `BETWEEN` against the full timestamps would drop. Hidden
    /// content is left out, since the app can't open it.
    private func topPlayed(
        _ contentType: ContentType,
        from firstDate: String?,
        through lastDate: String?,
        on req: Request
    ) async throws -> [TopPlayedItem] {
        guard let sqlite = req.db as? SQLiteDatabase else {
            return []
        }

        let subtitle = contentType == .song
            ? (select: "'' AS authorId, COALESCE(mg.name, '') AS authorName", join: "LEFT JOIN MusicGenre mg ON mg.id = c.musicGenre")
            : (select: "COALESCE(a.id, '') AS authorId, COALESCE(a.name, '') AS authorName", join: "LEFT JOIN Author a ON a.id = c.authorId")

        var conditions = ["p.contentType = ?", "p.isAutoplay = 0", "c.isHidden = 0"]
        var binds: [SQLiteData] = [.integer(contentType.rawValue)]
        if let firstDate {
            conditions.append("p.dateTime >= ?")
            binds.append(.text(firstDate))
        }
        if let lastDate {
            // `dateTime` is an ISO 8601 string and '~' sorts after every character in one,
            // so this keeps every timestamp that starts with `lastDate`.
            conditions.append("p.dateTime < ?")
            binds.append(.text(lastDate + "~"))
        }

        let query = """
            SELECT
                p.contentId,
                c.title AS contentName,
                \(subtitle.select),
                COUNT(*) AS playCount,
                COUNT(DISTINCT p.installId) AS uniqueListeners
            FROM PlayLog p
            INNER JOIN MedoContent c ON c.id = p.contentId
            \(subtitle.join)
            WHERE \(conditions.joined(separator: "\n  AND "))
            GROUP BY p.contentId
            ORDER BY playCount DESC, uniqueListeners DESC
            LIMIT 10
        """

        let rows = try await sqlite.query(query, binds).get()
        return rows.map { row in
            TopPlayedItem(
                rankNumber: "",
                contentId: row.column("contentId")?.string ?? "",
                contentName: row.column("contentName")?.string ?? "",
                contentAuthorId: row.column("authorId")?.string ?? "",
                contentAuthorName: row.column("authorName")?.string ?? "",
                playCount: row.column("playCount")?.integer ?? 0,
                uniqueListeners: row.column("uniqueListeners")?.integer ?? 0
            )
        }
    }
}
