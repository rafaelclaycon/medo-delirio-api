//
//  PushDevice.swift
//  medo-delirio-api
//
//  Created by Rafael Claycon Schmitt on 06/07/22.
//

import Fluent
import Vapor

final class PushDevice: Model, Content {

    static let schema = "PushDevice"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "installId")
    var installId: String
    
    @Field(key: "pushToken")
    var pushToken: String
    
    @Siblings(through: DeviceChannel.self, from: \.$device, to: \.$channel)
    public var channels: [PushChannel]
    
    init() { }
    
    init(id: UUID? = nil, installId: String, pushToken: String) {
        self.id = id
        self.installId = installId
        self.pushToken = pushToken
    }

}
