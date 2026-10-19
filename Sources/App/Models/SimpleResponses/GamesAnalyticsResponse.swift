//
//  GamesAnalyticsResponse.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 18/10/26.
//

import Vapor

/// Usage of the games, for the features tab in MedoHelper. Percentages go from 0 to 100,
/// rounded to 2 decimals, and are `0` when their denominator is.
struct GamesAnalyticsResponse: Content, Equatable {

    /// Window length in UTC days, today included.
    let days: Int
    /// Start of the window: midnight UTC, `days - 1` days before today.
    let since: String
    /// Distinct installs with a still-alive signal in the window, any version.
    let activeUsers: Int
    /// Active installs that ran a version with games (13.6 or later) in the window.
    let activeUsersWithGames: Int
    /// Distinct installs that started a game in the window.
    let players: Int
    /// `players / activeUsersWithGames * 100`.
    let playerPercentage: Double
    /// Players who started a game on two or more UTC days of the window.
    let returningPlayers: Int
    /// Players who finished at least one game.
    let finishers: Int
    let starts: Int
    let finishes: Int
    let abandons: Int
    /// `finishes / starts * 100`. Finishes and abandons don't add up to starts: a game the
    /// app was closed in the middle of sends neither.
    let completionPercentage: Double
    /// One per game, most players first.
    let games: [GamesAnalyticsGame]
    /// One per UTC day of the window, oldest first.
    let daily: [GamesAnalyticsDay]
    let shares: Int
    /// Shares by image format ("square", "stories"), most first.
    let sharesByFormat: [GamesAnalyticsNameCount]
    /// Shares by iOS activity type, most first, at most 10.
    let sharesByDestination: [GamesAnalyticsNameCount]
    /// Face game only.
    let musicMutedCount: Int
    let musicUnmutedCount: Int
    /// Author photos that failed to load in a round, most first, at most 20.
    let brokenAuthorPhotos: [GamesAnalyticsNameCount]
    /// Donation sheets opened from the games card.
    let supportSheetShownCount: Int
    let generatedAt: String
}

struct GamesAnalyticsGame: Content, Equatable {

    /// "whoseFace" or "whoseVoice".
    let game: String
    let players: Int
    let starts: Int
    let finishes: Int
    let abandons: Int
    let completionPercentage: Double
    /// Points in `whoseFace` (about 0 to 10,000), correct answers in `whoseVoice`.
    /// `nil` without finishes.
    let averageScore: Double?
    let averageHits: Double?
    /// Average time to answer a round, over the finishes that report it. A high one
    /// suggests the game is too hard.
    let averageSecondsPerRound: Double?
    let newRecords: Int
    /// Finishes by number of correct answers, fewest hits first.
    let hitsDistribution: [GamesAnalyticsHitsCount]
    /// Abandons by the round people left in, first round first.
    let abandonsByRound: [GamesAnalyticsRoundCount]
    let shares: Int
}

struct GamesAnalyticsHitsCount: Content, Equatable {

    let hits: Int
    let finishes: Int
}

struct GamesAnalyticsRoundCount: Content, Equatable {

    let round: Int
    let abandons: Int
    /// Abandons that came after answering the round.
    let answered: Int
}

struct GamesAnalyticsDay: Content, Equatable {

    /// "yyyy-MM-dd", UTC.
    let date: String
    /// Distinct installs that started a game that day.
    let players: Int
    /// Players whose first start in the window falls on that day.
    let newPlayers: Int
    let starts: Int
    let finishes: Int
}

struct GamesAnalyticsNameCount: Content, Equatable {

    let name: String
    let count: Int
}

extension GamesAnalyticsResponse {

    /// Adds up the games events. No database here, so the counting is unit tested.
    ///
    /// - Parameters:
    ///   - events: The events in the window, any order.
    ///   - dayList: Every UTC day of the window, oldest first, so days nobody played
    ///     still show up with zeros.
    init(
        events: [GameUsageEvent],
        dayList: [String],
        since: String,
        activeUsers: Int,
        activeUsersWithGames: Int,
        generatedAt: String
    ) {
        let sorted = events.sorted { $0.dateTime < $1.dateTime }

        var startDays: [String: Set<String>] = [:]
        var firstStartDay: [String: String] = [:]
        var finisherIds: Set<String> = []
        var starts = 0
        var finishes = 0
        var abandons = 0
        var formats: [String: Int] = [:]
        var destinations: [String: Int] = [:]
        var shares = 0
        var muted = 0
        var unmuted = 0
        var brokenPhotos: [String: Int] = [:]
        var supportSheets = 0
        var dailyPlayers: [String: Set<String>] = [:]
        var dailyStarts: [String: Int] = [:]
        var dailyFinishes: [String: Int] = [:]

        for event in sorted {
            switch event.action {
            case .started:
                starts += 1
                startDays[event.installId, default: []].insert(event.day)
                if firstStartDay[event.installId] == nil {
                    firstStartDay[event.installId] = event.day
                }
                dailyPlayers[event.day, default: []].insert(event.installId)
                dailyStarts[event.day, default: 0] += 1
            case .finished:
                finishes += 1
                finisherIds.insert(event.installId)
                dailyFinishes[event.day, default: 0] += 1
            case .abandoned:
                abandons += 1
            case .shared(_, let format, let destination):
                shares += 1
                formats[format, default: 0] += 1
                destinations[destination, default: 0] += 1
            case .musicMuted:
                muted += 1
            case .musicUnmuted:
                unmuted += 1
            case .brokenAuthorPhoto(let authorId):
                brokenPhotos[authorId, default: 0] += 1
            case .supportSheetShown:
                supportSheets += 1
            }
        }

        var newPlayersByDay: [String: Int] = [:]
        for day in firstStartDay.values {
            newPlayersByDay[day, default: 0] += 1
        }

        let byGame = Dictionary(grouping: sorted.filter { $0.game != nil }) { $0.game ?? "" }
        let games = byGame
            .map { GamesAnalyticsGame(game: $0.key, events: $0.value) }
            .sorted { ($0.players, $1.game) > ($1.players, $0.game) }

        self.days = dayList.count
        self.since = since
        self.activeUsers = activeUsers
        self.activeUsersWithGames = activeUsersWithGames
        self.players = startDays.count
        self.playerPercentage = Self.percentage(startDays.count, of: activeUsersWithGames)
        self.returningPlayers = startDays.values.filter { $0.count >= 2 }.count
        self.finishers = finisherIds.count
        self.starts = starts
        self.finishes = finishes
        self.abandons = abandons
        self.completionPercentage = Self.percentage(finishes, of: starts)
        self.games = games
        self.daily = dayList.map { day in
            GamesAnalyticsDay(
                date: day,
                players: dailyPlayers[day]?.count ?? 0,
                newPlayers: newPlayersByDay[day] ?? 0,
                starts: dailyStarts[day] ?? 0,
                finishes: dailyFinishes[day] ?? 0
            )
        }
        self.shares = shares
        self.sharesByFormat = Self.ranked(formats)
        self.sharesByDestination = Self.ranked(destinations, limit: 10)
        self.musicMutedCount = muted
        self.musicUnmutedCount = unmuted
        self.brokenAuthorPhotos = Self.ranked(brokenPhotos, limit: 20)
        self.supportSheetShownCount = supportSheets
        self.generatedAt = generatedAt
    }

    static func percentage(_ part: Int, of whole: Int) -> Double {
        guard whole > 0 else { return 0 }
        return rounded(Double(part) / Double(whole) * 100)
    }

    static func rounded(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }

    /// Most first, ties by name so the order is stable.
    private static func ranked(_ counts: [String: Int], limit: Int? = nil) -> [GamesAnalyticsNameCount] {
        let ranked = counts
            .map { GamesAnalyticsNameCount(name: $0.key, count: $0.value) }
            .sorted { ($0.count, $1.name) > ($1.count, $0.name) }
        guard let limit else { return ranked }
        return Array(ranked.prefix(limit))
    }
}

extension GamesAnalyticsGame {

    /// - Parameter events: Only this game's events.
    init(game: String, events: [GameUsageEvent]) {
        var players: Set<String> = []
        var starts = 0
        var abandons = 0
        var shares = 0
        var newRecords = 0
        var scores: [Int] = []
        var hits: [Int] = []
        var seconds: [Double] = []
        var hitsCounts: [Int: Int] = [:]
        var rounds: [Int: (abandons: Int, answered: Int)] = [:]

        for event in events {
            switch event.action {
            case .started:
                starts += 1
                players.insert(event.installId)
            case .finished(_, let score, let hitCount, _, let averageSeconds, let isNewRecord):
                scores.append(score)
                hits.append(hitCount)
                if let averageSeconds { seconds.append(averageSeconds) }
                if isNewRecord { newRecords += 1 }
                hitsCounts[hitCount, default: 0] += 1
            case .abandoned(_, let round, _, let answered):
                abandons += 1
                rounds[round, default: (0, 0)].abandons += 1
                if answered { rounds[round, default: (0, 0)].answered += 1 }
            case .shared:
                shares += 1
            case .musicMuted, .musicUnmuted, .brokenAuthorPhoto, .supportSheetShown:
                break
            }
        }

        func average<T: BinaryInteger>(_ values: [T]) -> Double? {
            values.isEmpty ? nil : GamesAnalyticsResponse.rounded(Double(values.reduce(0, +)) / Double(values.count))
        }

        self.game = game
        self.players = players.count
        self.starts = starts
        self.finishes = scores.count
        self.abandons = abandons
        self.completionPercentage = GamesAnalyticsResponse.percentage(scores.count, of: starts)
        self.averageScore = average(scores)
        self.averageHits = average(hits)
        self.averageSecondsPerRound = seconds.isEmpty
            ? nil
            : GamesAnalyticsResponse.rounded(seconds.reduce(0, +) / Double(seconds.count))
        self.newRecords = newRecords
        self.hitsDistribution = hitsCounts
            .map { GamesAnalyticsHitsCount(hits: $0.key, finishes: $0.value) }
            .sorted { $0.hits < $1.hits }
        self.abandonsByRound = rounds
            .map { GamesAnalyticsRoundCount(round: $0.key, abandons: $0.value.abandons, answered: $0.value.answered) }
            .sorted { $0.round < $1.round }
        self.shares = shares
    }
}
