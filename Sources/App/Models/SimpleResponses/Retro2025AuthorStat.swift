//
//  Retro2025AuthorStat.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 22/11/25.
//

import Vapor

struct Retro2025AuthorStat: Content {
    let authorName: String
    let shareCount: Int
    let imageURL: String?
}


