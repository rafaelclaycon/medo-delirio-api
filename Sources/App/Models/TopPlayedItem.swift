//
//  TopPlayedItem.swift
//  medo-delirio-api
//
//  Created by Rafael Claycon Schmitt on 11/10/26.
//

import Foundation
import Vapor

/// One row of the most played sounds or songs. Shaped like `TopChartItem` so the app can
/// show it with the same row, with plays in place of shares.
struct TopPlayedItem: Hashable, Codable, Identifiable, Content {

    let id: String
    let rankNumber: String
    let contentId: String
    let contentName: String
    /// Empty for songs.
    let contentAuthorId: String
    /// The music genre for songs, as in the song share ranking.
    let contentAuthorName: String
    let playCount: Int
    let uniqueListeners: Int

    init(
        id: String = UUID().uuidString,
        rankNumber: String,
        contentId: String,
        contentName: String,
        contentAuthorId: String,
        contentAuthorName: String,
        playCount: Int,
        uniqueListeners: Int
    ) {
        self.id = id
        self.rankNumber = rankNumber
        self.contentId = contentId
        self.contentName = contentName
        self.contentAuthorId = contentAuthorId
        self.contentAuthorName = contentAuthorName
        self.playCount = playCount
        self.uniqueListeners = uniqueListeners
    }
}
