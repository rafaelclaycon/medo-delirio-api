//
//  NavigationAnalyticsScreen.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 22/11/25.
//

import Vapor

struct NavigationAnalyticsScreen: Content {
    let id: String
    let screen_name: String
    let view_count: Int
}

