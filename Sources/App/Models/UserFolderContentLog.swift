//
//  UserFolderContentLog.swift
//  medo-delirio-api
//
//  Created by Rafael Claycon Schmitt on 24/10/22.
//

import Fluent
import Vapor

final class UserFolderContentLog: Model, Content {

    static let schema = "UserFolderContentLog"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "userFolderLogId")
    var userFolderLogId: String
    
    @Field(key: "contentId")
    var contentId: String
    
    init() { }
    
    init(id: UUID? = nil,
         userFolderLogId: String,
         contentId: String) {
        self.id = id
        self.userFolderLogId = userFolderLogId
        self.contentId = contentId
    }

}
