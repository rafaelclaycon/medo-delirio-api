//
//  CreateAuthor.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 02/05/23.
//

import Fluent

struct CreateAuthor: AsyncMigration {
    
    func prepare(on database: Database) async throws {
        try await database.schema("Author")
            .id()
            .field("name", .string, .required)
            .field("photo", .string)
            .field("description", .string)
            .field("isHidden", .bool, .required)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("Author").delete()
    }
}
