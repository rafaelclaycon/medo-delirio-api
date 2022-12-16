//
//  CreatePodcastEpisode.swift
//  medo-delirio-api
//
//  Created by Rafael Claycon Schmitt on 15/12/22.
//

import Fluent

struct CreatePodcastEpisode: AsyncMigration {

    func prepare(on database: Database) async throws {
        try await database.schema("PodcastEpisode")
            .id()
            .field("episodeId", .string, .required)
            .field("title", .string, .required)
            .field("description", .string, .required)
            .field("pubDate", .string, .required)
            .field("duration", .double, .required)
            .field("creationDate", .string, .required)
            .field("sendNotification", .bool, .required)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("PodcastEpisode").delete()
    }

}
