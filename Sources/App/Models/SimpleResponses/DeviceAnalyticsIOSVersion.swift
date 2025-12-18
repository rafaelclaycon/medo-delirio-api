//
//  DeviceAnalyticsIOSVersion.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 22/11/25.
//

import Vapor

struct DeviceAnalyticsIOSVersion: Content {
    let id: String
    let major_version: String
    let count: Int
}

