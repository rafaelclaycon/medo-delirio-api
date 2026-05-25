//
//  Episode.swift
//  medo-delirio-api
//

import Fluent
import Vapor

final class Episode: Model, Content {

    static let schema = "Episode"

    /// Derived from the RSS GUID using the same parseEpisodeId logic as the iOS app.
    /// e.g. "69980761" from "https://api.spreaker.com/episode/69980761"
    @ID(custom: "id", generatedBy: .user)
    var id: String?

    @Field(key: "title")
    var title: String

    @OptionalField(key: "imageURL")
    var imageURL: String?

    @OptionalField(key: "pubDate")
    var pubDate: Date?

    init() { }

    init(id: String, title: String, imageURL: String? = nil, pubDate: Date? = nil) {
        self.id = id
        self.title = title
        self.imageURL = imageURL
        self.pubDate = pubDate
    }
}
