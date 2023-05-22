//
//  UpdateEventsController.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 22/05/23.
//

import Vapor
import SQLiteNIO

struct UpdateEventsController {
    
    func getUpdateEventsHandlerV3(req: Request) throws -> EventLoopFuture<[UpdateEvent]> {
        guard let date = req.parameters.get("date") else {
            throw Abort(.badRequest)
        }
        
        if date == "all" {
            return UpdateEvent.query(on: req.db).all()
        }
        
        guard date.isUTCDateString() else {
            throw Abort(.badRequest)
        }
        
        print(date)
        
        if let sqlite = req.db as? SQLiteDatabase {
            let query = """
                select *
                from UpdateEvent
                where dateTime > '\(date)'
                order by dateTime
            """

            return sqlite.query(query).flatMapEach(on: req.eventLoop) { row in
                req.eventLoop.makeSucceededFuture(
                    UpdateEvent(id: row.column("id")?.string ?? "",
                                contentId: row.column("contentId")?.string ?? "",
                                dateTime: row.column("dateTime")?.string ?? "",
                                mediaType: row.column("mediaType")?.integer ?? 0,
                                eventType: row.column("eventType")?.integer ?? 0)
                )
            }
        } else {
            return req.eventLoop.makeSucceededFuture([])
        }
    }
    
    func putUpdateContentHandlerV3(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let medoContent = try req.content.decode(MedoContent.self)

        return MedoContent.find(medoContent.id, on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { existingMedoContent in
                existingMedoContent.title = medoContent.title
                existingMedoContent.authorId = medoContent.authorId
                existingMedoContent.description = medoContent.description
                //existingMedoContent.fileId = medoContent.fileId
                existingMedoContent.duration = medoContent.duration
                existingMedoContent.isOffensive = medoContent.isOffensive
                existingMedoContent.musicGenre = medoContent.musicGenre
                existingMedoContent.contentType = medoContent.contentType
                
                let updateEvent = UpdateEvent(
                    contentId: medoContent.id!.uuidString,
                    dateTime: Date().iso8601withFractionalSeconds,
                    mediaType: medoContent.contentType == .sound ? .sound : .song,
                    eventType: .metadataUpdated
                )
                
                return existingMedoContent.save(on: req.db)
                    .and(updateEvent.save(on: req.db))
                    .transform(to: .ok)
            }
    }
}
