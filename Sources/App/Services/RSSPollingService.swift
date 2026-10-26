import Vapor
import APNS
import FeedKit

struct RSSPollingService {

    static let feedURL = URL(string: "https://www.spreaker.com/show/4711842/episodes/feed")!
    static let pollingIntervalMinutes = 20
    static let minimumFeedItemCount = 5
    static let newEpisodeCooldownHours = 2

    static let requestTimeoutSeconds: Int64 = 30

    let app: Application

    struct FeedEpisode: Sendable, Equatable {
        let guid: String
        let title: String
        let imageURL: String?
        let pubDate: Date?
    }

    /// Every episode in the feed that has a GUID, newest first. The first one is always the
    /// feed's latest item.
    struct FeedSnapshot: Sendable {
        let episodes: [FeedEpisode]

        var latest: FeedEpisode { episodes[0] }
    }

    enum FeedError: Error, CustomStringConvertible {
        case parse(ParserError)
        case noItems
        case tooFewItems(Int)
        case missingLatestGUID

        var description: String {
            switch self {
            case .parse(let error):
                return "failed to parse feed - \(error)"
            case .noItems:
                return "failed to extract episodes from feed"
            case .tooFewItems(let count):
                return "feed returned only \(count) item(s), expected at least \(RSSPollingService.minimumFeedItemCount) — skipping (possible feed malfunction)"
            case .missingLatestGUID:
                return "failed to extract latest episode GUID from feed"
            }
        }
    }

    func checkForNewEpisode() async {
        app.logger.info("RSS poll: checking feed for new episodes...")

        let snapshot: FeedSnapshot
        do {
            let data = try await fetchFeed()
            // Parsing ~1 MB of XML is blocking work, kept off the concurrency pool.
            snapshot = try await app.threadPool.runIfActive { try Self.parseFeed(data) }
        } catch let error as FeedError {
            if case .tooFewItems = error {
                app.logger.warning("RSS poll: \(error)")
            } else {
                app.logger.error("RSS poll: \(error)")
            }
            return
        } catch {
            app.logger.error("RSS poll: failed to fetch feed - \(error)")
            return
        }

        await processEpisode(guid: snapshot.latest.guid, title: snapshot.latest.title)
        await syncEpisodes(snapshot.episodes)
    }

    private func fetchFeed() async throws -> Data {
        let response = try await app.client.get(URI(string: Self.feedURL.absoluteString)) { request in
            request.timeout = .seconds(Self.requestTimeoutSeconds)
        }
        guard response.status == .ok else {
            throw Abort(response.status, reason: "feed responded \(response.status.code)")
        }
        guard let body = response.body else {
            throw Abort(.badGateway, reason: "feed responded with an empty body")
        }
        return Data(body.readableBytesView)
    }

    static func parseFeed(_ data: Data) throws(FeedError) -> FeedSnapshot {
        let feed: Feed
        switch FeedParser(data: data).parse() {
        case .success(let parsed):
            feed = parsed
        case .failure(let error):
            throw .parse(error)
        }

        guard let items = feed.rssFeed?.items else {
            throw .noItems
        }
        guard items.count >= minimumFeedItemCount else {
            throw .tooFewItems(items.count)
        }
        guard items.first?.guid?.value != nil else {
            throw .missingLatestGUID
        }

        let episodes = items.compactMap { item -> FeedEpisode? in
            guard let guid = item.guid?.value else { return nil }
            return FeedEpisode(
                guid: guid,
                title: item.title ?? "Unknown",
                imageURL: item.iTunes?.iTunesImage?.attributes?.href,
                pubDate: item.pubDate
            )
        }
        return FeedSnapshot(episodes: episodes)
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
                        let result = await sendNewEpisodeNotifications(title: title)
                        existing.lastNotificationSentCount = result.sentCount
                        existing.lastNotifiedDeviceIds = result.deviceIds.joined(separator: ",")
                        existing.lastNotifiedAt = Date()
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

    // MARK: - Episode ID Parsing (mirrors parseEpisodeId in the iOS app)

    static func parseEpisodeId(from guid: String) -> String {
        guard let url = URL(string: guid), url.scheme != nil else {
            return guid // not a URL, use as-is
        }

        let lastComponent = url.lastPathComponent
        if !lastComponent.isEmpty && lastComponent != "/" {
            return lastComponent // Spreaker-style: .../episode/69980761
        }

        // WordPress-style: .../?p=40097
        if let queryItems = URLComponents(string: guid)?.queryItems,
           let p = queryItems.first(where: { $0.name == "p" })?.value,
           !p.isEmpty {
            return p
        }

        return guid // fallback: use full GUID string
    }

    // MARK: - Episode Sync

    private func syncEpisodes(_ feedEpisodes: [FeedEpisode]) async {
        let db = app.db

        // Early exit: if the most recent episode is already stored, the rest are too.
        if let latest = feedEpisodes.first {
            let latestId = Self.parseEpisodeId(from: latest.guid)
            if (try? await Episode.find(latestId, on: db)) != nil {
                app.logger.info("RSS poll: episode sync skipped — no new episodes")
                return
            }
        }

        var newCount = 0
        var updatedCount = 0

        for feedEpisode in feedEpisodes {
            let episodeId = Self.parseEpisodeId(from: feedEpisode.guid)
            let title = feedEpisode.title
            let imageURL = feedEpisode.imageURL
            let pubDate = feedEpisode.pubDate

            do {
                if let existing = try await Episode.find(episodeId, on: db) {
                    var changed = false
                    if existing.title != title { existing.title = title; changed = true }
                    if let imageURL, existing.imageURL != imageURL { existing.imageURL = imageURL; changed = true }
                    if let pubDate, existing.pubDate != pubDate { existing.pubDate = pubDate; changed = true }
                    if changed {
                        try await existing.save(on: db)
                        updatedCount += 1
                    }
                } else {
                    let episode = Episode(id: episodeId, title: title, imageURL: imageURL, pubDate: pubDate)
                    try await episode.save(on: db)
                    newCount += 1
                }
            } catch {
                app.logger.error("RSS poll: failed to sync episode \(episodeId) - \(error)")
            }
        }

        if newCount > 0 || updatedCount > 0 {
            app.logger.info("RSS poll: synced episodes — \(newCount) new, \(updatedCount) updated")
        }
    }

    func sendNewEpisodeNotifications(title: String) async -> (sentCount: Int, deviceIds: [String]) {
        let db = app.db

        do {
            guard let channel = try await PushChannel.query(on: db)
                .filter(\PushChannel.$channelId, .equal, "new_episodes")
                .with(\.$devices)
                .first()
            else {
                app.logger.warning("RSS poll: 'new_episodes' channel not found — skipping notifications")
                return (0, [])
            }

            let devices = channel.devices
            guard !devices.isEmpty else {
                app.logger.info("RSS poll: no devices subscribed to 'new_episodes' — skipping notifications")
                return (0, [])
            }

            let notification = TypedNotification(
                aps: .init(alert: .init(title: "Novo Episódio", body: "\"\(title)\" já disponível.")),
                type: "new_episode"
            )

            var sentCount = 0
            var sentDeviceIds: [String] = []
            for device in devices {
                guard let token = device.pushToken, !token.isEmpty else {
                    continue
                }
                do {
                    try await app.apns.send(notification, to: token).get()
                    sentCount += 1
                    sentDeviceIds.append(device.installId)
                } catch {
                    if PushTokenErrors.isInvalidToken(error) {
                        try? await device.delete(on: db)
                        app.logger.info("RSS poll: deleted invalid push token for device \(device.installId)")
                    } else {
                        app.logger.error("RSS poll: failed to send push to \(device.installId): \(error)")
                    }
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }

            app.logger.info("RSS poll: sent \(sentCount)/\(devices.count) new episode notifications")
            return (sentCount, sentDeviceIds)
        } catch {
            app.logger.error("RSS poll: failed to query new_episodes channel - \(error)")
            return (0, [])
        }
    }
}
