//
//  Content.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 30/04/23.
//

import Fluent
import Vapor

final class MedoContent: Model, Content {

    static let schema = "MedoContent"
    
    @ID(key: .id)
    var id: UUID?

    @Field(key: "title")
    var title: String
    
    @Field(key: "authorId")
    var authorId: String
    
    @Field(key: "description")
    var description: String
    
    @Field(key: "fileId")
    var fileId: String
    
    @Field(key: "creationDate")
    var creationDate: String
    
    @Field(key: "duration")
    var duration: Double
    
    @Field(key: "isOffensive")
    var isOffensive: Bool
    
    @Field(key: "musicGenre")
    var musicGenre: String?
    
    @Field(key: "contentType")
    var contentType: ContentType
    
    @Field(key: "isHidden")
    var isHidden: Bool
    
    init() { }
    
    init(
        sound: Sound
    ) {
        self.id = UUID(uuidString: sound.id)
        self.title = sound.title
        self.authorId = sound.authorId
        self.description = sound.description
        self.fileId = sound.filename
        self.creationDate = sound.dateAdded?.iso8601withFractionalSeconds ?? ""
        self.duration = sound.duration
        self.isOffensive = sound.isOffensive
        self.musicGenre = nil
        self.contentType = .sound
        self.isHidden = false
    }
}
