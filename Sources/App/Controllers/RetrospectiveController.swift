//
//  RetrospectiveController.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 25/11/23.
//

import Vapor

struct RetrospectiveController {

    func getRetroStartingVersionHandlerV3(req: Request) async throws -> String {
        guard let value = try await ServerSettingRepository.get(key: "show-classic-retro-starting-with-version", db: req.db) else {
            throw Abort(.notFound)
        }
        return value
    }

    func postSetRetroStartingVersionHandlerV3(req: Request) async throws -> HTTPStatus {
        let newValue = try req.content.decode(String.self)
        guard newValue.isEmpty == false else {
            return HTTPStatus.badRequest
        }
        try await ServerSettingRepository.set(key: "show-classic-retro-starting-with-version", value: newValue, db: req.db)
        return .ok
    }
}
