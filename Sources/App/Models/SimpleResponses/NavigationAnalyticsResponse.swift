//
//  NavigationAnalyticsResponse.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 22/11/25.
//

import Vapor

struct NavigationAnalyticsResponse: Content {
    let top_screens: [NavigationAnalyticsScreen]
    let total_views: Int
}

