//
//  CreateCollectionSound.swift
//  medo-delirio-api
//
//  Created by Rafael Claycon Schmitt on 28/10/22.
//

import Fluent

struct CreateCollectionSound: AsyncMigration {

    func prepare(on database: Database) async throws {
        try await database.schema("CollectionSound")
            .id()
            .field("collectionId", .string, .required)
            .field("soundId", .string, .required)
            .field("dateAdded", .string, .required)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("CollectionSound").delete()
    }

}
