//
//  ContentUpdatePushService.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 26/07/26.
//

import Vapor
import Fluent
import APNS

/// Sends silent background pushes telling devices new content is available to sync.
/// Calls are debounced so publishing a batch of items produces a single poke.
actor ContentUpdatePushService {

    static let shared = ContentUpdatePushService()

    /// Seconds of quiet after the last publish before the push goes out.
    private let debounceInterval: UInt64 = 180

    private var pendingTask: Task<Void, Never>?

    func contentPublished(on app: Application) {
        pendingTask?.cancel()
        pendingTask = Task {
            try? await Task.sleep(nanoseconds: debounceInterval * 1_000_000_000)
            guard !Task.isCancelled else { return }
            await send(on: app)
        }
    }

    private func send(on app: Application) async {
        let devices: [PushDevice]
        do {
            devices = try await PushDevice.query(on: app.db).all()
        } catch {
            app.logger.error("Content update push: failed to fetch devices: \(error)")
            return
        }

        app.logger.info("Content update push: poking \(devices.count) devices")

        // No alert/sound/badge; "content-available": 1 with priority 5 is what
        // makes APNs treat this as a background wake-up instead of a notification.
        let notification = TypedNotification(
            aps: .init(hasContentAvailable: true),
            type: "content_update"
        )

        for device in devices {
            guard let token = device.pushToken, !token.isEmpty else {
                continue
            }
            do {
                try await app.apns.send(notification, pushType: .background, to: token, priority: 5).get()
            } catch {
                let errorDescription = String(describing: error).lowercased()
                if errorDescription.contains("baddevicetoken") || errorDescription.contains("unregistered") {
                    try? await device.delete(on: app.db)
                    app.logger.info("Content update push: deleted invalid push token for device \(device.installId)")
                } else {
                    app.logger.error("Content update push: failed to send to \(device.installId): \(error)")
                }
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        app.logger.info("Content update push: done")
    }
}
