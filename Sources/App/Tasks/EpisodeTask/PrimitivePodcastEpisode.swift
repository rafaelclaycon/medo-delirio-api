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
    var creationDate: String
    var spotifyLink: String
    var applePodcastsLink: String
    var pocketCastsLink: String
    
    init(episodeId: String,
         title: String,
         description: String,
         pubDate: String,
         duration: Double,
         creationDate: String,
         spotifyLink: String,
         applePodcastsLink: String,
         pocketCastsLink: String) {
        self.episodeId = episodeId
        self.title = title
        self.description = description
        self.pubDate = pubDate
        self.duration = duration
        self.creationDate = creationDate
        self.spotifyLink = spotifyLink
        self.applePodcastsLink = applePodcastsLink
        self.pocketCastsLink = pocketCastsLink
    }

}
