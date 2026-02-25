import Fluent
import Vapor

final class LastKnownEpisode: Model, Content {

    static let schema = "LastKnownEpisode"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "feedURL")
    var feedURL: String

    @Field(key: "episodeGUID")
    var episodeGUID: String

    @Field(key: "episodeTitle")
    var episodeTitle: String

    @Field(key: "checkCount")
    var checkCount: Int

    @Field(key: "checkedAt")
    var checkedAt: Date

    @OptionalField(key: "episodeChangedAt")
    var episodeChangedAt: Date?

    init() { }

    init(
        id: UUID? = nil,
        feedURL: String,
        episodeGUID: String,
        episodeTitle: String,
        checkCount: Int = 1,
        checkedAt: Date = Date(),
        episodeChangedAt: Date? = nil
    ) {
        self.id = id
        self.feedURL = feedURL
        self.episodeGUID = episodeGUID
        self.episodeTitle = episodeTitle
        self.checkCount = checkCount
        self.checkedAt = checkedAt
        self.episodeChangedAt = episodeChangedAt
    }
}
