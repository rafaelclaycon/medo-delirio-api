//
//  DeviceModelHistoryResponse.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 20/03/26.
//

import Vapor

struct DeviceModelHistoryResponse: Content {
    let model_name: String
    let history: [DeviceModelMonthlyCount]
}
