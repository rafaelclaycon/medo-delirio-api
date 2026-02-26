//
//  EpisodeAnalyticsResponse.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 26/02/26.
//

import Vapor

struct EpisodeAnalyticsResponse: Content {

    let dailyUniqueUsers: [DailyActiveUsersResponse]
    let totalUniqueUsers: Int
    let usersWhoPlayed: Int
    let usersWhoBookmarked: Int
    let averagePlaysPerUser: Double
    let averageBookmarksPerUser: Double
}
