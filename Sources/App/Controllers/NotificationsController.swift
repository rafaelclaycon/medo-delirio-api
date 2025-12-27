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
    
//    func postAddAllExistingDevicesToGeneralChannelHandlerV2(req: Request) throws -> HTTPStatus {
//        PushDevice.query(on: req.db).all().flatMapEach(on: req.eventLoop) { device in
//            let deviceChannel = try DeviceChannel(id: UUID(), device: PushDevice(installId: device.installId, pushToken: device.pushToken), channel: PushChannel(id: UUID(), channelId: "general"))
//            try deviceChannel.save(on: req.db)
//        }
//        return HTTPStatus.ok
//    }
}
