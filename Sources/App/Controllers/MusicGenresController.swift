//
//  MusicGenresController.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 26/08/23.
//

import Vapor
import Fluent

struct MusicGenresController {

    func postImportMusicGenresHandlerV3(req: Request) async throws -> HTTPStatus {
        guard let password = req.parameters.get("password") else {
            throw Abort(.internalServerError)
        }
        guard password == ReleaseConfigs.Passwords.assetOperationPassword else {
            throw Abort(.forbidden)
        }

        let genres = try req.content.decode([MusicGenre].self)
        for i in genres.indices {
            genres[i].isHidden = false
        }
        try await req.db.transaction { transaction in
            try await genres.create(on: transaction)
        }
        return .ok
    }

    func postCreateMusicHandlerHandlerV3(req: Request) async throws -> HTTPStatus {
        guard let password = req.parameters.get("password") else {
            throw Abort(.internalServerError)
        }
        guard password == ReleaseConfigs.Passwords.assetOperationPassword else {
            throw Abort(.forbidden)
        }

        let content = try req.content.decode(MusicGenre.self)
        content.isHidden = false
        try await req.db.transaction { transaction in
            try await content.save(on: transaction)
        }

        guard let contentId = content.id?.uuidString else {
            throw Abort(.internalServerError)
        }

        let updateEvent = UpdateEvent(contentId: contentId,
                                      dateTime: Date().iso8601withFractionalSeconds,
                                      mediaType: .musicGenre,
                                      eventType: .created,
                                      visible: true)
        try await req.db.transaction { transaction in
            try await updateEvent.save(on: transaction)
        }

        return .ok
    }

    func getMusicGenreHandlerV3(req: Request) throws -> EventLoopFuture<MusicGenre> {
        guard let genreId = req.parameters.get("id", as: String.self) else {
            throw Abort(.badRequest)
        }

        guard let genreIdAsUUID = UUID(uuidString: genreId) else {
            throw Abort(.internalServerError)
        }

        return MusicGenre.query(on: req.db)
            .filter(\.$id == genreIdAsUUID)
            .first()
            .unwrap(or: Abort(.notFound))
            .flatMap { genre in
                return req.eventLoop.makeSucceededFuture(genre)
            }
    }

    func getAllMusicGenresHandlerV3(req: Request) throws -> EventLoopFuture<[MusicGenre]> {
        MusicGenre.query(on: req.db)
            .filter(\.$isHidden == false)
            .all()
    }

    func deleteMusicGenreHandlerV3(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let password = req.parameters.get("password") else {
            throw Abort(.internalServerError)
        }
        guard password == ReleaseConfigs.Passwords.assetOperationPassword else {
            throw Abort(.forbidden)
        }

        guard let genreId = req.parameters.get("id", as: String.self) else {
            throw Abort(.badRequest)
        }

        guard let genreIdAsUUID = UUID(uuidString: genreId) else {
            throw Abort(.internalServerError)
        }
        return MusicGenre.query(on: req.db)
            .filter(\.$id == genreIdAsUUID)
            .first()
            .unwrap(or: Abort(.notFound))
            .flatMap { content in
                content.isHidden = true
                return content.save(on: req.db).flatMap {
                    let updateEvent = UpdateEvent(contentId: genreId,
                                                  dateTime: Date().iso8601withFractionalSeconds,
                                                  mediaType: .musicGenre,
                                                  eventType: .deleted,
                                                  visible: true)
                    return updateEvent.save(on: req.db).transform(to: .ok)
                }
            }
    }
}
