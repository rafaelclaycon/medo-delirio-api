//
//  ReactionSound.swift
//  medo-delirio-api
//
//  Created by Rafael Claycon Schmitt on 28/10/22.
//

import Fluent
import Vapor

final class ReactionSound: Model, Content {

    static let schema = "ReactionSound"
    
    @ID(key: .id)
    var id: UUID?

    @Field(key: "reactionId")
    var reactionId: String
    
    @Field(key: "soundId")
    var soundId: String
    
    @Field(key: "dateAdded")
    var dateAdded: String

    @Field(key: "position")
    var position: Int

    init() { }

    init(
        id: UUID? = nil,
        reactionId: String,
        soundId: String,
        dateAdded: String,
        position: Int
    ) {
        self.id = id
        self.reactionId = reactionId
        self.soundId = soundId
        self.dateAdded = dateAdded
        self.position = position
    }
}
