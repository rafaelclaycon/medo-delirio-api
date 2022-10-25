//
//  CreateUserFolderLog.swift
//  medo-delirio-api
//
//  Created by Rafael Claycon Schmitt on 24/10/22.
//

import Fluent

struct CreateUserFolderLog: AsyncMigration {

    func prepare(on database: Database) async throws {
        try await database.schema("UserFolderLog")
            .id()
            .field("installId", .string, .required)
            .field("folderId", .string, .required)
            .field("folderSymbol", .string, .required)
            .field("folderName", .string, .required)
            .field("backgroundColor", .string, .required)
            .field("logDateTime", .string, .required)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("UserFolderLog").delete()
    }

}
