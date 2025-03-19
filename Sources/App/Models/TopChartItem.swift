//
//  TopChartItem.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 03/12/23.
//

import Foundation
import Vapor

struct TopChartItem: Hashable, Codable, Identifiable, Content {

    let id: String
    let rankNumber: String
    let contentId: String
    let contentName: String
    let contentAuthorId: String
    let contentAuthorName: String
    let shareCount: Int

    init(
        id: String = UUID().uuidString,
        rankNumber: String,
        contentId: String,
        contentName: String,
        contentAuthorId: String,
        contentAuthorName: String,
        shareCount: Int
    ) {
        self.id = id
        self.rankNumber = rankNumber
        self.contentId = contentId
        self.contentName = contentName
        self.contentAuthorId = contentAuthorId
        self.contentAuthorName = contentAuthorName
        self.shareCount = shareCount
    }
}

struct TopChartReaction: Hashable, Codable, Content {

    let position: String
    let reaction: Reaction
    let description: String
}
