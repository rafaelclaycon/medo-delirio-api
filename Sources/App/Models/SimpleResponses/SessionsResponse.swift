//
//  SessionsResponse.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 22/11/25.
//

import Vapor

struct SessionsResponse: Content {

    let sessionsCount: Int
    let date: String
}

