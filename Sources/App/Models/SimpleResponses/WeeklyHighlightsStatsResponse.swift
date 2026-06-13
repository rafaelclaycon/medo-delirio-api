//
//  WeeklyHighlightsStatsResponse.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 12/06/26.
//

import Vapor

struct WeeklyHighlightsStatsResponse: Content {

    /// Devices currently subscribed to the `weekly_highlights` channel.
    let currentSubscriberCount: Int

    /// All-time count of subscribe events for the channel (since event logging began).
    let totalSubscribes: Int

    /// All-time count of unsubscribe events for the channel (since event logging began).
    let totalUnsubscribes: Int

    /// One entry per broadcast, most recent first.
    let sends: [WeeklyHighlightsSendStat]
}

struct WeeklyHighlightsSendStat: Content {

    let weekNumber: Int
    let notificationType: String
    let topContentName: String
    let sentCount: Int
    let dateTime: String
}
