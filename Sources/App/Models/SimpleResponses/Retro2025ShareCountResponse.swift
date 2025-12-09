//
//  Retro2025ShareCountResponse.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 22/11/25.
//

import Vapor

struct Retro2025ShareCountResponse: Content {

    let shareCount: Int
    let date: String
}


