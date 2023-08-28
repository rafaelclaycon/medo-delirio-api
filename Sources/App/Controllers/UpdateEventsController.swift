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
            return UpdateEvent.query(on: req.db).filter("visible", .equal, true).all()
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
                and visible == true
                order by dateTime
            """

            return sqlite.query(query).flatMapEach(on: req.eventLoop) { row in
                req.eventLoop.makeSucceededFuture(
                    UpdateEvent(id: row.column("id")?.string ?? "",
                                contentId: row.column("contentId")?.string ?? "",
                                dateTime: row.column("dateTime")?.string ?? "",
                                mediaType: row.column("mediaType")?.integer ?? 0,
                                eventType: row.column("eventType")?.integer ?? 0,
                                visible: row.column("visible")?.bool ?? false)
                )
            }
        } else {
            return req.eventLoop.makeSucceededFuture([])
        }
    }

    func getUpdateEventsForDisplayHandlerV3(req: Request) throws -> EventLoopFuture<[UpdateEvent]> {
        guard let password = req.parameters.get("password") else {
            throw Abort(.internalServerError)
        }
        guard password == ReleaseConfigs.Passwords.assetOperationPassword else {
            throw Abort(.forbidden)
        }
        // TODO: - Finish this
        if let sqlite = req.db as? SQLiteDatabase {
            let query = """
                select *
                from UpdateEvent
                left join MedoContent
                where visible == true
                order by dateTime desc
            """

            return sqlite.query(query).flatMapEach(on: req.eventLoop) { row in
                req.eventLoop.makeSucceededFuture(
                    UpdateEvent(id: row.column("id")?.string ?? "",
                                contentId: row.column("contentId")?.string ?? "",
                                dateTime: row.column("dateTime")?.string ?? "",
                                mediaType: row.column("mediaType")?.integer ?? 0,
                                eventType: row.column("eventType")?.integer ?? 0,
                                visible: row.column("visible")?.bool ?? false)
                )
            }
        } else {
            return req.eventLoop.makeSucceededFuture([])
        }
    }

    func putChangeUpdateVisibilityHandlerV3(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let uuidString = req.parameters.get("updateId"), !uuidString.isEmpty else {
            throw Abort(.badRequest)
        }
        let regex = try NSRegularExpression(pattern: UUID.uuidRegex, options: [])
        let matches = regex.matches(in: uuidString, options: [], range: NSRange(location: 0, length: uuidString.utf16.count))
        guard matches.count > 0 else {
            throw Abort(.badRequest, reason: "Invalid UUID format")
        }

        guard let password = req.parameters.get("password") else {
            throw Abort(.badRequest)
        }
        guard password == ReleaseConfigs.Passwords.assetOperationPassword else {
            throw Abort(.forbidden)
        }

        guard let newValueAsString = req.parameters.get("newValue"), newValueAsString == "0" || newValueAsString == "1" else {
            throw Abort(.badRequest)
        }
        let visibleValue = newValueAsString == "1" ? true : false

        return UpdateEvent.find(UUID(uuidString: uuidString), on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { updateEvent in
                if visibleValue {
                    updateEvent.dateTime = Date.now.iso8601withFractionalSeconds
                }
                updateEvent.visible = visibleValue
                return updateEvent.save(on: req.db)
            }
            .transform(to: .ok)
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
                    eventType: .metadataUpdated,
                    visible: true
                )
                
                return existingMedoContent.save(on: req.db)
                    .and(updateEvent.save(on: req.db))
                    .transform(to: .ok)
            }
    }
    
    func postUpdateContentFileHandlerV3(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let mediaTypeString = req.parameters.get("type", as: String.self) else {
            throw Abort(.badRequest)
        }
        guard let contentId = req.parameters.get("id", as: String.self) else {
            throw Abort(.badRequest)
        }
        guard let mediaType = MediaType.from(string: mediaTypeString) else {
            throw Abort(.badRequest)
        }
        let updateEvent = UpdateEvent(
            contentId: contentId,
            dateTime: Date().iso8601withFractionalSeconds,
            mediaType: mediaType,
            eventType: .fileUpdated,
            visible: true
        )
        return updateEvent.save(on: req.db).transform(to: .ok)
    }
}
