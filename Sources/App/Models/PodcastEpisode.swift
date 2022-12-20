//
//  PodcastEpisode.swift
//  medo-delirio-api
//
//  Created by Rafael Claycon Schmitt on 15/12/22.
//

import Fluent
import Vapor

final class PodcastEpisode: Model, Content {

    static let schema = "PodcastEpisode"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "episodeId")
    var episodeId: String
    
    @Field(key: "title")
    var title: String
    
    @Field(key: "description")
    var description: String
    
    @Field(key: "pubDate")
    var pubDate: String
    
    @Field(key: "duration")
    var duration: Double
    
    @Field(key: "creationDate")
    var creationDate: String
    
    @Field(key: "spotifyLink")
    var spotifyLink: String
    
    @Field(key: "applePodcastsLink")
    var applePodcastsLink: String
    
    @Field(key: "pocketCastsLink")
    var pocketCastsLink: String
    
    init() { }
    
    init(id: UUID? = nil,
         episodeId: String,
         title: String,
         description: String,
         pubDate: String,
         duration: Double,
         creationDate: String,
         spotifyLink: String,
         applePodcastsLink: String,
         pocketCastsLink: String) {
        self.id = id
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
