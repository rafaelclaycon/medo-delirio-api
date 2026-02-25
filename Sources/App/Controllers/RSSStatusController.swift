import Vapor
import APNS

struct RSSStatusController {

    struct RSSStatusResponse: Content {
        let lastEpisodeTitle: String?
        let lastEpisodeGUID: String?
        let checkCount: Int
        let checkIntervalMinutes: Int
        let lastCheckedAt: Date?
        let lastNotificationSentCount: Int?
        let lastNotifiedDeviceIds: [String]?
        let lastNotifiedAt: Date?
    }

    func getRSSStatusHandlerV4(req: Request) async throws -> RSSStatusResponse {
        guard let password = req.parameters.get("password"),
              password == ReleaseConfigs.Passwords.sendNotificationPassword else {
            throw Abort(.unauthorized)
        }

        let record = try await LastKnownEpisode.query(on: req.db)
            .filter(\LastKnownEpisode.$feedURL, .equal, RSSPollingService.feedURL.absoluteString)
            .first()

        let deviceIds: [String]? = record?.lastNotifiedDeviceIds?
            .split(separator: ",")
            .map(String.init)

        return RSSStatusResponse(
            lastEpisodeTitle: record?.episodeTitle,
            lastEpisodeGUID: record?.episodeGUID,
            checkCount: record?.checkCount ?? 0,
            checkIntervalMinutes: RSSPollingService.pollingIntervalMinutes,
            lastCheckedAt: record?.checkedAt,
            lastNotificationSentCount: record?.lastNotificationSentCount,
            lastNotifiedDeviceIds: deviceIds,
            lastNotifiedAt: record?.lastNotifiedAt
        )
    }

    struct TestPushResponse: Content {
        let sentCount: Int
        let deviceIds: [String]
        let errors: [String]
    }

    func postTestNewEpisodePushHandlerV4(req: Request) async throws -> TestPushResponse {
        guard let password = req.parameters.get("password"),
              password == ReleaseConfigs.Passwords.sendNotificationPassword else {
            throw Abort(.unauthorized)
        }

        guard let channel = try await PushChannel.query(on: req.db)
            .filter(\PushChannel.$channelId, .equal, "new_episodes")
            .with(\.$devices)
            .first()
        else {
            throw Abort(.notFound, reason: "'new_episodes' channel not found")
        }

        let devices = channel.devices
        guard !devices.isEmpty else {
            return TestPushResponse(sentCount: 0, deviceIds: [], errors: ["No devices subscribed to new_episodes"])
        }

        let notification = TypedNotification(
            aps: .init(alert: .init(title: "Novo Episódio", body: "\"Episódio de teste\" já disponível.")),
            type: "new_episode"
        )

        var sentCount = 0
        var sentDeviceIds: [String] = []
        var errors: [String] = []

        for device in devices {
            do {
                try await req.application.apns.send(notification, to: device.pushToken).get()
                sentCount += 1
                sentDeviceIds.append(device.installId)
            } catch {
                let errorDescription = String(describing: error).lowercased()
                if errorDescription.contains("baddevicetoken") || errorDescription.contains("unregistered") {
                    try? await device.delete(on: req.db)
                    errors.append("Deleted invalid token for device \(device.installId)")
                } else {
                    errors.append("Failed to send to \(device.installId): \(error)")
                }
            }
            try await Task.sleep(nanoseconds: 500_000_000)
        }

        return TestPushResponse(sentCount: sentCount, deviceIds: sentDeviceIds, errors: errors)
    }
}
