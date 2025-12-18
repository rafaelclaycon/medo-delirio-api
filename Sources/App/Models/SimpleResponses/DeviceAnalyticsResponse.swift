//
//  DeviceAnalyticsResponse.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 22/11/25.
//

import Vapor

struct DeviceAnalyticsResponse: Content {
    let top_ios_versions: [DeviceAnalyticsIOSVersion]
    let top_device_models: [DeviceAnalyticsDeviceModel]
    let top_device_types: [DeviceAnalyticsDeviceType]
    let top_timezones: [DeviceAnalyticsTimezone]
    let total_timezones_count: Int
}

