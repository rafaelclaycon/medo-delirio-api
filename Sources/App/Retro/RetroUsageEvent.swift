//
//  RetroUsageEvent.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 05/11/26.
//

import Foundation

/// One Retrospectiva event from `UsageMetric`. The action and its parameters are packed
/// into `destinationScreen`, so they're parsed here. No Vapor, so the parsing is unit tested.
struct RetroUsageEvent: Equatable {

    enum Action: Equatable {
        /// The banner appeared on Vírgulas. At most once per app launch.
        case bannerShown
        /// "Bora!" tapped: the only way into the Stories.
        case openedFromBanner
        /// The banner's X tapped. It stays dismissed on that install.
        case bannerDismissed
        /// The Stories closed. `page` is the furthest one reached, or `loading` when they
        /// closed before the data loaded. `reason` is `closeButton`, `swipeDown` or
        /// `tappedPastEnd`.
        case closed(page: String, pageNumber: Int, pageCount: Int, reason: String)
        /// "Compartilhar" tapped on the last page. A tap, not a confirmed share.
        case shareTapped
        /// What the shared image shows, sent right after `shareTapped`. The only event 2025 has.
        case stats(RetroShareStats)
    }

    static let screen2026 = "Retro2026"
    static let screen2025 = "Retro2025"

    /// The Stories pages in display order. Pages without data are skipped, so compare by name.
    static let pages = ["intro", "shares", "topAuthor", "topSound3", "topSound2", "topSound1", "listening", "topEpisode", "habits", "share"]
    /// The furthest page of a viewing closed before the data loaded.
    static let loadingPage = "loading"
    /// Reaching it means they saw everything.
    static let lastPage = "share"

    let installId: String
    /// ISO 8601 in UTC, as the app sends it.
    let dateTime: String
    let appVersion: String
    let systemName: String
    let isiOSAppOnMac: Bool
    let action: Action

    /// The UTC day, "yyyy-MM-dd".
    var day: String { String(dateTime.prefix(10)) }

    init(
        installId: String,
        dateTime: String,
        appVersion: String = "",
        systemName: String = "iOS",
        isiOSAppOnMac: Bool = false,
        action: Action
    ) {
        self.installId = installId
        self.dateTime = dateTime
        self.appVersion = appVersion
        self.systemName = systemName
        self.isiOSAppOnMac = isiOSAppOnMac
        self.action = action
    }

    /// `nil` for a row that isn't a Retrospectiva event or doesn't parse.
    init?(
        installId: String,
        originatingScreen: String,
        destinationScreen: String,
        dateTime: String,
        appVersion: String,
        systemName: String,
        isiOSAppOnMac: Bool
    ) {
        guard let action = Self.action(originatingScreen: originatingScreen, destinationScreen: destinationScreen) else {
            return nil
        }
        self.init(
            installId: installId,
            dateTime: dateTime,
            appVersion: appVersion,
            systemName: systemName,
            isiOSAppOnMac: isiOSAppOnMac,
            action: action
        )
    }

    private static func action(originatingScreen: String, destinationScreen event: String) -> Action? {
        switch originatingScreen {
        case screen2026:
            switch event {
            case "didShowRetroBanner": return .bannerShown
            case "didOpenRetroFromBanner": return .openedFromBanner
            case "didDismissRetroBanner": return .bannerDismissed
            case "didTapRetroShareButton": return .shareTapped
            default: break
            }
            if event.hasPrefix("didCloseRetroStories") {
                // "didCloseRetroStories; topSound1; 6; 9; swipeDown"
                let fields = event.components(separatedBy: "; ")
                guard fields.count == 5, fields[0] == "didCloseRetroStories",
                      let pageNumber = Int(fields[2]), let pageCount = Int(fields[3]) else {
                    return nil
                }
                return .closed(page: fields[1], pageNumber: pageNumber, pageCount: pageCount, reason: fields[4])
            }
            return RetroShareStats(event).map(Action.stats)
        case screen2025:
            return RetroShareStats(event).map(Action.stats)
        default:
            return nil
        }
    }
}

/// The stats string sent with each share tap:
/// `<ranking>; <N> compart; <favorite day>; <author>; <minutes> min; <episode title>`.
///
/// Sound names and episode titles can hold commas and semicolons, so the parsing anchors
/// on the `compart` field and on the `no-author` / `no-episodes` tokens. 2025 has no
/// episode part.
struct RetroShareStats: Equatable {

    /// The top Vírgulas, #1 first, at most 5. Can be empty.
    let ranking: [String]
    /// Shares in the year.
    let shareCount: Int
    /// The weekday they shared most, e.g. "Sexta-feira". `nil` when they never shared.
    let favoriteDay: String?
    /// `nil` for `no-author`.
    let author: String?
    /// `nil` for `no-episodes`, and in 2025.
    let listeningMinutes: Int?
    let topEpisode: String?

    init(
        ranking: [String],
        shareCount: Int,
        favoriteDay: String?,
        author: String?,
        listeningMinutes: Int? = nil,
        topEpisode: String? = nil
    ) {
        self.ranking = ranking
        self.shareCount = shareCount
        self.favoriteDay = favoriteDay
        self.author = author
        self.listeningMinutes = listeningMinutes
        self.topEpisode = topEpisode
    }

    /// `nil` when `text` has no `<N> compart` field or what follows it doesn't fit.
    init?(_ text: String) {
        let fields = text.components(separatedBy: "; ")
        guard let compartIndex = fields.firstIndex(where: { $0.wholeMatch(of: /\d+ compart/) != nil }),
              let shareCount = Int(fields[compartIndex].prefix { $0.isNumber }) else {
            return nil
        }

        var rest = fields[(compartIndex + 1)...]
        guard let day = rest.popFirst() else { return nil }

        // Author: `name; photoURL`, `name; no-photo`, or the single token `no-author`.
        let author: String?
        if rest.first == "no-author" {
            rest.removeFirst()
            author = nil
        } else if let photoIndex = rest.firstIndex(where: { $0 == "no-photo" || $0.hasPrefix("http") }),
                  photoIndex > rest.startIndex {
            author = rest[rest.startIndex..<photoIndex].joined(separator: "; ")
            rest = rest[(photoIndex + 1)...]
        } else {
            return nil
        }

        // Episodes: `minutes min; title`, the single token `no-episodes`, or nothing in 2025.
        var listeningMinutes: Int?
        var topEpisode: String?
        if rest.isEmpty || Array(rest) == ["no-episodes"] {
            // No listening data.
        } else if let minutesField = rest.first, minutesField.wholeMatch(of: /\d+ min/) != nil,
                  let minutes = Int(minutesField.prefix { $0.isNumber }) {
            listeningMinutes = minutes
            let title = rest.dropFirst().joined(separator: "; ")
            topEpisode = title.isEmpty ? nil : title
        } else {
            return nil
        }

        self.init(
            ranking: Self.ranking(fields[..<compartIndex].joined(separator: "; ")),
            shareCount: shareCount,
            favoriteDay: day == "-" ? nil : day,
            author: author,
            listeningMinutes: listeningMinutes,
            topEpisode: topEpisode
        )
    }

    /// "1 Fudeu, 2 Eu prefiro morrer" → ["Fudeu", "Eu prefiro morrer"]. Names can hold
    /// commas, so each one runs up to the next ", <rank> ".
    static func ranking(_ text: String) -> [String] {
        guard text.hasPrefix("1 ") else { return [] }
        var remaining = text.dropFirst(2)
        var names: [String] = []
        for rank in 1...5 {
            if rank < 5, let next = remaining.range(of: ", \(rank + 1) ") {
                names.append(String(remaining[..<next.lowerBound]))
                remaining = remaining[next.upperBound...]
            } else {
                names.append(String(remaining))
                break
            }
        }
        return names
    }
}
