import Vapor
import APNS
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
                await self.syncEpisodes(items: items)
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

    private func syncEpisodes(items: [RSSFeedItem]) async {
        let db = app.db

        // Early exit: if the most recent episode is already stored, the rest are too.
        if let firstGuid = items.first?.guid?.value {
            let latestId = Self.parseEpisodeId(from: firstGuid)
            if (try? await Episode.find(latestId, on: db)) != nil {
                app.logger.info("RSS poll: episode sync skipped — no new episodes")
                return
            }
        }

        var newCount = 0
        var updatedCount = 0

        for item in items {
            guard let guid = item.guid?.value else { continue }

            let episodeId = Self.parseEpisodeId(from: guid)
            let title = item.title ?? "Unknown"
            let imageURL = item.iTunes?.iTunesImage?.attributes?.href
            let pubDate = item.pubDate

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
                    let errorDescription = String(describing: error).lowercased()
                    if errorDescription.contains("baddevicetoken") || errorDescription.contains("unregistered") {
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
