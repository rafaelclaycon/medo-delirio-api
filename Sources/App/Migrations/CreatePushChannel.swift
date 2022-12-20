//
//  CreatePushChannel.swift
//  medo-delirio-api
//
//  Created by Rafael Claycon Schmitt on 19/12/22.
//

import Fluent

struct CreatePushChannel: AsyncMigration {

    func prepare(on database: Database) async throws {
        try await database.schema("PushChannel")
            .id()
            .field("channel_id", .string, .required)
            .create()
        
        try await database.transaction { transaction in
            for channel in [PushChannel(channelId: "general"), PushChannel(channelId: "new_episodes")] {
                try await channel.save(on: transaction)
            }
        }
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("PushChannel").delete()
    }

}
