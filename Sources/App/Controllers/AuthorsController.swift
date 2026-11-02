//
//  AuthorsController.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 22/05/23.
//

import Vapor
import Fluent

struct AuthorsController {

    func postImportAuthorsHandlerV3(req: Request) async throws -> HTTPStatus {
        guard let password = req.parameters.get("password") else {
            throw Abort(.internalServerError)
        }
        guard password == ReleaseConfigs.Passwords.assetOperationPassword else {
            throw Abort(.forbidden)
        }

        let authors = try req.content.decode([Author].self)
        for i in authors.indices {
            authors[i].isHidden = false
        }
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
        content.isHidden = false
        try await req.db.transaction { transaction in
            try await content.save(on: transaction)
        }
        
        guard let contentId = content.id?.uuidString else {
            throw Abort(.internalServerError)
        }
        
        let updateEvent = UpdateEvent(contentId: contentId,
                                      dateTime: Date().iso8601withFractionalSeconds,
                                      mediaType: .author,
                                      eventType: .created,
                                      visible: true)
        try await req.db.transaction { transaction in
            try await updateEvent.save(on: transaction)
        }
        
        return .ok
    }

    func putUpdateAuthorHandlerV3(req: Request) async throws -> HTTPStatus {
        guard let password = req.parameters.get("password") else {
            throw Abort(.badRequest)
        }
        guard password == ReleaseConfigs.Passwords.assetOperationPassword else {
            throw Abort(.forbidden)
        }

        let author = try req.content.decode(Author.self)

        guard let existingAuthor = try await Author.find(author.id, on: req.db) else {
            throw Abort(.notFound)
        }
        existingAuthor.name = author.name
        existingAuthor.photo = author.photo
        existingAuthor.description = author.description
        existingAuthor.externalLinks = author.externalLinks
        // Only when the request carries a number: a MedoHelper from before the
        // field existed doesn't send it, and that shouldn't take anyone out of
        // the row. 0 (or less) takes the author out; a missing key and an
        // explicit null look the same to Fluent, so neither can.
        if let featuredRank = author.featuredRank {
            existingAuthor.featuredRank = featuredRank > 0 ? featuredRank : nil
        }

        let updateEvent = UpdateEvent(
            contentId: try existingAuthor.requireID().uuidString,
            dateTime: Date().iso8601withFractionalSeconds,
            mediaType: .author,
            eventType: .metadataUpdated,
            visible: true
        )

        try await existingAuthor.save(on: req.db)
        try await updateEvent.save(on: req.db)
        return .ok
    }

    func getAuthorHandlerV3(req: Request) async throws -> Author {
        guard let authorId = req.parameters.get("id", as: String.self) else {
            throw Abort(.badRequest)
        }
        guard let authorIdAsUUID = UUID(uuidString: authorId) else {
            throw Abort(.badRequest, reason: "Invalid id.")
        }

        guard let author = try await Author.query(on: req.db)
            .filter(\.$id == authorIdAsUUID)
            .first()
        else {
            throw Abort(.notFound)
        }
        return author
    }

    func getAuthorLinksHandlerV4(req: Request) async throws -> [Author] {
        try await Author.query(on: req.db)
            .filter(\.$isHidden == false)
            .filter(\.$externalLinks != nil)
            .all()
    }

    func getAllAuthorsHandlerV3(req: Request) async throws -> [Author] {
        try await Author.query(on: req.db)
            .filter(\.$isHidden == false)
            .all()
    }
    
    func deleteAuthorHandlerV3(req: Request) async throws -> HTTPStatus {
        guard let password = req.parameters.get("password") else {
            throw Abort(.internalServerError)
        }
        guard password == ReleaseConfigs.Passwords.assetOperationPassword else {
            throw Abort(.forbidden)
        }

        guard let authorId = req.parameters.get("id", as: String.self) else {
            throw Abort(.badRequest)
        }
        guard let authorIdAsUUID = UUID(uuidString: authorId) else {
            throw Abort(.badRequest, reason: "Invalid id.")
        }

        guard let content = try await Author.query(on: req.db)
            .filter(\.$id == authorIdAsUUID)
            .first()
        else {
            throw Abort(.notFound)
        }
        content.isHidden = true
        try await content.save(on: req.db)

        let updateEvent = UpdateEvent(contentId: authorId,
                                      dateTime: Date().iso8601withFractionalSeconds,
                                      mediaType: .author,
                                      eventType: .deleted,
                                      visible: true)
        try await updateEvent.save(on: req.db)
        return .ok
    }
}
