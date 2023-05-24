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
        
        let updateEvent = UpdateEvent(contentId: contentId,
                                      dateTime: Date.now.iso8601withFractionalSeconds,
                                      mediaType: .sound,
                                      eventType: .created)
        try await req.db.transaction { transaction in
            try await updateEvent.save(on: transaction)
        }
        
        return Response(status: .created, body: Response.Body(stringLiteral: content.id?.uuidString ?? ""))
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
                                                  dateTime: Date.now.iso8601withFractionalSeconds,
                                                  mediaType: .sound,
                                                  eventType: .deleted)
                    return updateEvent.save(on: req.db).transform(to: .ok)
                }
            }
    }
}
