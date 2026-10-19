//
//  GameUsageEvent.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 18/10/26.
//

import Foundation

/// One games event from `UsageMetric`. The app packs the event's parameters into
/// `destinationScreen` (e.g. "didAbandonGame(whoseFace, round: 3, of: 10, answered: false)"),
/// so they're parsed here. No Vapor, so the parsing is unit tested.
struct GameUsageEvent: Equatable {

    enum Action: Equatable {
        case started(game: String)
        /// `score` is points (about 0 to 10,000) in `whoseFace` and correct answers in
        /// `whoseVoice`, where it equals `hits`. `averageSeconds` is the time to answer a
        /// round, `nil` when the app couldn't measure it.
        case finished(game: String, score: Int, hits: Int, rounds: Int, averageSeconds: Double?, isNewRecord: Bool)
        /// `answered` tells whether the round being played was already answered.
        case abandoned(game: String, round: Int, totalRounds: Int, answered: Bool)
        case musicMuted
        case musicUnmuted
        case brokenAuthorPhoto(authorId: String)
        /// `destination` is the iOS activity type, or "unknown".
        case shared(game: String, format: String, destination: String)
        case supportSheetShown
    }

    /// Games first ship in this version.
    static let firstAppVersion = "13.6"

    static let gameScreen = "GameView"
    static let shareScreen = "GameShareView"
    static let supportScreen = "SupportPrompt"
    static let supportSheetShown = "support_sheet_shown(trigger=games)"

    let installId: String
    /// ISO 8601 in UTC, as the app sends it.
    let dateTime: String
    let action: Action

    /// The UTC day, "yyyy-MM-dd".
    var day: String { String(dateTime.prefix(10)) }

    var game: String? {
        switch action {
        case .started(let game),
             .finished(let game, _, _, _, _, _),
             .abandoned(let game, _, _, _),
             .shared(let game, _, _):
            return game
        case .musicMuted, .musicUnmuted, .brokenAuthorPhoto, .supportSheetShown:
            return nil
        }
    }

    init(installId: String, dateTime: String, action: Action) {
        self.installId = installId
        self.dateTime = dateTime
        self.action = action
    }

    /// `nil` for a row that isn't a games event or doesn't parse.
    init?(installId: String, originatingScreen: String, destinationScreen: String, dateTime: String) {
        guard let action = Self.action(originatingScreen: originatingScreen, destinationScreen: destinationScreen) else {
            return nil
        }
        self.init(installId: installId, dateTime: dateTime, action: action)
    }

    private static func action(originatingScreen: String, destinationScreen event: String) -> Action? {
        switch originatingScreen {
        case gameScreen:
            if event == "game_music_muted" { return .musicMuted }
            if event == "game_music_unmuted" { return .musicUnmuted }
            if let match = event.wholeMatch(of: /didStartGame\((\w+)\)/) {
                return .started(game: String(match.1))
            }
            if let match = event.wholeMatch(of: /didFinishGame\((\w+), score: (\d+), hits: (\d+), rounds: (\d+), avgSeconds: ([\d.]+|nil), newRecord: (true|false)\)/),
               let score = Int(match.2), let hits = Int(match.3), let rounds = Int(match.4) {
                return .finished(
                    game: String(match.1),
                    score: score,
                    hits: hits,
                    rounds: rounds,
                    averageSeconds: Double(match.5),
                    isNewRecord: match.6 == "true"
                )
            }
            if let match = event.wholeMatch(of: /didAbandonGame\((\w+), round: (\d+), of: (\d+), answered: (true|false)\)/),
               let round = Int(match.2), let totalRounds = Int(match.3) {
                return .abandoned(game: String(match.1), round: round, totalRounds: totalRounds, answered: match.4 == "true")
            }
            if let match = event.wholeMatch(of: /didFindBrokenAuthorPhoto\((.+)\)/) {
                return .brokenAuthorPhoto(authorId: String(match.1))
            }
            return nil
        case shareScreen:
            guard let match = event.wholeMatch(of: /didShareGameResult\((\w+), format: (\w+), to: (.+)\)/) else {
                return nil
            }
            return .shared(game: String(match.1), format: String(match.2), destination: String(match.3))
        case supportScreen:
            return event == supportSheetShown ? .supportSheetShown : nil
        default:
            return nil
        }
    }

    /// Compares dotted versions number by number, so "13.10" comes after "13.6".
    static func appVersion(_ version: String, isAtLeast minimum: String) -> Bool {
        func numbers(_ version: String) -> [Int] {
            version.split(separator: ".").map { Int($0) ?? 0 }
        }
        let lhs = numbers(version)
        let rhs = numbers(minimum)
        for index in 0..<max(lhs.count, rhs.count) {
            let left = index < lhs.count ? lhs[index] : 0
            let right = index < rhs.count ? rhs[index] : 0
            if left != right { return left > right }
        }
        return true
    }
}
