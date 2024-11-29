//
//  AddImageAuthorAttributionToReaction.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 29/11/24.
//

import Fluent

struct AddImageAuthorAttributionToReaction: AsyncMigration {

    func prepare(on database: Database) async throws {
        try await database.schema("Reaction")
            .field("attributionText", .string)
            .update()

        try await database.schema("Reaction")
            .field("attributionURL", .string)
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema("Reaction")
            .deleteField("attributionText")
            .update()

        try await database.schema("Reaction")
            .deleteField("attributionURL")
            .update()
    }
}
