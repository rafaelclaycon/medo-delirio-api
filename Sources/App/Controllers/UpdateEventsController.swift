//
//  UpdateEventsController.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 22/05/23.
//

import Vapor
import SQLiteNIO

struct UpdateEventsController {
    
    func getUpdateEventsHandlerV3(req: Request) async throws -> [UpdateEvent] {
        guard let date = req.parameters.get("date") else {
            throw Abort(.badRequest)
        }
        
        if date == "all" {
            return try await UpdateEvent.query(on: req.db).filter("visible", .equal, true).all()
        }
        
        guard date.isUTCDateString() else {
            throw Abort(.badRequest)
        }
        
        guard let sqlite = req.db as? SQLiteDatabase else {
            return []
        }
        let query = """
            select *
            from UpdateEvent
            where dateTime > ?
            and visible == true
            order by dateTime
        """
        return try await sqlite.query(query, [.text(date)]).map(Self.updateEvent(from:))
    }

    func getUpdateEventsForDisplayHandlerV3(req: Request) async throws -> [UpdateEvent] {
        guard let password = req.parameters.get("password") else {
            throw Abort(.internalServerError)
        }
        guard password == ReleaseConfigs.Passwords.assetOperationPassword else {
            throw Abort(.forbidden)
        }
        // TODO: - Finish this
        guard let sqlite = req.db as? SQLiteDatabase else {
            return []
        }
        let query = """
            select *
            from UpdateEvent
            left join MedoContent
            where visible == true
            order by dateTime desc
        """
        return try await sqlite.query(query).map(Self.updateEvent(from:))
    }

    private static func updateEvent(from row: SQLiteRow) -> UpdateEvent {
        UpdateEvent(id: row.column("id")?.string ?? "",
                    contentId: row.column("contentId")?.string ?? "",
                    dateTime: row.column("dateTime")?.string ?? "",
                    mediaType: row.column("mediaType")?.integer ?? 0,
                    eventType: row.column("eventType")?.integer ?? 0,
                    visible: row.column("visible")?.bool ?? false)
    }

    func putChangeUpdateVisibilityHandlerV3(req: Request) async throws -> HTTPStatus {
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

        guard let updateEvent = try await UpdateEvent.find(UUID(uuidString: uuidString), on: req.db) else {
            throw Abort(.notFound)
        }
        if visibleValue {
            updateEvent.dateTime = Date().iso8601withFractionalSeconds
        }
        updateEvent.visible = visibleValue
        try await updateEvent.save(on: req.db)
        return .ok
    }
    
    func putUpdateContentHandlerV3(req: Request) async throws -> HTTPStatus {
        guard let password = req.parameters.get("password") else {
            throw Abort(.badRequest)
        }
        guard password == ReleaseConfigs.Passwords.assetOperationPassword else {
            throw Abort(.forbidden)
        }

        let medoContent = try req.content.decode(MedoContent.self)

        guard let existingMedoContent = try await MedoContent.find(medoContent.id, on: req.db) else {
            throw Abort(.notFound)
        }
        existingMedoContent.title = medoContent.title
        existingMedoContent.authorId = medoContent.authorId
        existingMedoContent.description = medoContent.description
        //existingMedoContent.fileId = medoContent.fileId
        existingMedoContent.duration = medoContent.duration
        existingMedoContent.isOffensive = medoContent.isOffensive
        existingMedoContent.musicGenre = medoContent.musicGenre
        existingMedoContent.contentType = medoContent.contentType
        
        let updateEvent = UpdateEvent(
            contentId: try existingMedoContent.requireID().uuidString,
            dateTime: Date().iso8601withFractionalSeconds,
            mediaType: medoContent.contentType == .sound ? .sound : .song,
            eventType: .metadataUpdated,
            visible: true
        )
        
        try await existingMedoContent.save(on: req.db)
        try await updateEvent.save(on: req.db)
        return .ok
    }
    
    func postUpdateContentFileHandlerV3(req: Request) async throws -> HTTPStatus {
        guard let password = req.parameters.get("password") else {
            throw Abort(.badRequest)
        }
        guard password == ReleaseConfigs.Passwords.assetOperationPassword else {
            throw Abort(.forbidden)
        }

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
        try await updateEvent.save(on: req.db)
        return .ok
    }
}
