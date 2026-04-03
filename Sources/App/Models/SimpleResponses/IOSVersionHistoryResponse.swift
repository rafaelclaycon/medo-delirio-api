//
//  IOSVersionHistoryResponse.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 20/03/26.
//

import Vapor

struct IOSVersionHistoryResponse: Content {
    let major_version: String
    let history: [IOSVersionMonthlyCount]
}
