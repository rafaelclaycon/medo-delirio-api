//
//  CreateReactionSound.swift
//  medo-delirio-api
//
//  Created by Rafael Claycon Schmitt on 28/10/22.
//

import Fluent

struct CreateReactionSound: AsyncMigration {

    func prepare(on database: Database) async throws {
        try await database.schema("ReactionSound")
            .id()
            .field("reactionId", .string, .required)
            .field("soundId", .string, .required)
            .field("dateAdded", .string, .required)
            .field("position", .int, .required)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("ReactionSound").delete()
    }
}
