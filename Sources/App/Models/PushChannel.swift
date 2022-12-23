//
//  PushChannel.swift
//  medo-delirio-api
//
//  Created by Rafael Claycon Schmitt on 19/12/22.
//

import Fluent
import Vapor

final class PushChannel: Model, Content {

    static let schema = "PushChannel"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "channel_id")
    var channelId: String
    
    @Siblings(through: DeviceChannel.self, from: \.$channel, to: \.$device)
    public var devices: [PushDevice]
    
    init() { }
    
    init(id: UUID? = nil, channelId: String) {
        self.id = id
        self.channelId = channelId
    }

}
