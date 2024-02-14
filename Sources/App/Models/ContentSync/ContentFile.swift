//
//  ContentFile.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 02/05/23.
//

import Fluent
import Vapor

final class ContentFile: Model, Content {
    
    static let schema = "ContentFile"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "fileId")
    var fileId: String
    
    @Field(key: "hash")
    var hash: String
    
    init() { }
    
    init(
        fileId: String,
        hash: String
    ) {
        self.id = UUID()
        self.fileId = fileId
        self.hash = hash
    }
}
