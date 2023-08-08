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
