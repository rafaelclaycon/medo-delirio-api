import Foundation

/// Mirrors `ElectionActivityAttributes.ContentState` in the iOS app, key for key: ActivityKit
/// decodes the APNs `content-state` with a plain `JSONDecoder`, so any mismatch silently drops
/// the update. That's also why there's no `Date` here.
struct ElectionLiveContentState: Codable, Equatable {

    var sectionsCountedPercent: Double
    var isFinal: Bool
    /// TSE totalization time, seconds since 1970.
    var updatedAt: Double
    var candidates: [Candidate]

    struct Candidate: Codable, Equatable {
        let number: Int
        let name: String
        let party: String
        let percent: Double
        let status: ElectionSnapshot.Status
        let colorHex: String?
    }

    /// Lock Screen space is tight: 4 rows in the 1st round, only the 2 finalists in the 2nd.
    static func candidateLimit(round: Int) -> Int {
        round == 2 ? 2 : 4
    }

    /// - Parameter candidateColors: "#RRGGBB" by ballot number, as a string key so it
    ///   round-trips through JSON settings.
    init(snapshot: ElectionSnapshot, candidateColors: [String: String], fallbackDate: Date = .now) {
        self.sectionsCountedPercent = snapshot.sectionsCountedPercent
        self.isFinal = snapshot.isFinal
        self.updatedAt = (snapshot.totalizedAt ?? fallbackDate).timeIntervalSince1970
        self.candidates = snapshot.candidates
            .prefix(Self.candidateLimit(round: snapshot.round))
            .map { candidate in
                Candidate(
                    number: candidate.number,
                    name: candidate.name,
                    party: candidate.party,
                    percent: candidate.percent,
                    status: candidate.status,
                    colorHex: candidateColors[String(candidate.number)]
                )
            }
    }
}
