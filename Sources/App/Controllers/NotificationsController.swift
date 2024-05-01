//
//  NotificationsController.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 22/05/23.
//

import Vapor
import APNS

struct NotificationsController {
    
    func postPushDeviceHandlerV1(req: Request) throws -> EventLoopFuture<PushDevice> {
        let device = try req.content.decode(PushDevice.self)
        return device.save(on: req.db).map {
            device
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
