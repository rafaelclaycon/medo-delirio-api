//
//  ContentCollection.swift
//  medo-delirio-api
//
//  Created by Rafael Claycon Schmitt on 28/10/22.
//

import Fluent
import Vapor

final class ContentCollection: Model, Content {

    static let schema = "ContentCollection"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "title")
    var title: String
    
    @Field(key: "imageUrl")
    var imageUrl: String
    
    init() { }
    
    init(id: UUID? = nil,
         title: String,
         imageUrl: String) {
        self.id = id
        self.title = title
        self.imageUrl = imageUrl
    }

}
