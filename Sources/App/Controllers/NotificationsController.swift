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
