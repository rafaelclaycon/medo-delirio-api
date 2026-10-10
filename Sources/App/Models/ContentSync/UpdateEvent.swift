//
//  UpdateEvent.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 28/04/23.
//

import Fluent
import Vapor

final class UpdateEvent: Model, Content {

    static let schema = "UpdateEvent"
    
    @ID(key: .id)
    var id: UUID?

    @Field(key: "contentId")
    var contentId: String
    
    @Field(key: "dateTime")
    var dateTime: String
    
    @Field(key: "mediaType")
    var mediaType: MediaType
    
    @Field(key: "eventType")
    var eventType: EventType

    @Field(key: "visible")
    var visible: Bool
    
    init() { }
    
    init(
        id: UUID? = UUID(),
        contentId: String,
        dateTime: String,
        mediaType: MediaType,
        eventType: EventType,
        visible: Bool
    ) {
        self.id = id
        self.contentId = contentId
        self.dateTime = dateTime
        self.mediaType = mediaType
        self.eventType = eventType
        self.visible = visible
    }
    
    init(
        id: String,
        contentId: String,
        dateTime: String,
        mediaType: Int,
        eventType: Int,
        visible: Bool
    ) {
        self.id = UUID(uuidString: id)
        self.contentId = contentId
        self.dateTime = dateTime
        self.mediaType = MediaType(rawValue: mediaType) ?? .sound
        self.eventType = EventType(rawValue: eventType) ?? .created
        self.visible = visible
    }
}

extension UpdateEvent {

    /// Hides every event of a piece of content, so clients that haven't synced it yet
    /// skip straight to its deletion instead of downloading it first. A bulk query
    /// update, so it doesn't trigger `UpdateEventPushMiddleware`.
    static func hideAll(forContentId contentId: String, on db: Database) async throws {
        try await UpdateEvent.query(on: db)
            .filter(\.$contentId == contentId)
            .set(\.$visible, to: false)
            .update()
    }
}
