//
//  Retro2025UserStat.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 22/11/25.
//

import Vapor

struct Retro2025UserStat: Content {
    let userId: String
    let totalShares: Int
    let mostActiveDay: String?
}


