import Fluent
import Vapor

/// One row per Weekly Highlights notification broadcast. Lets us report how many
/// highlights were sent each week, since `WeeklyHighlightsSendResult` is otherwise
/// ephemeral (returned in the HTTP response and logged, never persisted).
final class WeeklyHighlightLog: Model, Content {

    static let schema = "WeeklyHighlightLog"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "weekNumber")
    var weekNumber: Int

    @Field(key: "notificationType")
    var notificationType: String

    @Field(key: "topContentName")
    var topContentName: String

    @Field(key: "sentCount")
    var sentCount: Int

    @Field(key: "dateTime")
    var dateTime: String

    init() { }

    init(
        id: UUID? = nil,
        weekNumber: Int,
        notificationType: String,
        topContentName: String,
        sentCount: Int,
        dateTime: String
    ) {
        self.id = id
        self.weekNumber = weekNumber
        self.notificationType = notificationType
        self.topContentName = topContentName
        self.sentCount = sentCount
        self.dateTime = dateTime
    }
}
