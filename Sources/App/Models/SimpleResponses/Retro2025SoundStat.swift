//
//  Retro2025SoundStat.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 22/11/25.
//

import Vapor

struct Retro2025SoundStat: Content {
    let soundNumber: Int
    let soundName: String
    let shareCount: Int
}


