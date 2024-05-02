//
//  ReactionsController.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 01/05/24.
//

import Vapor
import Fluent

struct ReactionsController {

    func postImportReactionsHandlerV4(req: Request) async throws -> HTTPStatus {
//        guard let password = req.parameters.get("password") else {
//            throw Abort(.internalServerError)
//        }
//        guard password == ReleaseConfigs.Passwords.assetOperationPassword else {
//            throw Abort(.forbidden)
//        }
//
//        let authors = try req.content.decode([Author].self)
//        for i in authors.indices {
//            authors[i].isHidden = false
//        }
//        try await req.db.transaction { transaction in
//            try await authors.create(on: transaction)
//        }
        return .ok
    }

    func postCreateReactionHandlerV4(req: Request) async throws -> HTTPStatus {
        guard let password = req.parameters.get("password") else {
            throw Abort(.internalServerError)
        }
        guard password == ReleaseConfigs.Passwords.assetOperationPassword else {
            throw Abort(.forbidden)
        }

        let content = try req.content.decode(Reaction.self)
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

    func putUpdateReactionHandlerV4(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let password = req.parameters.get("password") else {
            throw Abort(.badRequest)
        }
        guard password == ReleaseConfigs.Passwords.assetOperationPassword else {
            throw Abort(.forbidden)
        }

        let author = try req.content.decode(Author.self)

        return Author.find(author.id, on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { existingAuthor in
                existingAuthor.name = author.name
                existingAuthor.photo = author.photo
                existingAuthor.description = author.description
                existingAuthor.externalLinks = author.externalLinks

                let updateEvent = UpdateEvent(
                    contentId: author.id!.uuidString,
                    dateTime: Date().iso8601withFractionalSeconds,
                    mediaType: .author,
                    eventType: .metadataUpdated,
                    visible: true
                )

                return existingAuthor.save(on: req.db)
                    .and(updateEvent.save(on: req.db))
                    .transform(to: .ok)
            }
    }

    func getReactionHandlerV4(req: Request) throws -> EventLoopFuture<Author> {
        guard let authorId = req.parameters.get("id", as: String.self) else {
            throw Abort(.badRequest)
        }
        print(authorId)
        guard let authorIdAsUUID = UUID(uuidString: authorId) else {
            throw Abort(.internalServerError)
        }

        return Author.query(on: req.db)
            .filter(\.$id == authorIdAsUUID)
            .first()
            .unwrap(or: Abort(.notFound))
            .flatMap { author in
                return req.eventLoop.makeSucceededFuture(author)
            }
    }

    func getAllReactionsHandlerV4(req: Request) throws -> EventLoopFuture<[Author]> {
        Author.query(on: req.db)
            .filter(\.$isHidden == false)
            .all()
    }

    func deleteReactionHandlerV4(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let password = req.parameters.get("password") else {
            throw Abort(.internalServerError)
        }
        guard password == ReleaseConfigs.Passwords.assetOperationPassword else {
            throw Abort(.forbidden)
        }

        guard let authorId = req.parameters.get("id", as: String.self) else {
            throw Abort(.badRequest)
        }
        print(authorId)
        guard let authorIdAsUUID = UUID(uuidString: authorId) else {
            throw Abort(.internalServerError)
        }
        return Author.query(on: req.db)
            .filter(\.$id == authorIdAsUUID)
            .first()
            .unwrap(or: Abort(.notFound))
            .flatMap { content in
                content.isHidden = true
                return content.save(on: req.db).flatMap {
                    let updateEvent = UpdateEvent(contentId: authorId,
                                                  dateTime: Date().iso8601withFractionalSeconds,
                                                  mediaType: .author,
                                                  eventType: .deleted,
                                                  visible: true)
                    return updateEvent.save(on: req.db).transform(to: .ok)
                }
            }
    }

    // MARK: - Reaction Detail

    func postAddSoundsToReactionHandlerV4(req: Request) async throws -> HTTPStatus {
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
}
