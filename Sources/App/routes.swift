//
//  routes.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 01/06/22.
//

import Vapor

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
    app.post("api", "v1", "client-device-info", use: clientLoggingController.postClientDeviceInfoHandlerV1)
    app.post("api", "v1", "user-folder-logs", use: clientLoggingController.postUserFolderLogsHandlerV1)
    app.post("api", "v1", "user-folder-content-logs", use: clientLoggingController.postUserFolderContentLogsHandlerV1)
    app.post("api", "v1", "still-alive-signal", use: clientLoggingController.postStillAliveSignalHandlerV1)
    app.post("api", "v2", "usage-metric", use: clientLoggingController.postUsageMetricHandlerV2)
    
    let notificationsController = NotificationsController()
    app.post("api", "v1", "push-device", use: notificationsController.postPushDeviceHandlerV1)
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
    //app.post("api", "v2", "add-all-existing-devices-to-general-channel", use: notificationsController.postAddAllExistingDevicesToGeneralChannelHandlerV2)

    app.get("api", "v3", "sound", ":id") { req -> EventLoopFuture<Sound> in
        guard let soundId = req.parameters.get("id", as: String.self) else {
            throw Abort(.badRequest)
        }
        print(soundId)
        guard let soundIdAsUUID = UUID(uuidString: soundId) else {
            throw Abort(.internalServerError)
        }
        
        return MedoContent.query(on: req.db)
            .filter(\.$id == soundIdAsUUID)
            .first()
            .unwrap(or: Abort(.notFound))
            .flatMap { content in
                let sound = Sound(content: content)
                return req.eventLoop.makeSucceededFuture(sound)
            }
    }
    
    app.get("api", "v3", "all-sounds") { req -> EventLoopFuture<[Sound]> in
        let query = MedoContent.query(on: req.db)
            .filter(\.$contentType == .sound)
        
        return query.all().flatMapThrowing { medoContentList in
            medoContentList.map { content in
                return Sound(content: content)
            }
        }
    }

    app.get("api", "v3", "all-authors") { req -> EventLoopFuture<[Author]> in
        Author.query(on: req.db).all()
    }
    
    app.get("api", "v3", "update-events", ":date") { req -> EventLoopFuture<[UpdateEvent]> in
        guard let date = req.parameters.get("date") else {
            throw Abort(.badRequest)
        }
        
        if date == "all" {
            return UpdateEvent.query(on: req.db).all()
        }
        
        guard date.isUTCDateString() else {
            throw Abort(.badRequest)
        }
        
        print(date)
        
        if let sqlite = req.db as? SQLiteDatabase {
            let query = """
                select *
                from UpdateEvent
                where dateTime > '\(date)'
                order by dateTime
            """

            return sqlite.query(query).flatMapEach(on: req.eventLoop) { row in
                req.eventLoop.makeSucceededFuture(
                    UpdateEvent(id: row.column("id")?.string ?? "",
                                contentId: row.column("contentId")?.string ?? "",
                                dateTime: row.column("dateTime")?.string ?? "",
                                mediaType: row.column("mediaType")?.integer ?? 0,
                                eventType: row.column("eventType")?.integer ?? 0)
                )
            }
        } else {
            return req.eventLoop.makeSucceededFuture([])
        }
    }

    app.post("api", "v3", "create-sound") { req -> Response in
        let content = try req.content.decode(MedoContent.self)
        try await req.db.transaction { transaction in
            try await content.save(on: transaction)
        }
        
        let contentFile = ContentFile(fileId: content.fileId, hash: "")
        try await req.db.transaction { transaction in
            try await contentFile.save(on: transaction)
        }
        
        guard let contentId = content.id?.uuidString else {
            throw Abort(.internalServerError)
        }
        
        let updateEvent = UpdateEvent(contentId: contentId,
                                      dateTime: Date.now.iso8601withFractionalSeconds,
                                      mediaType: .sound,
                                      eventType: .created)
        try await req.db.transaction { transaction in
            try await updateEvent.save(on: transaction)
        }
        
        return Response(status: .created, body: Response.Body(stringLiteral: content.id?.uuidString ?? ""))
    }
    
    app.post("api", "v3", "create-author", ":password") { req -> HTTPStatus in
        guard let password = req.parameters.get("password") else {
            throw Abort(.internalServerError)
        }
        guard password == ReleaseConfigs.Passwords.assetOperationPassword else {
            throw Abort(.forbidden)
        }
        let content = try req.content.decode(Author.self)
        try await req.db.transaction { transaction in
            try await content.save(on: transaction)
        }
        return .ok
    }
    
    app.post("api", "v3", "import-authors") { req -> HTTPStatus in
        let authors = try req.content.decode([Author].self)
        try await req.db.transaction { transaction in
            try await authors.create(on: transaction)
        }
        return .ok
    }
    
    app.post("api", "v3", "import-sounds") { req -> HTTPStatus in
        let sounds = try req.content.decode([Sound].self)
        
        try await req.db.transaction { transaction in
            for sound in sounds {
                let medoContent = MedoContent(sound: sound)
                try await medoContent.create(on: transaction)
            }
        }
        
        return .ok
    }
    
    app.put("api", "v3", "update-content") { req -> EventLoopFuture<HTTPStatus> in
        let medoContent = try req.content.decode(MedoContent.self)

        return MedoContent.find(medoContent.id, on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { existingMedoContent in
                existingMedoContent.title = medoContent.title
                existingMedoContent.authorId = medoContent.authorId
                existingMedoContent.description = medoContent.description
                //existingMedoContent.fileId = medoContent.fileId
                existingMedoContent.duration = medoContent.duration
                existingMedoContent.isOffensive = medoContent.isOffensive
                existingMedoContent.musicGenre = medoContent.musicGenre
                existingMedoContent.contentType = medoContent.contentType
                
                let updateEvent = UpdateEvent(
                    contentId: medoContent.id!.uuidString,
                    dateTime: Date().iso8601withFractionalSeconds,
                    mediaType: medoContent.contentType == .sound ? .sound : .song,
                    eventType: .metadataUpdated
                )
                
                return existingMedoContent.save(on: req.db)
                    .and(updateEvent.save(on: req.db))
                    .transform(to: .ok)
            }
    }
}
