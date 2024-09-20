//
//  ContentShareCountStats.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 20/09/24.
//

import Vapor

struct ContentShareCountStats: Content {

    let contentId: String
    let totalShareCount: Int
    let lastWeekShareCount: Int
}
