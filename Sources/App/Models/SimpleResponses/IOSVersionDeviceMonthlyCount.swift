//
//  IOSVersionDeviceMonthlyCount.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 20/03/26.
//

import Vapor

struct IOSVersionDeviceMonthlyCount: Content {
    let month: String
    let count: Int
}
