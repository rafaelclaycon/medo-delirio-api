//
//  AddFeaturedRankFieldToAuthor.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 15/10/26.
//

import Fluent

/// The app's row of favorite profile photos. Nil for every author until curated.
struct AddFeaturedRankFieldToAuthor: AsyncMigration {

    func prepare(on database: Database) async throws {
        try await database.schema("Author")
            .field("featuredRank", .int)
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema("Author")
            .deleteField("featuredRank")
            .update()
    }
}
