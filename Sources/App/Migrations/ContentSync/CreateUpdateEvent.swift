//
//  CreateUpdateEvent.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 02/05/23.
//

import Fluent

struct CreateUpdateEvent: AsyncMigration {
    
    func prepare(on database: Database) async throws {
        try await database.schema("UpdateEvent")
            .id()
            .field("contentId", .string, .required)
            .field("dateTime", .string, .required)
            .field("mediaType", .int, .required)
            .field("eventType", .int, .required)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("UpdateEvent").delete()
    }
}
