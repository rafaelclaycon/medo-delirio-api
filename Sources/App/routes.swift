//
//  routes.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 01/06/22.
//

import Vapor

let api: PathComponent = "api"
let v1: PathComponent = "v1"
let v2: PathComponent = "v2"
let v3: PathComponent = "v3"

func routes(_ app: Application) throws {
    let statusCheckController = StatusCheckController()
    app.get(api, v1, "status-check", use: statusCheckController.getStatusCheckHandlerV1)
    app.get(api, v2, "status-check", use: statusCheckController.getStatusCheckHandlerV2)
    
    let statisticsController = StatisticsController()
    app.get(api, v1, "all-client-device-info", use: statisticsController.getAllClientDeviceInfoHandlerV1)
    app.get(api, v1, "all-sound-share-count-stats", use: statisticsController.getAllSoundShareCountStatsHandlerV1)
    app.get(api, v1, "install-id-count", use: statisticsController.getInstallIdCountHandlerV1)
    app.get(api, v2, "sound-share-count-stats-all-time", use: statisticsController.getSoundShareCountStatsAllTimeHandlerV2)
    app.get(api, v2, "sound-share-count-stats-from", ":date", use: statisticsController.getSoundShareCountStatsFromHandlerV2)
    app.post(api, v1, "share-count-stat", use: statisticsController.postShareCountStatHandlerV1)
    app.post(api, v1, "shared-to-bundle-id", use: statisticsController.postSharedToBundleIdHandlerV1)
    
    let askForMoneyController = AskForMoneyController()
    app.get(api, v1, "display-ask-for-money-view", use: askForMoneyController.getDisplayAskForMoneyViewHandlerV1)
    app.get(api, v2, "current-test-version", use: askForMoneyController.getCurrentTestVersionHandlerV2)
    app.post(api, v1, "display-ask-for-money-view", use: askForMoneyController.postDisplayAskForMoneyViewHandlerV1)
    app.post(api, v2, "set-test-version", use: askForMoneyController.postSetTestVersionHandlerV2)
    
    let donorsController = DonorsController()
    app.get(api, v2, "donor-names", use: donorsController.getDonorNamesHandlerV2)
    app.get(api, v3, "donor-names", use: donorsController.getDonorNamesHandlerV3)
    app.get(api, v3, "display-recurring-donation-banner", use: donorsController.getDisplayRecurringDonationBannerHandlerV3)
    app.post(api, v2, "set-donor-names", ":password", use: donorsController.postSetDonorNamesHandlerV2)
    app.post(api, v3, "set-donor-names", ":password", use: donorsController.postSetDonorNamesHandlerV3)
    app.post(api, v3, "display-recurring-donation-banner", use: donorsController.postSetDisplayRecurringDonationBannerHandlerV3)
    
    let clientLoggingController = ClientLoggingController()
    app.post(api, v1, "client-device-info", use: clientLoggingController.postClientDeviceInfoHandlerV1)
    app.post(api, v1, "user-folder-logs", use: clientLoggingController.postUserFolderLogsHandlerV1)
    app.post(api, v1, "user-folder-content-logs", use: clientLoggingController.postUserFolderContentLogsHandlerV1)
    app.post(api, v1, "still-alive-signal", use: clientLoggingController.postStillAliveSignalHandlerV1)
    app.post(api, v2, "usage-metric", use: clientLoggingController.postUsageMetricHandlerV2)
    
    let notificationsController = NotificationsController()
    app.post(api, v1, "push-device", use: notificationsController.postPushDeviceHandlerV1)
    app.post(api, v1, "send-push-notification") { req -> HTTPStatus in
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
    //app.post(api, v2, "add-all-existing-devices-to-general-channel", use: notificationsController.postAddAllExistingDevicesToGeneralChannelHandlerV2)
    
    let soundsController = SoundsController()
    app.post(api, v3, "import-sounds", use: soundsController.postImportSoundsHandlerV3)
    app.post(api, v3, "create-sound", use: soundsController.postCreateSoundHandlerV3)
    app.get(api, v3, "sound", ":id", use: soundsController.getSoundHandlerV3)
    app.get(api, v3, "all-sounds", use: soundsController.getAllSoundsHandlerV3)
    app.delete(api, v3, "sound", ":id", use: soundsController.deleteSoundHandlerV3)
    
    let authorsController = AuthorsController()
    app.post(api, v3, "import-authors", use: authorsController.postImportAuthorsHandlerV3)
    app.post(api, v3, "create-author", ":password", use: authorsController.postCreateAuthorHandlerV3)
    app.get(api, v3, "author", ":id", use: authorsController.getAuthorHandlerV3)
    app.get(api, v3, "all-authors", use: authorsController.getAllAuthorsHandlerV3)
    app.delete(api, v3, "author", ":id", use: authorsController.deleteAuthorHandlerV3)
    
    let songsController = SongsController()
    app.post(api, v3, "import-songs", use: songsController.postImportSongsHandlerV3)
    app.get(api, v3, "all-songs", use: songsController.getAllSongsHandlerV3)

    let genresController = MusicGenresController()
    app.post(api, v3, "import-music-genres", use: genresController.postImportMusicGenresHandlerV3)
    app.get(api, v3, "all-music-genres", use: genresController.getAllMusicGenresHandlerV3)
    
    let updateEventsController = UpdateEventsController()
    app.get(api, v3, "update-events", ":date", use: updateEventsController.getUpdateEventsHandlerV3)
    app.get(api, v3, "update-events-for-display", ":password", use: updateEventsController.getUpdateEventsForDisplayHandlerV3)
    app.put(api, v3, "change-update-visibility", ":updateId", ":newValue", ":password", use: updateEventsController.putChangeUpdateVisibilityHandlerV3)
    app.put(api, v3, "update-content", use: updateEventsController.putUpdateContentHandlerV3)
    app.post(api, v3, "update-content-file", ":type", ":id", use: updateEventsController.postUpdateContentFileHandlerV3)
}
