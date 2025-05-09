//
//  routes.swift
//  medo-delirio-api
//
//  Created by Rafael Claycon Schmitt on 01/06/22.
//

import Vapor

let api: PathComponent = "api"
let v1: PathComponent = "v1"
let v2: PathComponent = "v2"
let v3: PathComponent = "v3"
let v4: PathComponent = "v4"

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
    app.get(api, v3, "sound-share-count-stats-all-time", use: statisticsController.getSoundShareCountStatsAllTimeHandlerV3)
    app.get(api, v3, "sound-share-count-stats-from", ":date", use: statisticsController.getSoundShareCountStatsFromHandlerV3)
    app.get(api, v3, "sound-share-count-stats-from-to", ":firstDate", ":secondDate", use: statisticsController.getSoundShareCountStatsFromToHandlerV3)
    app.get(api, v3, "sound-share-count-stats-for", ":soundId", use: statisticsController.getSoundShareCountStatsForSoundIdHandler)
    app.post(api, v1, "share-count-stat", use: statisticsController.postShareCountStatHandlerV1)
    app.post(api, v1, "shared-to-bundle-id", use: statisticsController.postSharedToBundleIdHandlerV1)

    // Songs
    app.get(api, v3, "song-share-count-stats-all-time", use: statisticsController.getSongShareCountStatsAllTimeHandlerV3)
    app.get(api, v3, "song-share-count-stats-from", ":date", use: statisticsController.getSongShareCountStatsFromHandlerV3)
    app.get(api, v3, "song-share-count-stats-from-to", ":firstDate", ":secondDate", use: statisticsController.getSongShareCountStatsFromToHandlerV3)

    // Reactions
    app.get(api, v3, "reaction-popularity-stats", use: statisticsController.getReactionPopularityStatsHandlerV3)
    app.get(api, v4, "top-3-reactions", use: statisticsController.getTop3ReactionsHandlerV4)

    let askForMoneyController = AskForMoneyController()
    app.get(api, v1, "display-ask-for-money-view", use: askForMoneyController.getDisplayAskForMoneyViewHandlerV1)
    app.get(api, v2, "current-test-version", use: askForMoneyController.getCurrentTestVersionHandlerV2)
    app.get(api, v4, "money-info", use: askForMoneyController.getMoneyInfoHandlerV4)
    app.post(api, v1, "display-ask-for-money-view", use: askForMoneyController.postDisplayAskForMoneyViewHandlerV1)
    app.post(api, v2, "set-test-version", use: askForMoneyController.postSetTestVersionHandlerV2)
    app.post(api, v4, "money-info", ":password", use: askForMoneyController.postMoneyInfoHandlerV4)

    let donorsController = DonorsController()
    app.get(api, v3, "donor-names", use: donorsController.getDonorNamesHandlerV3)
    app.get(api, v3, "display-recurring-donation-banner", use: donorsController.getDisplayRecurringDonationBannerHandlerV3)
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
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        return .ok
    }
    //app.post(api, v2, "add-all-existing-devices-to-general-channel", use: notificationsController.postAddAllExistingDevicesToGeneralChannelHandlerV2)

    let soundsController = SoundsController()
    app.get(api, v3, "sound", ":id", use: soundsController.getSoundHandlerV3)
    app.get(api, v3, "all-sounds", use: soundsController.getAllSoundsHandlerV3)
    app.post(api, v3, "import-sounds", ":password", use: soundsController.postImportSoundsHandlerV3)
    app.post(api, v3, "create-sound", ":password", use: soundsController.postCreateSoundHandlerV3)
    app.delete(api, v3, "sound", ":id", ":password", use: soundsController.deleteSoundHandlerV3)

    let authorsController = AuthorsController()
    app.get(api, v3, "author", ":id", use: authorsController.getAuthorHandlerV3) // Links and no links
    app.get(api, v4, "author-links-first-open", use: authorsController.getAuthorLinksHandlerV4)
    app.get(api, v3, "all-authors", use: authorsController.getAllAuthorsHandlerV3)
    app.post(api, v3, "import-authors", ":password", use: authorsController.postImportAuthorsHandlerV3)
    app.post(api, v3, "create-author", ":password", use: authorsController.postCreateAuthorHandlerV3)
    app.put(api, v3, "update-author", ":password", use: authorsController.putUpdateAuthorHandlerV3)
    app.delete(api, v3, "author", ":id", ":password", use: authorsController.deleteAuthorHandlerV3)

    let songsController = SongsController()
    app.get(api, v3, "all-songs", use: songsController.getAllSongsHandlerV3)
    app.get(api, v3, "song", ":id", use: songsController.getSongHandlerV3)
    app.post(api, v3, "import-songs", ":password", use: songsController.postImportSongsHandlerV3)
    app.post(api, v3, "create-song", ":password", use: songsController.postCreateSongHandlerV3)
    app.delete(api, v3, "song", ":id", ":password", use: songsController.deleteSongHandlerV3)

    let genresController = MusicGenresController()
    app.get(api, v3, "music-genre", ":id", use: genresController.getMusicGenreHandlerV3)
    app.get(api, v3, "all-music-genres", use: genresController.getAllMusicGenresHandlerV3)
    app.post(api, v3, "import-music-genres", ":password", use: genresController.postImportMusicGenresHandlerV3)
    app.post(api, v3, "create-music-genre", ":password", use: genresController.postCreateMusicHandlerHandlerV3)
    app.delete(api, v3, "music-genre", ":id", ":password", use: genresController.deleteMusicGenreHandlerV3)

    let updateEventsController = UpdateEventsController()
    app.get(api, v3, "update-events", ":date", use: updateEventsController.getUpdateEventsHandlerV3)
    app.get(api, v3, "update-events-for-display", ":password", use: updateEventsController.getUpdateEventsForDisplayHandlerV3)
    app.put(api, v3, "change-update-visibility", ":updateId", ":newValue", ":password", use: updateEventsController.putChangeUpdateVisibilityHandlerV3)
    app.put(api, v3, "update-content", ":password", use: updateEventsController.putUpdateContentHandlerV3)
    app.post(api, v3, "update-content-file", ":type", ":id", ":password", use: updateEventsController.postUpdateContentFileHandlerV3)

    let retrospectiveController = RetrospectiveController()
    app.get(api, v4, "classic-retro-starting-version", use: retrospectiveController.getRetroStartingVersionHandlerV3)
    app.post(api, v4, "set-classic-retro-version", use: retrospectiveController.postSetRetroStartingVersionHandlerV3)

    let reactionsController = ReactionsController()
    app.get(api, v4, "reactions", use: reactionsController.getAllReactionsHandlerV4)
    app.get(api, v4, "reaction", ":reactionId", use: reactionsController.getReactionHandlerV4)
    app.get(api, v4, "reaction-sounds", ":reactionId", use: reactionsController.getReactionSoundsHandlerV4)
    app.get(api, v4, "reactions-for-sound", ":soundId", use: reactionsController.getReactionsForSoundHandler)
    app.post(api, v4, "create-reaction", ":password", use: reactionsController.postCreateReactionHandlerV4)
    app.post(api, v4, "add-sounds-to-reaction", ":password", use: reactionsController.postAddSoundsToReactionHandlerV4)
    app.put(api, v4, "reaction", ":password", use: reactionsController.putUpdateReactionHandlerV4)
    app.delete(api, v4, "delete-all-reactions", ":password", use: reactionsController.deleteAllReactionsHandlerV4)
    app.delete(api, v4, "delete-all-reaction-sounds", ":password", use: reactionsController.deleteAllReactionSoundsHandlerV4)
    app.delete(api, v4, "delete-reaction-sounds", ":id", ":password", use: reactionsController.deleteReactionSoundsHandlerV4)
    app.delete(api, v4, "delete-reaction", ":id", ":password", use: reactionsController.deleteReactionHandlerV4)

    let housekeepingController = HousekeepingController()
    app.post(api, v4, "replace-device-model-name", ":password", ":oldName", ":newName", use: housekeepingController.postReplaceDeviceModelNameHandlerV4)
    app.post(api, v4, "fix-song-stats", use: housekeepingController.postFixSongStatsHandlerV4)

    let dynamicBannerController = DynamicBannerController()
    app.get(api, v4, "dynamic-banner-dont-show-version", use: dynamicBannerController.getBannerDontShowVersionHandlerV4)
    app.get(api, v4, "dynamic-banner", use: dynamicBannerController.getBannerDataHandlerV4)
    app.post(api, v4, "set-dynamic-banner-dont-show-version", use: dynamicBannerController.postSetBannerDontShowVersionHandlerV4)
    app.post(api, v4, "dynamic-banner", ":password", use: dynamicBannerController.postSetBannerDataHandlerV4)
}
