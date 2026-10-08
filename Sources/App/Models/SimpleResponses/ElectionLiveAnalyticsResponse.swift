//
//  ElectionLiveAnalyticsResponse.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 04/10/26.
//

import Vapor

/// Usage of the election Live Activity, from the `UsageMetric` events the app's
/// `ElectionLiveBanner`, `ElectionResults` and `ElectionLiveWhatsNew` send. Installs are
/// counted by `customInstallId`, so the same person starting several times counts once.
///
/// Undercounts: the app only reports a start after the Live Activity actually began,
/// and the results screen only sends them from the version after 13.2 on.
struct ElectionLiveAnalyticsResponse: Content {

    /// Start of the window, as received (ISO 8601 UTC).
    let since: String
    /// Distinct installs that started the Live Activity, from the banner or the results screen.
    let uniqueStarters: Int
    let totalStarts: Int
    /// Distinct installs that stopped it, from the banner or the results screen.
    let uniqueStoppers: Int
    let totalStops: Int
    /// Installs whose latest start or stop event is a start, sent in the last 8 hours (the
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

/// Usage of the election Live Activity as a time series, for a chart. Built by
/// `ElectionLiveUsageSeries`; same events and the same undercount as
/// `ElectionLiveAnalyticsResponse`.
struct ElectionLiveSeriesResponse: Content {

    /// Window start, rounded down to a bucket boundary (ISO 8601 UTC).
    let since: String
    let until: String
    let bucketMinutes: Int
    /// Distinct installs that started the Live Activity in the window.
    let uniqueStarters: Int
    let totalStarts: Int
    let uniqueStoppers: Int
    /// Every bucket of the window in order, empty ones included.
    let buckets: [ElectionLiveSeriesBucket]
    let generatedAt: String
}

struct ElectionLiveSeriesBucket: Content {

    /// Bucket start, ISO 8601 UTC.
    let start: String
    /// The same instant as "HH:mm" in Brasília time, for axis labels.
    let startBrasilia: String
    let starters: Int
    let newStarters: Int
    /// Everyone who started so far in the window: the chart's main line.
    let cumulativeStarters: Int
    let stoppers: Int
    /// Installs whose latest start or stop event is a start at most 8 hours old at the end of the
    /// bucket. An estimate: activities the system or the final push ended are invisible.
    let watchingEstimate: Int
}
