//
//  Author.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 02/05/23.
//

import Fluent
import Vapor

final class Author: Model, Content {
    
    static let schema = "Author"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "photo")
    var photo: String?
    
    @Field(key: "description")
    var description: String?
    
    @Field(key: "isHidden")
    var isHidden: Bool?
    
    init() { }
}
