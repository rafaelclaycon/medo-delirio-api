//
//  CreateUserFolderContentLog.swift
//  medo-delirio-api
//
//  Created by Rafael Claycon Schmitt on 24/10/22.
//

import Fluent

struct CreateUserFolderContentLog: AsyncMigration {

    func prepare(on database: Database) async throws {
        try await database.schema("UserFolderContentLog")
            .id()
            .field("userFolderLogId", .string, .required)
            .field("contentId", .string, .required)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("UserFolderContentLog").delete()
    }

}
