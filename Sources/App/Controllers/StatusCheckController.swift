//
//  StatusCheckController.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 22/05/23.
//

import Vapor

struct StatusCheckController {
    
    func getStatusCheckHandlerV1(req: Request) throws -> EventLoopFuture<String> {
        return req.eventLoop.makeSucceededFuture("Conexão com o servidor OK.")
    }
    
    func getStatusCheckHandlerV2(req: Request) -> HTTPStatus {
        return .ok
    }
}
