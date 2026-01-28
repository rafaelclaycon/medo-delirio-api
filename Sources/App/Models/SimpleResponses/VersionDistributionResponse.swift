//
//  VersionDistributionResponse.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 28/01/26.
//

import Vapor

struct VersionDistributionResponse: Content {
    let date: String
    let versions: [VersionDistributionStat]
    let totalUsers: Int
}

struct VersionDistributionStat: Content {
    let appVersion: String
    let uniqueUsers: Int
    let percentage: Double
}
