//
//  CreateContentCollection.swift
//  medo-delirio-api
//
//  Created by Rafael Claycon Schmitt on 28/10/22.
//

import Fluent

struct CreateContentCollection: AsyncMigration {

    func prepare(on database: Database) async throws {
        try await database.schema("ContentCollection")
            .id()
            .field("title", .string, .required)
            .field("imageUrl", .string, .required)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("ContentCollection").delete()
    }

}
