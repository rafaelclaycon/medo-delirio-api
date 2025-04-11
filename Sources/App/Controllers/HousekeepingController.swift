//
//  HousekeepingController.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 21/03/25.
//

import Vapor
import SQLiteNIO

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

    func postFixSongStatsHandlerV4(req: Request) async throws -> HTTPStatus {
        guard let sqlite = req.db as? SQLiteDatabase else {
            throw Abort(.internalServerError, reason: "Database does not support raw SQL.")
        }

        try await sqlite.sql().raw("""
            update ShareCountStat
            set contentType =
                case
                    when contentType = 0 then 1
                    when contentType = 2 then 4
                    else contentType
                end
            where contentType in (0, 2)
            and contentId in (
                select id
                from MedoContent
                where contentType = 1
            )
        """).run()

        return .ok
    }
}
