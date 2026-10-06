//
//  EpisodeAnalyticsResponse.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 26/02/26.
//

import Vapor

struct EpisodeAnalyticsResponse: Content {

    let dailyUniqueUsers: [DailyActiveUsersResponse]
    /// Installs that played at least one episode in the last 30 days.
    let totalUniqueUsers: Int
    /// Installs that played, viewed the episodes screen or bookmarked (any episode activity).
    let totalViewers: Int
    let usersWhoPlayed: Int
    let usersWhoBookmarked: Int
    let averagePlaysPerUser: Double
    let averageBookmarksPerUser: Double
}
