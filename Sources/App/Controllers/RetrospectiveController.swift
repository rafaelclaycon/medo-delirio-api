//
//  RetrospectiveController.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 25/11/23.
//

import Vapor

struct RetrospectiveController {

    func getRetroStartingVersionHandlerV3(req: Request) throws -> String {
        guard let value = UserDefaults.standard.object(forKey: "show-retro-starting-with-version") else {
            throw Abort(.notFound)
        }
        return String(value as! String)
    }

    func postSetRetroStartingVersionHandlerV3(req: Request) throws -> HTTPStatus {
        let newValue = try req.content.decode(String.self)
        guard newValue.isEmpty == false else {
            return HTTPStatus.badRequest
        }
        UserDefaults.standard.set(newValue, forKey: "show-retro-starting-with-version")
        return .ok
    }
}
