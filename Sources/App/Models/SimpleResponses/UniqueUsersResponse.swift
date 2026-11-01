//
//  UniqueUsersResponse.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 01/11/26.
//

import Vapor

/// Distinct installs with a still-alive signal, over three rolling windows.
struct UniqueUsersResponse: Content, Equatable {

    /// Signals in the last 7 days.
    let lastWeek: Int
    /// Signals in the last 30 days.
    let lastMonth: Int
    /// Every signal ever received.
    let allTime: Int
    let generatedAt: String
}
