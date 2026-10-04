//
//  ElectionLiveAnalyticsResponse.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 04/10/26.
//

import Vapor

/// Usage of the election Live Activity, from the `UsageMetric` events the app's
/// `ElectionLiveBanner` and `ElectionLiveWhatsNew` send. Installs are counted by
/// `customInstallId`, so the same person starting several times counts once.
///
/// Undercounts: the app only reports a start after the Live Activity actually began,
/// and the results screen (13.1) doesn't send events at all.
struct ElectionLiveAnalyticsResponse: Content {

    /// Start of the window, as received (ISO 8601 UTC).
    let since: String
    /// Distinct installs that started the Live Activity from the banner.
    let uniqueStarters: Int
    let totalStarts: Int
    /// Distinct installs that stopped it from the banner.
    let uniqueStoppers: Int
    let totalStops: Int
    /// Installs whose latest banner event is a start, sent in the last 8 hours (the
    /// longest a Live Activity stays active). An estimate: it can't see activities the
    /// system or the results screen ended.
    let likelyWatchingNow: Int
    /// Distinct installs that dismissed the election What's New screen.
    let whatsNewDismissals: Int
    /// One entry per UTC hour that had events, ascending.
    let hourly: [ElectionLiveHourlyCount]
    let startersByVersion: [ElectionLiveVersionCount]
    let generatedAt: String
}

struct ElectionLiveHourlyCount: Content {

    /// UTC hour, `yyyy-MM-ddTHH`.
    let hour: String
    /// Distinct installs that started in this hour.
    let starters: Int
    /// Distinct installs whose first start in the window was in this hour. Summing
    /// these up to an hour gives the cumulative `uniqueStarters` at that hour.
    let newStarters: Int
    /// Distinct installs that stopped in this hour.
    let stoppers: Int
}

struct ElectionLiveVersionCount: Content {

    let appVersion: String
    /// Distinct installs on this version that started the Live Activity.
    let starters: Int
}
