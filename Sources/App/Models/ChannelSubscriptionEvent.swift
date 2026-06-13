import Fluent
import Vapor

/// Append-only log of channel subscribe/unsubscribe actions. The `DeviceChannel`
/// pivot is hard-deleted on unsubscribe, so without this log churn is unrecoverable —
/// it lets us count unsubscribes (and subscribes) over time per channel.
final class ChannelSubscriptionEvent: Model, Content {

    static let schema = "ChannelSubscriptionEvent"

    enum Action {
        static let subscribe = "subscribe"
        static let unsubscribe = "unsubscribe"
    }

    @ID(key: .id)
    var id: UUID?

    @Field(key: "installId")
    var installId: String

    @Field(key: "channelId")
    var channelId: String

    @Field(key: "action")
    var action: String

    @Field(key: "dateTime")
    var dateTime: String

    init() { }

    init(
        id: UUID? = nil,
        installId: String,
        channelId: String,
        action: String,
        dateTime: String
    ) {
        self.id = id
        self.installId = installId
        self.channelId = channelId
        self.action = action
        self.dateTime = dateTime
    }
}
