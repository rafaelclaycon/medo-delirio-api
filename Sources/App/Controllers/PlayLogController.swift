//
//  PlayLogController.swift
//  medo-delirio-api
//
//  Created by Rafael Claycon Schmitt on 06/10/26.
//

import Vapor
import Fluent

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
