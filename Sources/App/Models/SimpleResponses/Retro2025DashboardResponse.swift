//
//  Retro2025DashboardResponse.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 22/11/25.
//

import Vapor

struct Retro2025DashboardResponse: Content {
    let overallStats: Retro2025OverallStats
    let topSounds: [Retro2025SoundStat]
    let topAuthors: [Retro2025AuthorStat]
    let dayPatterns: [Retro2025DayOfWeekStat]
    let topUsers: [Retro2025UserStat]
    let date: String?
    let startDate: String?
    let endDate: String?
}


