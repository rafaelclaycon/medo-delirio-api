//
//  VersionSignalsHourlyResponse.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 28/01/26.
//

import Vapor

struct VersionSignalsHourlyResponse: Content {
    let date: String
    let hours: [HourlyVersionData]
    let dayTotals: [VersionTotal]
}

struct HourlyVersionData: Content {
    let hour: Int
    let versions: [VersionSignal]
}

struct VersionSignal: Content {
    let appVersion: String
    let uniqueUsers: Int
    let signalCount: Int
}

struct VersionTotal: Content {
    let appVersion: String
    let uniqueUsers: Int
    let percentage: Double
}
