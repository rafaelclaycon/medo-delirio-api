//
//  CollectionSound.swift
//  medo-delirio-api
//
//  Created by Rafael Claycon Schmitt on 28/10/22.
//

import Fluent
import Vapor

final class CollectionSound: Model, Content {

    static let schema = "CollectionSound"
    
    @ID(key: .id)
    var id: UUID?

    @Field(key: "collectionId")
    var collectionId: String
    
    @Field(key: "soundId")
    var soundId: String
    
    @Field(key: "dateAdded")
    var dateAdded: String

    init() { }

    init(id: UUID? = nil,
         collectionId: String,
         soundId: String,
         dateAdded: String) {
        self.id = id
        self.collectionId = collectionId
        self.soundId = soundId
        self.dateAdded = dateAdded
    }

}
