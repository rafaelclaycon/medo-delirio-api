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

    func postReplaceDeviceModelNameHandlerV4(req: Request) async throws -> HTTPStatus {
        guard let password = req.parameters.get("password") else {
            throw Abort(.badRequest)
        }
        guard let oldName = req.parameters.get("oldName") else {
            throw Abort(.badRequest)
        }
        guard let newName = req.parameters.get("newName") else {
            throw Abort(.badRequest)
        }
        guard password == ReleaseConfigs.Passwords.assetOperationPassword else {
            throw Abort(.forbidden)
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
        guard let password = req.parameters.get("password") else {
            throw Abort(.badRequest)
        }
        guard password == ReleaseConfigs.Passwords.assetOperationPassword else {
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
