//
//  DeviceAnalyticsTimezone.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 22/11/25.
//

import Vapor

struct DeviceAnalyticsTimezone: Content {
    let id: String
    let timezone: String
    let count: Int
}

