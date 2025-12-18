//
//  DailyActiveUsersResponse.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 22/11/25.
//

import Vapor

struct DailyActiveUsersResponse: Content {

    let date: String
    let activeUsers: Int
}

