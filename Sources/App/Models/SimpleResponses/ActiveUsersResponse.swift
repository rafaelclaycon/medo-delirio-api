//
//  ActiveUsersResponse.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 22/11/25.
//

import Vapor

struct ActiveUsersResponse: Content {

    let activeUsers: Int
    let date: String
}

