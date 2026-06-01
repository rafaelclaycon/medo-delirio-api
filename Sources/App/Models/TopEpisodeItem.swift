//
//  TopEpisodeItem.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 31/05/26.
//

import Foundation
import Vapor

struct TopEpisodeItem: Hashable, Codable, Identifiable, Content {

    let id: String
    let rankNumber: String
    let episodeId: String
    let episodeName: String
    let playCount: Int
    let uniqueListeners: Int

    init(
        id: String = UUID().uuidString,
        rankNumber: String,
        episodeId: String,
        episodeName: String,
        playCount: Int,
        uniqueListeners: Int
    ) {
        self.id = id
        self.rankNumber = rankNumber
        self.episodeId = episodeId
        self.episodeName = episodeName
        self.playCount = playCount
        self.uniqueListeners = uniqueListeners
    }
}
