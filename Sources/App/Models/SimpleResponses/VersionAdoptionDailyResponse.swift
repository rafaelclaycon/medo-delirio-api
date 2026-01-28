//
//  VersionAdoptionDailyResponse.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 28/01/26.
//

import Vapor

struct VersionAdoptionDailyResponse: Content {
    let days: Int
    let data: [DailyVersionData]
}

struct DailyVersionData: Content {
    let date: String
    let versions: [DailyVersionStat]
}

struct DailyVersionStat: Content {
    let appVersion: String
    let uniqueUsers: Int
}
