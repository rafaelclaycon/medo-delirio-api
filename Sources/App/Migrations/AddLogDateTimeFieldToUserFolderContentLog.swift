//
//  AddLogDateTimeFieldToUserFolderContentLog.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 02/11/24.
//

import Fluent

struct AddLogDateTimeFieldToUserFolderContentLog: AsyncMigration {

    func prepare(on database: Database) async throws {
        try await database.schema("UserFolderContentLog")
            .field("logDateTime", .string)
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema("UserFolderContentLog")
            .deleteField("logDateTime")
            .update()
    }
}
