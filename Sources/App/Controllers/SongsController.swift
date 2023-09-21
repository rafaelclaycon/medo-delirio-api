//
//  SongsController.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 24/05/23.
//

import Vapor
import Fluent

struct SongsController {
    
    func postImportSongsHandlerV3(req: Request) async throws -> HTTPStatus {
        guard let password = req.parameters.get("password") else {
            throw Abort(.internalServerError)
        }
        guard password == ReleaseConfigs.Passwords.assetOperationPassword else {
            throw Abort(.forbidden)
        }

        let songs = try req.content.decode([Song].self)
        try await req.db.transaction { transaction in
            for song in songs {
                let medoContent = MedoContent(song: song)
                try await medoContent.create(on: transaction)
            }
        }
        return .ok
    }

    func postCreateSongHandlerV3(req: Request) async throws -> Response {
        guard let password = req.parameters.get("password") else {
            throw Abort(.internalServerError)
        }
        guard password == ReleaseConfigs.Passwords.assetOperationPassword else {
            throw Abort(.forbidden)
        }

        let content = try req.content.decode(MedoContent.self)
        try await req.db.transaction { transaction in
            try await content.save(on: transaction)
        }

        let contentFile = ContentFile(fileId: content.fileId, hash: "")
        try await req.db.transaction { transaction in
            try await contentFile.save(on: transaction)
        }

        guard let contentId = content.id?.uuidString else {
            throw Abort(.internalServerError)
        }

        let eventWrapper = EventIdWrapper()

        let updateEvent = UpdateEvent(
            contentId: contentId,
            dateTime: Date().iso8601withFractionalSeconds,
            mediaType: .song,
            eventType: .created,
            visible: false
        )

        try await req.db.transaction { transaction in
            try await updateEvent.save(on: transaction)
            if let id = updateEvent.id?.uuidString {
                await eventWrapper.setUpdateEventId(id)
            }
        }

        let response = await CreateContentResponse(contentId: content.id?.uuidString ?? "", eventId: eventWrapper.updateEventId)

        let data = try JSONEncoder().encode(response)
        return Response(status: .created, body: Response.Body(data: data))
    }

    func getAllSongsHandlerV3(req: Request) throws -> EventLoopFuture<[Song]> {
        let query = MedoContent.query(on: req.db)
            .filter(\.$contentType == .song)
            .filter(\.$isHidden == false)
        
        return query.all().flatMapThrowing { medoContentList in
            medoContentList.map { content in
                return Song(content: content)
            }
        }
    }

    func getSongHandlerV3(req: Request) throws -> EventLoopFuture<Song> {
        guard let songId = req.parameters.get("id", as: String.self) else {
            throw Abort(.badRequest)
        }

        guard let songIdAsUUID = UUID(uuidString: songId) else {
            throw Abort(.internalServerError)
        }

        return MedoContent.query(on: req.db)
            .filter(\.$id == songIdAsUUID)
            .first()
            .unwrap(or: Abort(.notFound))
            .flatMap { content in
                let song = Song(content: content)
                return req.eventLoop.makeSucceededFuture(song)
            }
    }

    func deleteSongHandlerV3(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let password = req.parameters.get("password") else {
            throw Abort(.internalServerError)
        }
        guard password == ReleaseConfigs.Passwords.assetOperationPassword else {
            throw Abort(.forbidden)
        }

        guard let songId = req.parameters.get("id", as: String.self) else {
            throw Abort(.badRequest)
        }

        guard let songIdAsUUID = UUID(uuidString: songId) else {
            throw Abort(.internalServerError)
        }
        return MedoContent.query(on: req.db)
            .filter(\.$id == songIdAsUUID)
            .first()
            .unwrap(or: Abort(.notFound))
            .flatMap { content in
                content.isHidden = true
                return content.save(on: req.db).flatMap {
                    let updateEvent = UpdateEvent(contentId: songId,
                                                  dateTime: Date().iso8601withFractionalSeconds,
                                                  mediaType: .song,
                                                  eventType: .deleted,
                                                  visible: true)
                    return updateEvent.save(on: req.db).transform(to: .ok)
                }
            }
    }
}
