//
//  Retro2025OverallStats.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 22/11/25.
//

import Vapor

struct Retro2025OverallStats: Content {
    let totalShares: Int
    let uniqueUsers: Int
    let averageSharesPerUser: Double
    let startDate: String?
    let endDate: String?
}


