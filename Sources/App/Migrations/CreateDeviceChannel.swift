//
//  CreateDeviceChannel.swift
//  medo-delirio-api
//
//  Created by Rafael Claycon Schmitt on 19/12/22.
//

import Fluent

struct CreateDeviceChannel: AsyncMigration {

    func prepare(on database: Database) async throws {
        try await database.schema("PushDevice+PushChannel")
            .id()
            .field("installId", .string, .required)
            .field("channel_id", .string, .required)
            .unique(on: "installId", "channel_id")
            .create()
        
        try await PushDevice.query(on: database).all().compactMap { device in
            let deviceChannel = try DeviceChannel(device: PushDevice(installId: device.installId, pushToken: device.pushToken), channel: PushChannel(channelId: "general"))
            deviceChannel.save(on: database)
        }
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("PushDevice+PushChannel").delete()
    }

}
