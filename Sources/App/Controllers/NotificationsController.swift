//
//  NotificationsController.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 22/05/23.
//

import Vapor
import APNS

struct NotificationsController {
    
    func postPushDeviceHandlerV1(req: Request) async throws -> PushDevice {
        let input = try req.content.decode(PushDevice.self)
        
        if let existingDevice = try await PushDevice.query(on: req.db)
            .filter(\PushDevice.$installId, .equal, input.installId)
            .first()
        {
            existingDevice.pushToken = input.pushToken
            try await existingDevice.save(on: req.db)
            return existingDevice
        } else {
            try await input.save(on: req.db)
            return input
        }
    }
    
    func postSendPushNotificationHandlerV1(req: Request) async throws -> HTTPStatus {
        let notif = try req.content.decode(PushNotification.self)

        guard let password = notif.password, password == ReleaseConfigs.Passwords.sendNotificationPassword else {
            throw Abort(.unauthorized)
        }

        let devices = try await PushDevice.query(on: req.db).all()
        for device in devices {
            guard let token = device.pushToken, !token.isEmpty else {
                continue
            }
            do {
                try await req.application.apns.send(.init(title: notif.title, body: notif.description), to: token).get()
            } catch {
                if PushTokenErrors.isInvalidToken(error) {
                    try? await device.delete(on: req.db)
                    req.logger.info("Deleted invalid push token for device \(device.installId)")
                } else {
                    req.logger.error("Failed to send push to \(device.installId): \(error)")
                }
            }
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        return .ok
    }

    /// Sends this week's highlights right away, ignoring the once-a-day guard.
    func postTestWeeklyHighlightsPushHandlerV4(req: Request) async throws -> WeeklyHighlightsSendResult {
        guard let password = req.parameters.get("password"),
              password == ReleaseConfigs.Passwords.analyticsPassword else {
            throw Abort(.forbidden)
        }
        let service = WeeklyHighlightsService(app: req.application)
        guard let result = await service.sendWeeklyHighlights(force: true) else {
            throw Abort(.internalServerError, reason: "No highlight data found for the past 7 days")
        }
        return result
    }

    struct ChannelSubscriptionRequest: Content {
        let installId: String
        let channelId: String
    }

    func postSubscribeChannelHandlerV4(req: Request) async throws -> HTTPStatus {
        let input = try req.content.decode(ChannelSubscriptionRequest.self)

        let device: PushDevice
        if let existing = try await PushDevice.query(on: req.db)
            .filter(\PushDevice.$installId, .equal, input.installId)
            .first()
        {
            device = existing
        } else {
            let newDevice = PushDevice(installId: input.installId)
            try await newDevice.save(on: req.db)
            device = newDevice
        }

        guard let channel = try await PushChannel.query(on: req.db)
            .filter(\PushChannel.$channelId, .equal, input.channelId)
            .first()
        else {
            throw Abort(.notFound, reason: "Channel not found")
        }

        let existingPivot = try await DeviceChannel.query(on: req.db)
            .filter(\DeviceChannel.$device.$id, .equal, try device.requireID())
            .filter(\DeviceChannel.$channel.$id, .equal, try channel.requireID())
            .first()

        if existingPivot == nil {
            let pivot = try DeviceChannel(device: device, channel: channel)
            try await pivot.save(on: req.db)

            // Only log genuine new subscriptions, so subscribe/unsubscribe counts
            // reflect actual state transitions rather than idempotent re-subscribes.
            try await ChannelSubscriptionEvent(
                installId: input.installId,
                channelId: input.channelId,
                action: ChannelSubscriptionEvent.Action.subscribe,
                dateTime: Date().iso8601withFractionalSeconds
            ).save(on: req.db)
        }

        return .ok
    }

    func postUnsubscribeChannelHandlerV4(req: Request) async throws -> HTTPStatus {
        let input = try req.content.decode(ChannelSubscriptionRequest.self)

        guard let device = try await PushDevice.query(on: req.db)
            .filter(\PushDevice.$installId, .equal, input.installId)
            .first()
        else {
            throw Abort(.notFound, reason: "Device not found")
        }

        guard let channel = try await PushChannel.query(on: req.db)
            .filter(\PushChannel.$channelId, .equal, input.channelId)
            .first()
        else {
            throw Abort(.notFound, reason: "Channel not found")
        }

        if let existing = try await DeviceChannel.query(on: req.db)
            .filter(\DeviceChannel.$device.$id, .equal, try device.requireID())
            .filter(\DeviceChannel.$channel.$id, .equal, try channel.requireID())
            .first()
        {
            try await existing.delete(on: req.db)

            // Log only real unsubscribes (a pivot actually existed and was removed).
            try await ChannelSubscriptionEvent(
                installId: input.installId,
                channelId: input.channelId,
                action: ChannelSubscriptionEvent.Action.unsubscribe,
                dateTime: Date().iso8601withFractionalSeconds
            ).save(on: req.db)
        }

        return .ok
    }

    func getDeviceChannelsHandlerV4(req: Request) async throws -> [String] {
        guard let installId = req.parameters.get("installId") else {
            throw Abort(.badRequest, reason: "Missing installId")
        }

        guard let device = try await PushDevice.query(on: req.db)
            .filter(\PushDevice.$installId, .equal, installId)
            .with(\.$channels)
            .first()
        else {
            throw Abort(.notFound, reason: "Device not found")
        }

        return device.channels.map { $0.channelId }
    }
}

// MARK: - Routes

extension NotificationsController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let v1 = routes.grouped("api", "v1")
        let v4 = routes.grouped("api", "v4")

        v1.post("push-device", use: postPushDeviceHandlerV1)
        v1.post("send-push-notification", use: postSendPushNotificationHandlerV1)
        v4.post("subscribe-channel", use: postSubscribeChannelHandlerV4)
        v4.post("unsubscribe-channel", use: postUnsubscribeChannelHandlerV4)
        v4.get("device-channels", ":installId", use: getDeviceChannelsHandlerV4)
        v4.post("test-weekly-highlights-push", ":password", use: postTestWeeklyHighlightsPushHandlerV4)
    }
}
