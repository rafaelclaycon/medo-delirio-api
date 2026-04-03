//
//  IOSVersionMonthlyCount.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 20/03/26.
//

import Vapor

struct IOSVersionMonthlyCount: Content {
    let month: String
    let count: Int
    let total: Int
}
