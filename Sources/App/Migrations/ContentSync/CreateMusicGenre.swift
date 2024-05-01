//
//  CreateMusicGenre.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 26/08/23.
//

import Fluent

struct CreateMusicGenre: AsyncMigration {

    func prepare(on database: Database) async throws {
        try await database.schema("MusicGenre")
            .id()
            .field("symbol", .string, .required)
            .field("name", .string, .required)
            .field("isHidden", .bool, .required)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("MusicGenre").delete()
    }
}
