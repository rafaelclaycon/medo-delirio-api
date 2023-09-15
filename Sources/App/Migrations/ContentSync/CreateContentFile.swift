//
//  CreateContentFile.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 02/05/23.
//

import Fluent

struct CreateContentFile: AsyncMigration {
    
    func prepare(on database: Database) async throws {
        try await database.schema("ContentFile")
            .id()
            .field("fileId", .string, .required)
            .field("hash", .string, .required)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("ContentFile").delete()
    }
}
