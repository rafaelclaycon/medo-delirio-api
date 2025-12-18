//
//  DeviceAnalyticsDeviceModel.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 22/11/25.
//

import Vapor

struct DeviceAnalyticsDeviceModel: Content {
    let id: String
    let model_name: String
    let count: Int
}

