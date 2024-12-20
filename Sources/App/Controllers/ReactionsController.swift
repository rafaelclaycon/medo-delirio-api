//
//  ReactionsController.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 01/05/24.
//

import Vapor
import Fluent

// MARK: - GET

struct ReactionsController {

    func getReactionHandlerV4(req: Request) throws -> EventLoopFuture<Reaction> {
        guard
            let rawId = req.parameters.get("reactionId", as: String.self),
            let reactionId = UUID(uuidString: rawId)
        else {
            throw Abort(.badRequest)
        }
        return Reaction.query(on: req.db)
            .filter(\.$id == reactionId)
            .first()
            .unwrap(or: Abort(.notFound))
    }

    func getReactionSoundsHandlerV4(req: Request) throws -> EventLoopFuture<[ReactionSound]> {
        guard let reactionId = req.parameters.get("reactionId", as: String.self) else {
            throw Abort(.badRequest)
        }
        return ReactionSound.query(on: req.db)
            .filter(\.$reactionId == reactionId)
            .all()
    }

    func getAllReactionsHandlerV4(req: Request) throws -> EventLoopFuture<[Reaction]> {
        Reaction.query(on: req.db)
            .all()
    }

    func getReactionsForSoundHandler(req: Request) throws -> EventLoopFuture<[Reaction]> {
        guard let soundId = req.parameters.get("soundId", as: String.self) else {
            throw Abort(.badRequest)
        }
        return ReactionSound.query(on: req.db)
            .filter(\.$soundId == soundId)
            .all()
            .flatMap { reactions in
                let reactionIds = reactions.compactMap { UUID(uuidString: $0.reactionId) }

                return Reaction.query(on: req.db)
                    .filter(\.$id ~~ reactionIds)
                    .all()
            }
    }
}

// MARK: - POST

extension ReactionsController {

    func postCreateReactionHandlerV4(req: Request) async throws -> HTTPStatus {
        guard let password = req.parameters.get("password") else {
            throw Abort(.internalServerError)
        }
        guard password == ReleaseConfigs.Passwords.reactionsPassword else {
            throw Abort(.forbidden)
        }

        let content = try req.content.decode(Reaction.self)

        try await req.db.transaction { transaction in
            try await content.save(on: transaction)
        }

        return .ok
    }

    func postAddSoundsToReactionHandlerV4(req: Request) async throws -> HTTPStatus {
        guard let password = req.parameters.get("password") else {
            throw Abort(.internalServerError)
        }
        guard password == ReleaseConfigs.Passwords.reactionsPassword else {
            throw Abort(.forbidden)
        }

        let sounds = try req.content.decode([ReactionSound].self)

        try await req.db.transaction { transaction in
            for sound in sounds {
                try await sound.save(on: transaction)
            }
        }
        return .ok
    }
}


// MARK: - PUT

extension ReactionsController {

    func putUpdateReactionHandlerV4(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let password = req.parameters.get("password") else {
            throw Abort(.badRequest)
        }
        guard password == ReleaseConfigs.Passwords.reactionsPassword else {
            throw Abort(.forbidden)
        }

        let reaction = try req.content.decode(Reaction.self)

        return Reaction.find(reaction.id, on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { existingReaction in
                existingReaction.title = reaction.title
                existingReaction.position = reaction.position
                existingReaction.image = reaction.image
                existingReaction.lastUpdate = reaction.lastUpdate
                existingReaction.attributionText = reaction.attributionText
                existingReaction.attributionURL = reaction.attributionURL

                return existingReaction.save(on: req.db)
                    .transform(to: .ok)
            }
    }
}


// MARK: - DELETE

extension ReactionsController {

    func deleteAllReactionsHandlerV4(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let password = req.parameters.get("password") else {
            throw Abort(.internalServerError)
        }
        guard password == ReleaseConfigs.Passwords.reactionsPassword else {
            throw Abort(.forbidden)
        }
        return Reaction.query(on: req.db).delete().flatMap {
            return req.eventLoop.makeSucceededFuture(.ok)
        }.flatMapError { error in
            req.logger.error("Failed to delete reactions: \(error.localizedDescription)")
            return req.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "Failed to delete Reactions."))
        }
    }

    /// Deletes all sounds for all Reactions.
    func deleteAllReactionSoundsHandlerV4(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let password = req.parameters.get("password") else {
            throw Abort(.internalServerError)
        }
        guard password == ReleaseConfigs.Passwords.reactionsPassword else {
            throw Abort(.forbidden)
        }
        return ReactionSound.query(on: req.db).delete().flatMap {
            return req.eventLoop.makeSucceededFuture(.ok)
        }.flatMapError { error in
            req.logger.error("Failed to delete reaction sounds: \(error.localizedDescription)")
            return req.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "Failed to delete Reaction sounds."))
        }
    }

    /// Deletes all sounds for a specific Reaction.
    func deleteReactionSoundsHandlerV4(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let password = req.parameters.get("password") else {
            throw Abort(.internalServerError)
        }
        guard password == ReleaseConfigs.Passwords.reactionsPassword else {
            throw Abort(.forbidden)
        }

        guard let reactionId = req.parameters.get("id", as: String.self) else {
            throw Abort(.badRequest)
        }

        return ReactionSound.query(on: req.db)
            .filter(\.$reactionId == reactionId)
            .all()
            .flatMap { contents in
                let deleteFutures = contents.map { content in
                    content.delete(on: req.db)
                }
                return EventLoopFuture.andAllSucceed(deleteFutures, on: req.eventLoop).transform(to: .ok)
            }
    }

    func deleteReactionHandlerV4(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let password = req.parameters.get("password") else {
            throw Abort(.internalServerError)
        }
        guard password == ReleaseConfigs.Passwords.reactionsPassword else {
            throw Abort(.forbidden)
        }
        guard
            let reactionIdString = req.parameters.get("id", as: String.self),
            let reactionId = UUID(uuidString: reactionIdString)
        else {
            throw Abort(.badRequest)
        }
        return Reaction.query(on: req.db)
            .filter(\.$id == reactionId)
            .delete()
            .transform(to: .ok)
    }
}
