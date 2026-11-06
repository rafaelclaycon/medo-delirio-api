//
//  routes.swift
//  medo-delirio-api
//
//  Created by Rafael Claycon Schmitt on 01/06/22.
//

import Vapor

/// Each controller registers its own routes in `boot(routes:)`, at the end of its file.
/// `RoutesTests` lists every path the API serves.
func routes(_ app: Application) throws {
    try app.register(collection: ShareController())
    try app.register(collection: StatusCheckController())
    try app.register(collection: StatisticsController())
    try app.register(collection: PlayLogController())
    try app.register(collection: WidgetSummaryController())
    try app.register(collection: AskForMoneyController())
    try app.register(collection: DonorsController())
    try app.register(collection: ClientLoggingController())
    try app.register(collection: NotificationsController())
    try app.register(collection: PushBroadcastController())
    try app.register(collection: SoundsController())
    try app.register(collection: AuthorsController())
    try app.register(collection: SongsController())
    try app.register(collection: MusicGenresController())
    try app.register(collection: UpdateEventsController())
    try app.register(collection: RetrospectiveController())
    try app.register(collection: ReactionsController())
    try app.register(collection: HousekeepingController())
    try app.register(collection: RSSStatusController())
    try app.register(collection: DynamicBannerController())
    try app.register(collection: EpisodeHighlightController())
    try app.register(collection: RetroBannerController())
    try app.register(collection: ElectionController())
}
