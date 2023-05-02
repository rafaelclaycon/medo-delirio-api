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
    
    init() { }
}
