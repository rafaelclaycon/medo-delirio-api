import Vapor

struct RSSStatusController {

    struct RSSStatusResponse: Content {
        let lastEpisodeTitle: String?
        let lastEpisodeGUID: String?
        let checkCount: Int
        let checkIntervalMinutes: Int
        let lastCheckedAt: Date?
    }

    func getRSSStatusHandlerV4(req: Request) async throws -> RSSStatusResponse {
        let record = try await LastKnownEpisode.query(on: req.db)
            .filter(\LastKnownEpisode.$feedURL, .equal, RSSPollingService.feedURL.absoluteString)
            .first()

        return RSSStatusResponse(
            lastEpisodeTitle: record?.episodeTitle,
            lastEpisodeGUID: record?.episodeGUID,
            checkCount: record?.checkCount ?? 0,
            checkIntervalMinutes: RSSPollingService.pollingIntervalMinutes,
            lastCheckedAt: record?.checkedAt
        )
    }
}
