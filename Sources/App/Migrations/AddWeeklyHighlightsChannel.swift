import Fluent

struct AddWeeklyHighlightsChannel: AsyncMigration {

    func prepare(on database: Database) async throws {
        try await PushChannel(channelId: "weekly_highlights").save(on: database)
    }

    func revert(on database: Database) async throws {
        try await PushChannel.query(on: database)
            .filter(\PushChannel.$channelId, .equal, "weekly_highlights")
            .delete()
    }
}
