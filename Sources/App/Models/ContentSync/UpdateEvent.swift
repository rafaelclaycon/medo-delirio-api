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
    
    @Field(key: "isNewContent")
    var isNewContent: Bool
    
    @Field(key: "isMetadataChange")
    var isMetadataChange: Bool
    
    @Field(key: "isFileChange")
    var isFileChange: Bool
    
    init() { }
}
