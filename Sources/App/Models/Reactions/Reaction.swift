//
//  Reaction.swift
//  medo-delirio-api
//
//  Created by Rafael Claycon Schmitt on 28/10/22.
//

import Fluent
import Vapor

final class Reaction: Model, Content, Equatable, Hashable {

    static let schema = "Reaction"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "title")
    var title: String

    @Field(key: "position")
    var position: Int

    @Field(key: "image")
    var image: String

    @Field(key: "lastUpdate")
    var lastUpdate: String

    @Field(key: "attributionText")
    var attributionText: String?

    @Field(key: "attributionURL")
    var attributionURL: String?

    init() { }

    init(
        id: UUID? = nil,
        title: String,
        position: Int,
        image: String,
        lastUpdate: String,
        attributionText: String?,
        attributionURL: String?
    ) {
        self.id = id
        self.title = title
        self.position = position
        self.image = image
        self.lastUpdate = lastUpdate
        self.attributionText = attributionText
        self.attributionURL = attributionURL
    }

    static func == (lhs: Reaction, rhs: Reaction) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(title)
    }
}
