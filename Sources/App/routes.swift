import Fluent
import Vapor
import SQLiteNIO
import APNS

func routes(_ app: Application) throws {
    let statusCheckController = StatusCheckController()
    app.get("api", "v1", "status-check", use: statusCheckController.getStatusCheckHandlerV1)
    app.get("api", "v2", "status-check", use: statusCheckController.getStatusCheckHandlerV2)
    
    let statisticsController = StatisticsController()
    app.get("api", "v1", "all-client-device-info", use: statisticsController.getAllClientDeviceInfoHandlerV1)
    app.get("api", "v1", "all-sound-share-count-stats", use: statisticsController.getAllSoundShareCountStatsHandlerV1)
    app.get("api", "v1", "install-id-count", use: statisticsController.getInstallIdCountHandlerV1)
    app.get("api", "v2", "sound-share-count-stats-all-time", use: statisticsController.getSoundShareCountStatsAllTimeHandlerV2)
    app.get("api", "v2", "sound-share-count-stats-from", ":date", use: statisticsController.getSoundShareCountStatsFromHandlerV2)
    app.post("api", "v1", "share-count-stat", use: statisticsController.postShareCountStatHandlerV1)
    app.post("api", "v1", "shared-to-bundle-id", use: statisticsController.postSharedToBundleIdHandlerV1)
    
    let askForMoneyController = AskForMoneyController()
    app.get("api", "v1", "display-ask-for-money-view", use: askForMoneyController.getDisplayAskForMoneyViewHandlerV1)
    app.get("api", "v2", "current-test-version", use: askForMoneyController.getCurrentTestVersionHandlerV2)
    app.post("api", "v1", "display-ask-for-money-view", use: askForMoneyController.postDisplayAskForMoneyViewHandlerV1)
    app.post("api", "v2", "set-test-version", use: askForMoneyController.postSetTestVersionHandlerV2)
    
    let donorsController = DonorsController()
    app.get("api", "v2", "donor-names", use: donorsController.getDonorNamesHandlerV2)
    app.get("api", "v3", "donor-names", use: donorsController.getDonorNamesHandlerV3)
    app.post("api", "v2", "set-donor-names", ":password", use: donorsController.postSetDonorNamesHandlerV2)
    app.post("api", "v3", "set-donor-names", ":password", use: donorsController.postSetDonorNamesHandlerV3)
    
    let clientLoggingController = ClientLoggingController()
    app.post("api", "v1", "client-device-info") { req -> EventLoopFuture<ClientDeviceInfo> in
        let info = try req.content.decode(ClientDeviceInfo.self)
        return info.save(on: req.db).map {
            info
        }
    }
    app.post("api", "v1", "user-folder-logs") { req -> HTTPStatus in
        let folderLogs = try req.content.decode([UserFolderLog].self)
        
        try await req.db.transaction { transaction in
            for log in folderLogs {
                try await log.save(on: transaction)
            }
        }
        return .ok
    }
    app.post("api", "v1", "user-folder-content-logs") { req -> HTTPStatus in
        let contentLogs = try req.content.decode([UserFolderContentLog].self)
        
        try await req.db.transaction { transaction in
            for log in contentLogs {
                try await log.save(on: transaction)
            }
        }
        return .ok
    }
    app.post("api", "v1", "still-alive-signal") { req -> HTTPStatus in
        let signal = try req.content.decode(StillAliveSignal.self)
        
        try await req.db.transaction { transaction in
            try await signal.save(on: transaction)
        }
        return .ok
    }
    app.post("api", "v2", "usage-metric") { req -> HTTPStatus in
        let metric = try req.content.decode(UsageMetric.self)
        try await req.db.transaction { transaction in
            try await metric.save(on: transaction)
        }
        return .ok
    }
    
    let notificationsController = NotificationsController()
    app.post("api", "v1", "push-device") { req -> EventLoopFuture<PushDevice> in
        let device = try req.content.decode(PushDevice.self)
        return device.save(on: req.db).map {
            device
        }
    }
    app.post("api", "v1", "send-push-notification") { req -> HTTPStatus in
        let notif = try req.content.decode(PushNotification.self)
        
        guard let password = notif.password, password == ReleaseConfigs.Passwords.sendNotificationPassword else {
            throw Abort(.unauthorized)
        }

        let devices = try await PushDevice.query(on: req.db).all()
        for device in devices {
            _ = app.apns.send(.init(title: notif.title, body: notif.description), to: device.pushToken)
            sleep(1)
        }
        return .ok
    }
//    app.post("api", "v2", "add-all-existing-devices-to-general-channel") { req -> HTTPStatus in
//        PushDevice.query(on: req.db).all().flatMapEach(on: req.eventLoop) { device in
//            let deviceChannel = try DeviceChannel(id: UUID(), device: PushDevice(installId: device.installId, pushToken: device.pushToken), channel: PushChannel(id: UUID(), channelId: "general"))
//            try deviceChannel.save(on: req.db)
//        }
//        return HTTPStatus.ok
//    }
}
