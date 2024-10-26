//
//  CreateReaction.swift
//  medo-delirio-api
//
//  Created by Rafael Claycon Schmitt on 28/10/22.
//

import Fluent

struct CreateReaction: AsyncMigration {

    func prepare(on database: Database) async throws {
        try await database.schema("Reaction")
            .id()
            .field("title", .string, .required)
            .field("position", .int, .required)
            .field("image", .string, .required)
            .field("lastUpdate", .string, .required)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("Reaction").delete()
    }
}
