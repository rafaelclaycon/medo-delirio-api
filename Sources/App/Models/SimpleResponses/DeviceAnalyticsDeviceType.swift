//
//  DeviceAnalyticsDeviceType.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 22/11/25.
//

import Vapor

struct DeviceAnalyticsDeviceType: Content {
    let id: String
    let device_type: String
    let count: Int
}

