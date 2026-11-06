//
//  StatusCheckController.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 22/05/23.
//

import Vapor

struct StatusCheckController {
    
    func getStatusCheckHandlerV1(req: Request) -> String {
        return "Conexão com o servidor OK."
    }
    
    func getStatusCheckHandlerV2(req: Request) -> HTTPStatus {
        return .ok
    }
}

// MARK: - Routes

extension StatusCheckController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let v1 = routes.grouped("api", "v1")
        let v2 = routes.grouped("api", "v2")

        v1.get("status-check", use: getStatusCheckHandlerV1)
        v2.get("status-check", use: getStatusCheckHandlerV2)
    }
}
