//
//  UserFolderLog.swift
//  medo-delirio-api
//
//  Created by Rafael Claycon Schmitt on 24/10/22.
//

import Fluent
import Vapor

final class UserFolderLog: Model, Content {

    static let schema = "UserFolderLog"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "installId")
    var installId: String
    
    @Field(key: "folderId")
    var folderId: String
    
    @Field(key: "folderSymbol")
    var folderSymbol: String
    
    @Field(key: "folderName")
    var folderName: String
    
    @Field(key: "backgroundColor")
    var backgroundColor: String
    
    @Field(key: "logDateTime")
    var logDateTime: String?
    
    init() { }
    
    init(
        id: UUID? = nil,
        installId: String,
        folderId: String,
        folderSymbol: String,
        folderName: String,
        backgroundColor: String,
        logDateTime: String
    ) {
        self.id = id
        self.installId = installId
        self.folderId = folderId
        self.folderSymbol = folderSymbol
        self.folderName = folderName
        self.backgroundColor = backgroundColor
        self.logDateTime = logDateTime
    }
}
