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
        
        let devices = try await PushDevice.query(on: database).all()
        
        try devices.forEach { device in
            let deviceChannel = try DeviceChannel(id: UUID(), device: PushDevice(installId: device.installId, pushToken: device.pushToken), channel: PushChannel(channelId: "general"))
            //let _ = deviceChannel.save(on: database)
            print("Device \(device.installId) added to general notification channel.")
        }
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("PushDevice+PushChannel").delete()
    }

}
