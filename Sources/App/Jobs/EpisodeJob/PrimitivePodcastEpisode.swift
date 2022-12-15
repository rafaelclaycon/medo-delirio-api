//
//  PrimitivePodcastEpisode.swift
//  medo-delirio-api
//
//  Created by Rafael Claycon Schmitt on 14/12/22.
//

import Foundation

struct PrimitivePodcastEpisode: Hashable, Codable, Identifiable {

    var id: String { episodeId }
    var episodeId: String
    var title: String
    var description: String
    var pubDate: String
    var duration: Double
    
    init(episodeId: String,
         title: String,
         description: String,
         pubDate: String,
         duration: Double) {
        self.episodeId = episodeId
        self.title = title
        self.description = description
        self.pubDate = pubDate
        self.duration = duration
    }

}
