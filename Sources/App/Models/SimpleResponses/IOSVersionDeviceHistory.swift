//
//  IOSVersionDeviceHistory.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 20/03/26.
//

import Vapor

struct IOSVersionDeviceHistory: Content {
    let model_name: String
    let history: [IOSVersionDeviceMonthlyCount]
}
