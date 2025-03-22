//
//  HousekeepingController.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 21/03/25.
//

import Vapor

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
}
