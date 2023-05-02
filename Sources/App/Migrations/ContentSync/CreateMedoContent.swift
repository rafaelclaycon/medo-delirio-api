//
//  CreateMedoContent.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 30/04/23.
//

import Fluent

struct CreateMedoContent: AsyncMigration {

    func prepare(on database: Database) async throws {
        try await database.schema("MedoContent")
            .id()
            .field("title", .string, .required)
            .field("authorId", .string, .required)
            .field("description", .string, .required)
            .field("contentFileId", .string, .required)
            .field("creationDate", .string, .required)
            .field("duration", .double, .required)
            .field("isOffensive", .bool, .required)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("MedoContent").delete()
    }
}
