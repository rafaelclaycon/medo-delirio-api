//
//  AddExternalLinksFieldToAuthor.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 25/03/24.
//

import Fluent

struct AddExternalLinksFieldToAuthor: AsyncMigration {

    func prepare(on database: Database) async throws {
        try await database.schema("Author")
            .field("externalLinks", .string)
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema("Author")
            .deleteField("externalLinks")
            .update()
    }
}
