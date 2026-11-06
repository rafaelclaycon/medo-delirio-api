//
//  Retro2026AnalyticsResponse.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 05/11/26.
//

import Vapor

/// How the Retrospectiva 2026 is doing, for the features tab in MedoHelper. People are
/// counted by install. Percentages go from 0 to 100, rounded to 2 decimals, and are `0`
/// when their denominator is.
struct Retro2026AnalyticsResponse: Content, Equatable {

    /// The first 2026 event, `nil` before any.
    let firstEventAt: String?
    let funnel: Retro2026Funnel
    /// `didShowRetroBanner` rows: the app launches the banner was seen in.
    let bannerImpressions: Int
    let opens: Int
    let closes: Int
    /// Closes before the data loaded. Part of `closes`.
    let closesBeforeLoading: Int
    /// `opens - closes`, at least 0: mostly the app killed with the Stories open.
    let opensWithoutClose: Int
    let shareTaps: Int
    /// Closes by furthest page, `loading` first, then the pages in display order.
    let dropOff: [Retro2026PageDropOff]
    /// One per UTC day from the first event to today, oldest first.
    let daily: [Retro2026Day]
    /// Newest version first.
    let byAppVersion: [Retro2026Breakdown]
    /// Most shown first.
    let bySystemName: [Retro2026Breakdown]
    /// "false" (iPhone and iPad) first, then "true" (iPhone app on a Mac).
    let byMac: [Retro2026Breakdown]
    /// From the stats strings sent with the share taps.
    let stats: RetroStatsSummary
    let comparison: Retro2025Comparison
    let generatedAt: String
}

/// Distinct installs at each step.
struct Retro2026Funnel: Content, Equatable {

    let shown: Int
    let opened: Int
    /// Closed on the `share` page, or tapped share.
    let reachedEnd: Int
    let tappedShare: Int
    let dismissed: Int
    /// `opened / shown * 100`.
    let openRate: Double
    /// `reachedEnd / opened * 100`.
    let completionRate: Double
    /// `tappedShare / opened * 100`.
    let shareRate: Double
    /// `dismissed / shown * 100`.
    let dismissRate: Double
}

struct Retro2026PageDropOff: Content, Equatable {

    let page: String
    let closeButton: Int
    let swipeDown: Int
    let tappedPastEnd: Int
    /// A reason the app doesn't send today.
    let other: Int
    let total: Int
}

struct Retro2026Day: Content, Equatable {

    /// "yyyy-MM-dd", UTC.
    let date: String
    /// Distinct installs per step that day.
    let shown: Int
    let opened: Int
    let tappedShare: Int
}

/// Distinct installs per step for one value. An install that changed value (updated the
/// app, say) counts under each.
struct Retro2026Breakdown: Content, Equatable {

    let name: String
    let shown: Int
    let opened: Int
    let tappedShare: Int
}

/// What the shared images showed. Each install counts once, with its latest stats string,
/// so tapping share again doesn't weigh more.
struct RetroStatsSummary: Content, Equatable {

    /// Stats strings received: one per share tap.
    let shareTaps: Int
    /// Distinct installs that sent one.
    let people: Int
    /// The #1 Vírgula, most people first, at most 10.
    let topFirstSounds: [RetroNameCount]
    /// Vírgulas anywhere in the top 5, at most 10.
    let topSounds: [RetroNameCount]
    /// At most 10.
    let topAuthors: [RetroNameCount]
    let withoutAuthor: Int
    /// Monday first; "Nunca" last for people who never shared.
    let favoriteDays: [RetroNameCount]
    /// People per range of shares in the year.
    let shareCounts: [RetroNameCount]
    let medianShareCount: Int?
    /// People per range of listening minutes, among those with episodes. Empty in 2025.
    let listeningMinutes: [RetroNameCount]
    let withoutEpisodes: Int
    let medianListeningMinutes: Int?
    /// At most 10.
    let topEpisodes: [RetroNameCount]
}

/// 2025 sent only the stats string, so only share taps and what they showed compare.
struct Retro2025Comparison: Content, Equatable {

    /// Share taps per day since each year's first one, day 0 first.
    let daily: [RetroComparisonDay]
    let retro2025: RetroStatsSummary
}

struct RetroComparisonDay: Content, Equatable {

    /// Days since that year's first share tap.
    let day: Int
    let retro2025: Int
    let retro2026: Int
}

struct RetroNameCount: Content, Equatable {

    let name: String
    let count: Int
}

extension Retro2026AnalyticsResponse {

    /// Adds up the Retrospectiva events. No database here, so the counting is unit tested.
    ///
    /// - Parameters:
    ///   - events: The 2026 events, any order.
    ///   - events2025: The 2025 stats strings, any order.
    ///   - today: The UTC day "yyyy-MM-dd" the daily lists run to.
    init(events: [RetroUsageEvent], events2025: [RetroUsageEvent], today: String, generatedAt: String) {
        let sorted = events.sorted { $0.dateTime < $1.dateTime }

        var shown: Set<String> = []
        var opened: Set<String> = []
        var reachedEnd: Set<String> = []
        var tappedShare: Set<String> = []
        var dismissed: Set<String> = []
        var impressions = 0
        var opens = 0
        var closes = 0
        var closesBeforeLoading = 0
        var shareTaps = 0
        var reasonsByPage: [String: [String: Int]] = [:]
        var dailyShown: [String: Set<String>] = [:]
        var dailyOpened: [String: Set<String>] = [:]
        var dailyTapped: [String: Set<String>] = [:]
        var versions: [String: Steps] = [:]
        var systems: [String: Steps] = [:]
        var macs: [String: Steps] = [:]

        for event in sorted {
            let id = event.installId
            let step: WritableKeyPath<Steps, Set<String>>?
            switch event.action {
            case .bannerShown:
                impressions += 1
                shown.insert(id)
                dailyShown[event.day, default: []].insert(id)
                step = \.shown
            case .openedFromBanner:
                opens += 1
                opened.insert(id)
                dailyOpened[event.day, default: []].insert(id)
                step = \.opened
            case .bannerDismissed:
                dismissed.insert(id)
                step = nil
            case .closed(let page, _, _, let reason):
                closes += 1
                if page == RetroUsageEvent.loadingPage { closesBeforeLoading += 1 }
                if page == RetroUsageEvent.lastPage { reachedEnd.insert(id) }
                reasonsByPage[page, default: [:]][reason, default: 0] += 1
                step = nil
            case .shareTapped:
                shareTaps += 1
                tappedShare.insert(id)
                reachedEnd.insert(id)
                dailyTapped[event.day, default: []].insert(id)
                step = \.tappedShare
            case .stats:
                step = nil
            }
            if let step {
                versions[event.appVersion, default: Steps()][keyPath: step].insert(id)
                systems[event.systemName, default: Steps()][keyPath: step].insert(id)
                macs[event.isiOSAppOnMac ? "true" : "false", default: Steps()][keyPath: step].insert(id)
            }
        }

        let knownPages = [RetroUsageEvent.loadingPage] + RetroUsageEvent.pages
        let unknownPages = reasonsByPage.keys.filter { !knownPages.contains($0) }.sorted()
        let dropOff = (knownPages + unknownPages).map { page in
            let reasons = reasonsByPage[page] ?? [:]
            let total = reasons.values.reduce(0, +)
            let closeButton = reasons["closeButton"] ?? 0
            let swipeDown = reasons["swipeDown"] ?? 0
            let tappedPastEnd = reasons["tappedPastEnd"] ?? 0
            return Retro2026PageDropOff(
                page: page,
                closeButton: closeButton,
                swipeDown: swipeDown,
                tappedPastEnd: tappedPastEnd,
                other: total - closeButton - swipeDown - tappedPastEnd,
                total: total
            )
        }

        let stats2026 = sorted.compactMap(Self.stats)
        let stats2025 = events2025.sorted { $0.dateTime < $1.dateTime }.compactMap(Self.stats)

        self.firstEventAt = sorted.first?.dateTime
        self.funnel = Retro2026Funnel(
            shown: shown.count,
            opened: opened.count,
            reachedEnd: reachedEnd.count,
            tappedShare: tappedShare.count,
            dismissed: dismissed.count,
            openRate: Self.percentage(opened.count, of: shown.count),
            completionRate: Self.percentage(reachedEnd.count, of: opened.count),
            shareRate: Self.percentage(tappedShare.count, of: opened.count),
            dismissRate: Self.percentage(dismissed.count, of: shown.count)
        )
        self.bannerImpressions = impressions
        self.opens = opens
        self.closes = closes
        self.closesBeforeLoading = closesBeforeLoading
        self.opensWithoutClose = max(opens - closes, 0)
        self.shareTaps = shareTaps
        self.dropOff = dropOff
        self.daily = Self.days(from: sorted.first?.day, through: today).map { day in
            Retro2026Day(
                date: day,
                shown: dailyShown[day]?.count ?? 0,
                opened: dailyOpened[day]?.count ?? 0,
                tappedShare: dailyTapped[day]?.count ?? 0
            )
        }
        self.byAppVersion = versions.map { $0.value.breakdown(name: $0.key) }
            .sorted { !GameUsageEvent.appVersion($1.name, isAtLeast: $0.name) }
        self.bySystemName = systems.map { $0.value.breakdown(name: $0.key) }
            .sorted { ($0.shown, $1.name) > ($1.shown, $0.name) }
        self.byMac = macs.map { $0.value.breakdown(name: $0.key) }
            .sorted { $0.name < $1.name }
        self.stats = RetroStatsSummary(stats: stats2026)
        self.comparison = Retro2025Comparison(
            daily: Self.comparisonDays(retro2025: stats2025, retro2026: stats2026, today: today),
            retro2025: RetroStatsSummary(stats: stats2025)
        )
        self.generatedAt = generatedAt
    }

    /// Installs per step, for the breakdowns.
    private struct Steps {
        var shown: Set<String> = []
        var opened: Set<String> = []
        var tappedShare: Set<String> = []

        func breakdown(name: String) -> Retro2026Breakdown {
            Retro2026Breakdown(name: name, shown: shown.count, opened: opened.count, tappedShare: tappedShare.count)
        }
    }

    typealias DatedStats = (installId: String, day: String, stats: RetroShareStats)

    private static func stats(_ event: RetroUsageEvent) -> DatedStats? {
        guard case .stats(let stats) = event.action else { return nil }
        return (event.installId, event.day, stats)
    }

    /// Share taps per day since each year's first, as far as the longer of the two runs.
    /// 2026 runs to today, so days nobody shared yet still show up with zeros.
    private static func comparisonDays(retro2025: [DatedStats], retro2026: [DatedStats], today: String) -> [RetroComparisonDay] {
        func taps(_ stats: [DatedStats], through last: String?) -> [Int] {
            let counts = Dictionary(grouping: stats, by: \.day).mapValues(\.count)
            return days(from: stats.first?.day, through: last ?? stats.last?.day ?? "").map { counts[$0] ?? 0 }
        }
        let taps2025 = taps(retro2025, through: nil)
        let taps2026 = taps(retro2026, through: today)
        return (0..<max(taps2025.count, taps2026.count)).map { day in
            RetroComparisonDay(
                day: day,
                retro2025: day < taps2025.count ? taps2025[day] : 0,
                retro2026: day < taps2026.count ? taps2026[day] : 0
            )
        }
    }

    /// Every UTC day from `first` to `last`, both included. Empty without `first`.
    static func days(from first: String?, through last: String) -> [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let first, let start = formatter.date(from: first), let end = formatter.date(from: last), start <= end else {
            return []
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = formatter.timeZone
        var days: [String] = []
        var date = start
        while date <= end {
            days.append(formatter.string(from: date))
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return days
    }

    static func percentage(_ part: Int, of whole: Int) -> Double {
        guard whole > 0 else { return 0 }
        return (Double(part) / Double(whole) * 100 * 100).rounded() / 100
    }
}

extension RetroStatsSummary {

    static let weekdays = ["Segunda-feira", "Terça-feira", "Quarta-feira", "Quinta-feira", "Sexta-feira", "Sábado", "Domingo"]
    static let neverShared = "Nunca"

    /// - Parameter stats: Oldest first, so each install keeps its latest.
    init(stats: [Retro2026AnalyticsResponse.DatedStats]) {
        var latest: [String: RetroShareStats] = [:]
        for item in stats {
            latest[item.installId] = item.stats
        }
        let people = Array(latest.values)

        var firstSounds: [String: Int] = [:]
        var sounds: [String: Int] = [:]
        var authors: [String: Int] = [:]
        var days: [String: Int] = [:]
        var episodes: [String: Int] = [:]
        for person in people {
            if let first = person.ranking.first { firstSounds[first, default: 0] += 1 }
            for sound in Set(person.ranking) { sounds[sound, default: 0] += 1 }
            if let author = person.author { authors[author, default: 0] += 1 }
            days[person.favoriteDay ?? Self.neverShared, default: 0] += 1
            if let episode = person.topEpisode { episodes[episode, default: 0] += 1 }
        }

        let shareCounts = people.map(\.shareCount).sorted()
        let minutes = people.compactMap(\.listeningMinutes).sorted()

        self.shareTaps = stats.count
        self.people = people.count
        self.topFirstSounds = Self.ranked(firstSounds)
        self.topSounds = Self.ranked(sounds)
        self.topAuthors = Self.ranked(authors)
        self.withoutAuthor = people.filter { $0.author == nil }.count
        let dayOrder = Self.weekdays + [Self.neverShared]
        self.favoriteDays = days
            .map { RetroNameCount(name: $0.key, count: $0.value) }
            .sorted { (dayOrder.firstIndex(of: $0.name) ?? .max, $0.name) < (dayOrder.firstIndex(of: $1.name) ?? .max, $1.name) }
        self.shareCounts = Self.buckets(
            shareCounts,
            ranges: [("0", 0...0), ("1–9", 1...9), ("10–49", 10...49), ("50–99", 50...99), ("100–249", 100...249), ("250–499", 250...499), ("500+", 500...Int.max)]
        )
        self.medianShareCount = Self.median(shareCounts)
        self.listeningMinutes = minutes.isEmpty ? [] : Self.buckets(
            minutes,
            ranges: [("< 30", 0...29), ("30–59", 30...59), ("1–3 h", 60...179), ("3–10 h", 180...599), ("10 h+", 600...Int.max)]
        )
        self.withoutEpisodes = people.filter { $0.listeningMinutes == nil }.count
        self.medianListeningMinutes = Self.median(minutes)
        self.topEpisodes = Self.ranked(episodes)
    }

    /// Most first, ties by name so the order is stable, at most 10.
    private static func ranked(_ counts: [String: Int]) -> [RetroNameCount] {
        Array(
            counts
                .map { RetroNameCount(name: $0.key, count: $0.value) }
                .sorted { ($0.count, $1.name) > ($1.count, $0.name) }
                .prefix(10)
        )
    }

    private static func buckets(_ values: [Int], ranges: [(String, ClosedRange<Int>)]) -> [RetroNameCount] {
        ranges.map { name, range in
            RetroNameCount(name: name, count: values.filter(range.contains).count)
        }
    }

    /// - Parameter values: Sorted.
    private static func median(_ values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        let middle = values.count / 2
        return values.count.isMultiple(of: 2) ? (values[middle - 1] + values[middle]) / 2 : values[middle]
    }
}
