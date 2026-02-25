import Vapor
import FeedKit

struct RSSPollingService {

    static let feedURL = URL(string: "https://www.spreaker.com/show/4711842/episodes/feed")!
    static let pollingIntervalMinutes = 20
    static let minimumFeedItemCount = 5
    static let newEpisodeCooldownHours = 2

    let app: Application

    func checkForNewEpisode() {
        app.logger.info("RSS poll: checking feed for new episodes...")

        let parser = FeedParser(URL: Self.feedURL)
        let result = parser.parse()

        switch result {
        case .success(let feed):
            guard let rssFeed = feed.rssFeed,
                  let items = rssFeed.items else {
                app.logger.error("RSS poll: failed to extract episodes from feed")
                return
            }

            guard items.count >= Self.minimumFeedItemCount else {
                app.logger.warning("RSS poll: feed returned only \(items.count) item(s), expected at least \(Self.minimumFeedItemCount) — skipping (possible feed malfunction)")
                return
            }

            guard let latestItem = items.first,
                  let guid = latestItem.guid?.value else {
                app.logger.error("RSS poll: failed to extract latest episode GUID from feed")
                return
            }

            let title = latestItem.title ?? "Unknown"
            Task {
                await self.processEpisode(guid: guid, title: title)
            }

        case .failure(let error):
            app.logger.error("RSS poll: failed to parse feed - \(error)")
        }
    }

    private func processEpisode(guid: String, title: String) async {
        let db = app.db

        do {
            let existing = try await LastKnownEpisode.query(on: db)
                .filter(\LastKnownEpisode.$feedURL, .equal, Self.feedURL.absoluteString)
                .first()

            if let existing = existing {
                existing.checkCount += 1
                existing.checkedAt = Date()

                if existing.episodeGUID != guid {
                    let hoursSinceLastChange = Date().timeIntervalSince(existing.episodeChangedAt ?? .distantPast) / 3600
                    if hoursSinceLastChange < Double(Self.newEpisodeCooldownHours) {
                        app.logger.warning("RSS poll: new GUID detected but cooldown active (\(String(format: "%.1f", hoursSinceLastChange))h < \(Self.newEpisodeCooldownHours)h) — skipping")
                    } else {
                        app.logger.info("RSS poll: new episode detected - \"\(title)\"")
                        existing.episodeGUID = guid
                        existing.episodeTitle = title
                        existing.episodeChangedAt = Date()
                        // TODO: Send APNS notification here
                    }
                } else {
                    app.logger.info("RSS poll: no new episode (latest: \"\(existing.episodeTitle)\")")
                }

                try await existing.save(on: db)
            } else {
                app.logger.info("RSS poll: seeded initial episode - \"\(title)\"")
                let record = LastKnownEpisode(
                    feedURL: Self.feedURL.absoluteString,
                    episodeGUID: guid,
                    episodeTitle: title
                )
                try await record.save(on: db)
            }
        } catch {
            app.logger.error("RSS poll: database error - \(error)")
        }
    }
}
