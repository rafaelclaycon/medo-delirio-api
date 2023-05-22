//
//  AuthorsController.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 22/05/23.
//

import Vapor

struct AuthorsController {
    
    func postImportAuthorsHandlerV3(req: Request) async throws -> HTTPStatus {
        let authors = try req.content.decode([Author].self)
        try await req.db.transaction { transaction in
            try await authors.create(on: transaction)
        }
        return .ok
    }
    
    func postCreateAuthorHandlerV3(req: Request) async throws -> HTTPStatus {
        guard let password = req.parameters.get("password") else {
            throw Abort(.internalServerError)
        }
        guard password == ReleaseConfigs.Passwords.assetOperationPassword else {
            throw Abort(.forbidden)
        }
        let content = try req.content.decode(Author.self)
        try await req.db.transaction { transaction in
            try await content.save(on: transaction)
        }
        return .ok
    }
    
    func getAllAuthorsHandlerV3(req: Request) -> EventLoopFuture<[Author]> {
        Author.query(on: req.db).all()
    }
}
