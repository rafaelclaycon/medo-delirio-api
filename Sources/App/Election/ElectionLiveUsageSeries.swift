import Foundation

/// Usage of the election Live Activity over time, for a chart: one bucket per few minutes
/// with who started, who stopped and an estimate of who was still watching. Built from the
/// start and stop events in `UsageMetric` (banner and results screen). No Vapor here, so the
/// bucketing is unit tested.
struct ElectionLiveUsageSeries: Equatable {

    struct Event: Equatable {

        enum Kind: Equatable {
            case started
            case stopped
        }

        let installId: String
        let kind: Kind
        let at: Date
    }

    struct Bucket: Equatable {
        let start: Date
        /// Distinct installs with a start in the bucket.
        let starters: Int
        /// Distinct installs whose first start in the window falls in the bucket.
        let newStarters: Int
        /// Running sum of `newStarters`: everyone who started so far in the window.
        let cumulativeStarters: Int
        /// Distinct installs with a stop in the bucket.
        let stoppers: Int
        /// Installs whose latest event at the end of the bucket is a start at most
        /// `watchLimit` old. Can't see activities the system or the results screen ended.
        let watchingEstimate: Int
    }

    /// A Live Activity stays active for at most 8 hours.
    static let watchLimit: TimeInterval = 8 * 60 * 60

    let since: Date
    let until: Date
    let bucketSeconds: TimeInterval
    let buckets: [Bucket]
    /// Distinct installs that started in the window.
    let uniqueStarters: Int
    /// Every start in the window, repeats included.
    let totalStarts: Int
    /// Distinct installs that stopped in the window.
    let uniqueStoppers: Int

    /// - Parameters:
    ///   - events: Should reach back `watchLimit` before `since`, so installs that started
    ///     before the window count as watching at its start. Any order.
    ///   - since: Rounded down to a bucket boundary, so buckets line up with the clock.
    init(events: [Event], since: Date, until: Date, bucketSeconds: TimeInterval) {
        precondition(bucketSeconds > 0, "bucketSeconds must be positive")
        let alignedSince = Date(
            timeIntervalSince1970: (since.timeIntervalSince1970 / bucketSeconds).rounded(.down) * bucketSeconds
        )
        self.since = alignedSince
        self.until = until
        self.bucketSeconds = bucketSeconds

        let sorted = events.sorted { $0.at < $1.at }
        let inWindow = sorted.filter { $0.at >= alignedSince && $0.at < until }
        let starts = inWindow.filter { $0.kind == .started }
        let stops = inWindow.filter { $0.kind == .stopped }

        var firstStart: [String: Date] = [:]
        for start in starts where firstStart[start.installId] == nil {
            firstStart[start.installId] = start.at
        }

        uniqueStarters = firstStart.count
        totalStarts = starts.count
        uniqueStoppers = Set(stops.map(\.installId)).count

        var buckets: [Bucket] = []
        var latest: [String: Event] = [:]
        var nextEvent = sorted.startIndex
        var cumulative = 0
        var bucketStart = alignedSince

        while bucketStart < until {
            let bucketEnd = min(bucketStart.addingTimeInterval(bucketSeconds), until)
            let range = bucketStart..<bucketEnd

            // Everything before the end of this bucket, the lookback included, decides who's
            // watching when it ends.
            while nextEvent < sorted.endIndex, sorted[nextEvent].at < bucketEnd {
                latest[sorted[nextEvent].installId] = sorted[nextEvent]
                nextEvent += 1
            }

            let newStarters = firstStart.values.filter { range.contains($0) }.count
            cumulative += newStarters
            let watching = latest.values.filter {
                $0.kind == .started && bucketEnd.timeIntervalSince($0.at) <= Self.watchLimit
            }.count

            buckets.append(Bucket(
                start: bucketStart,
                starters: Set(starts.filter { range.contains($0.at) }.map(\.installId)).count,
                newStarters: newStarters,
                cumulativeStarters: cumulative,
                stoppers: Set(stops.filter { range.contains($0.at) }.map(\.installId)).count,
                watchingEstimate: watching
            ))
            bucketStart = bucketStart.addingTimeInterval(bucketSeconds)
        }
        self.buckets = buckets
    }

    // MARK: - Labels

    private static let brasiliaTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        // Fixed UTC-3 if the server has no tzdata, like `ElectionSnapshot`. Brazil has had
        // no daylight saving time since 2019.
        formatter.timeZone = TimeZone(identifier: "America/Sao_Paulo") ?? TimeZone(secondsFromGMT: -3 * 60 * 60)
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    /// "21:10" for 2026-10-05T00:10:00Z: Brasília time, for chart axis labels.
    static func brasiliaTime(_ date: Date) -> String {
        brasiliaTimeFormatter.string(from: date)
    }

    // MARK: - Parsing

    private static let fractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plainFormatter = ISO8601DateFormatter()

    /// The app sends `UsageMetric.dateTime` with fractional seconds. Accepts both, for
    /// query parameters typed by hand.
    static func parseDate(_ string: String) -> Date? {
        fractionalFormatter.date(from: string) ?? plainFormatter.date(from: string)
    }

    static func iso8601(_ date: Date) -> String {
        fractionalFormatter.string(from: date)
    }
}
