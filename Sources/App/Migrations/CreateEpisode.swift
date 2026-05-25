//
//  CreateEpisode.swift
//  medo-delirio-api
//

import Fluent

struct CreateEpisode: AsyncMigration {

    func prepare(on database: Database) async throws {
        try await database.schema("Episode")
            .field("id", .string, .identifier(auto: false))
            .field("title", .string, .required)
            .field("imageURL", .string)
            .field("pubDate", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("Episode").delete()
    }
}
