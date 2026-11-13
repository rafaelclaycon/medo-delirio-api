//
//  HousekeepingController.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 21/03/25.
//

import Vapor
import Fluent
import SQLKit

struct HousekeepingController {

    /// The names come from the path (`…/:password/:oldName/:newName`) or, on the header
    /// route, from the query (`?oldName=…&newName=…`).
    func postReplaceDeviceModelNameHandlerV4(req: Request) async throws -> HTTPStatus {
        guard req.adminPassword == ReleaseConfigs.Passwords.assetOperationPassword else {
            throw Abort(.forbidden)
        }
        guard let oldName = req.parameters.get("oldName") ?? req.query[String.self, at: "oldName"] else {
            throw Abort(.badRequest)
        }
        guard let newName = req.parameters.get("newName") ?? req.query[String.self, at: "newName"] else {
            throw Abort(.badRequest)
        }

        try await req.db.transaction { transaction in
            try await ClientDeviceInfo.query(on: transaction)
                .filter(\ClientDeviceInfo.$modelName, .equal, oldName)
                .set(\ClientDeviceInfo.$modelName, to: newName)
                .update()

            try await StillAliveSignal.query(on: transaction)
                .filter(\StillAliveSignal.$modelName, .equal, oldName)
                .set(\StillAliveSignal.$modelName, to: newName)
                .update()
        }
        return .ok
    }

    /// Idempotent repair: align `ShareCountStat.contentType` with `MedoContent` while preserving regular vs video shares.
    func postRepairShareCountStatContentTypesHandlerV4(req: Request) async throws -> HTTPStatus {
        guard req.adminPassword == ReleaseConfigs.Passwords.assetOperationPassword else {
            throw Abort(.forbidden)
        }
        guard let sql = req.db as? SQLDatabase else {
            throw Abort(.internalServerError, reason: "Database does not support raw SQL.")
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

        return .ok
    }
}

// MARK: - Routes

extension HousekeepingController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let v4 = routes.grouped("api", "v4")

        // Not `admin(...)`: the router can't hold `:oldName` where this path has `:password`,
        // so the header route takes the names in the query instead.
        v4.post("replace-device-model-name", ":password", ":oldName", ":newName", use: postReplaceDeviceModelNameHandlerV4)
        v4.post("replace-device-model-name", use: postReplaceDeviceModelNameHandlerV4)
        v4.admin(.POST, "repair-share-count-stat-content-types", ":password", use: postRepairShareCountStatContentTypesHandlerV4)
    }
}
