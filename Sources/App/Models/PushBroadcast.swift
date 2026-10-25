import Vapor

/// A plain alert written by hand in MedoHelper and sent to every device. Tapping it just
/// opens the app. Typed pushes (new episode, weekly highlights, content sync) are only
/// sent by the server itself.
struct PushBroadcastRequest: Content {
    let title: String
    let body: String
}

struct PushBroadcastStatus: Content, Equatable {

    enum State: String, Codable, Sendable {
        case sending, finished, cancelled
    }

    let id: UUID
    let title: String
    let body: String
    var state: State
    /// Devices with a push token when the broadcast started.
    let total: Int
    /// `sent + failed + removedTokens`, so clients don't have to add them up.
    var processed: Int
    var sent: Int
    var failed: Int
    /// Tokens APNs rejected as unregistered, bad or for another topic, whose devices were deleted.
    var removedTokens: Int
    let startedAt: Date
    var finishedAt: Date?
    /// The last few failures, newest last.
    var recentErrors: [String]
}

struct PushAudience: Content {
    let deviceCount: Int
}
