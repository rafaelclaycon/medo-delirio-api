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

    func getReactionHandlerV4(req: Request) async throws -> Reaction {
        guard
            let rawId = req.parameters.get("reactionId", as: String.self),
            let reactionId = UUID(uuidString: rawId)
        else {
            throw Abort(.badRequest)
        }
        guard let reaction = try await Reaction.query(on: req.db)
            .filter(\.$id == reactionId)
            .first()
        else {
            throw Abort(.notFound)
        }
        return reaction
    }

    func getReactionSoundsHandlerV4(req: Request) async throws -> [ReactionSound] {
        guard let reactionId = req.parameters.get("reactionId", as: String.self) else {
            throw Abort(.badRequest)
        }
        return try await ReactionSound.query(on: req.db)
            .filter(\.$reactionId == reactionId)
            .all()
    }

    func getAllReactionsHandlerV4(req: Request) async throws -> [Reaction] {
        try await Reaction.query(on: req.db)
            .all()
    }

    func getReactionsForSoundHandler(req: Request) async throws -> [Reaction] {
        guard let soundId = req.parameters.get("soundId", as: String.self) else {
            throw Abort(.badRequest)
        }
        let reactions = try await ReactionSound.query(on: req.db)
            .filter(\.$soundId == soundId)
            .all()
        let reactionIds = reactions.compactMap { UUID(uuidString: $0.reactionId) }

        return try await Reaction.query(on: req.db)
            .filter(\.$id ~~ reactionIds)
            .all()
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

    func putUpdateReactionHandlerV4(req: Request) async throws -> HTTPStatus {
        guard let password = req.parameters.get("password") else {
            throw Abort(.badRequest)
        }
        guard password == ReleaseConfigs.Passwords.reactionsPassword else {
            throw Abort(.forbidden)
        }

        let reaction = try req.content.decode(Reaction.self)

        guard let existingReaction = try await Reaction.find(reaction.id, on: req.db) else {
            throw Abort(.notFound)
        }
        existingReaction.title = reaction.title
        existingReaction.position = reaction.position
        existingReaction.image = reaction.image
        existingReaction.lastUpdate = reaction.lastUpdate
        existingReaction.attributionText = reaction.attributionText
        existingReaction.attributionURL = reaction.attributionURL

        try await existingReaction.save(on: req.db)
        return .ok
    }
}


// MARK: - DELETE

extension ReactionsController {

    func deleteAllReactionsHandlerV4(req: Request) async throws -> HTTPStatus {
        guard let password = req.parameters.get("password") else {
            throw Abort(.internalServerError)
        }
        guard password == ReleaseConfigs.Passwords.reactionsPassword else {
            throw Abort(.forbidden)
        }
        do {
            try await Reaction.query(on: req.db).delete()
        } catch {
            req.logger.error("Failed to delete reactions: \(error.localizedDescription)")
            throw Abort(.internalServerError, reason: "Failed to delete Reactions.")
        }
        return .ok
    }

    /// Deletes all sounds for all Reactions.
    func deleteAllReactionSoundsHandlerV4(req: Request) async throws -> HTTPStatus {
        guard let password = req.parameters.get("password") else {
            throw Abort(.internalServerError)
        }
        guard password == ReleaseConfigs.Passwords.reactionsPassword else {
            throw Abort(.forbidden)
        }
        do {
            try await ReactionSound.query(on: req.db).delete()
        } catch {
            req.logger.error("Failed to delete reaction sounds: \(error.localizedDescription)")
            throw Abort(.internalServerError, reason: "Failed to delete Reaction sounds.")
        }
        return .ok
    }

    /// Deletes all sounds for a specific Reaction.
    func deleteReactionSoundsHandlerV4(req: Request) async throws -> HTTPStatus {
        guard let password = req.parameters.get("password") else {
            throw Abort(.internalServerError)
        }
        guard password == ReleaseConfigs.Passwords.reactionsPassword else {
            throw Abort(.forbidden)
        }

        guard let reactionId = req.parameters.get("id", as: String.self) else {
            throw Abort(.badRequest)
        }

        let contents = try await ReactionSound.query(on: req.db)
            .filter(\.$reactionId == reactionId)
            .all()
        for content in contents {
            try await content.delete(on: req.db)
        }
        return .ok
    }

    func deleteReactionHandlerV4(req: Request) async throws -> HTTPStatus {
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
        try await Reaction.query(on: req.db)
            .filter(\.$id == reactionId)
            .delete()
        return .ok
    }
}
