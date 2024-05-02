//
//  Reaction.swift
//  medo-delirio-api
//
//  Created by Rafael Claycon Schmitt on 28/10/22.
//

import Fluent
import Vapor

final class Reaction: Model, Content {

    static let schema = "Reaction"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "title")
    var title: String

    @Field(key: "position")
    var position: Int

    @Field(key: "image")
    var image: String

    @Field(key: "blackOverlay")
    var blackOverlay: Int

    @Field(key: "titleSize")
    var titleSize: Int

    @Field(key: "lastUpdate")
    var lastUpdate: String

    init() { }
    
    init(
        id: UUID? = nil,
        title: String,
        position: Int,
        image: String,
        blackOverlay: Int,
        titleSize: Int,
        lastUpdate: String
    ) {
        self.id = id
        self.title = title
        self.position = position
        self.image = image
        self.blackOverlay = blackOverlay
        self.titleSize = titleSize
        self.lastUpdate = lastUpdate
    }
}