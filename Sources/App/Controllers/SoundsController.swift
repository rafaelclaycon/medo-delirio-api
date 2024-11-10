//
//  SoundsController.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 22/05/23.
//

import Vapor
import Fluent

struct SoundsController {

    func postImportSoundsHandlerV3(req: Request) async throws -> HTTPStatus {
        guard let password = req.parameters.get("password") else {
            throw Abort(.internalServerError)
        }
        guard password == ReleaseConfigs.Passwords.assetOperationPassword else {
            throw Abort(.forbidden)
        }

        let sounds = try req.content.decode([Sound].self)
        
        try await req.db.transaction { transaction in
            for sound in sounds {
                let medoContent = MedoContent(sound: sound)
                try await medoContent.create(on: transaction)
            }
        }
        
        return .ok
    }
    
    func postCreateSoundHandlerV3(req: Request) async throws -> Response {
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
            mediaType: .sound,
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
    
    func getSoundHandlerV3(req: Request) throws -> EventLoopFuture<Sound> {
        guard let soundId = req.parameters.get("id", as: String.self) else {
            throw Abort(.badRequest)
        }
        print(soundId)
        guard let soundIdAsUUID = UUID(uuidString: soundId) else {
            throw Abort(.internalServerError)
        }
        
        return MedoContent.query(on: req.db)
            .filter(\.$id == soundIdAsUUID)
            .first()
            .unwrap(or: Abort(.notFound))
            .flatMap { content in
                let sound = Sound(content: content)
                return req.eventLoop.makeSucceededFuture(sound)
            }
    }
    
    func getAllSoundsHandlerV3(req: Request) throws -> EventLoopFuture<[Sound]> {
        let query = MedoContent.query(on: req.db)
            .filter(\.$contentType == .sound)
            .filter(\.$isHidden == false)
        
        return query.all().flatMapThrowing { medoContentList in
            medoContentList.map { content in
                return Sound(content: content)
            }
        }
    }
    
    func deleteSoundHandlerV3(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let password = req.parameters.get("password") else {
            throw Abort(.internalServerError)
        }
        guard password == ReleaseConfigs.Passwords.assetOperationPassword else {
            throw Abort(.forbidden)
        }

        guard let soundId = req.parameters.get("id", as: String.self) else {
            throw Abort(.badRequest)
        }
        print(soundId)
        guard let soundIdAsUUID = UUID(uuidString: soundId) else {
            throw Abort(.internalServerError)
        }
        return MedoContent.query(on: req.db)
            .filter(\.$id == soundIdAsUUID)
            .first()
            .unwrap(or: Abort(.notFound))
            .flatMap { content in
                content.isHidden = true
                return content.save(on: req.db).flatMap {
                    let updateEvent = UpdateEvent(contentId: soundId,
                                                  dateTime: Date().iso8601withFractionalSeconds,
                                                  mediaType: .sound,
                                                  eventType: .deleted,
                                                  visible: true)
                    return updateEvent.save(on: req.db).transform(to: .ok)
                }
            }
    }
}
