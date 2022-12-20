//
//  DeviceChannel.swift
//  medo-delirio-api
//
//  Created by Rafael Claycon Schmitt on 19/12/22.
//

import Fluent
import Vapor

final class DeviceChannel: Model {

    static let schema = "PushDevice+PushChannel"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "installId")
    var device: PushDevice
    
    @Parent(key: "channel_id")
    var channel: PushChannel
    
    init() { }
    
    init(id: UUID? = nil, device: PushDevice, channel: PushChannel) throws {
        self.id = id
        self.$device.id = try device.requireID()
        self.$channel.id = try channel.requireID()
    }

}
