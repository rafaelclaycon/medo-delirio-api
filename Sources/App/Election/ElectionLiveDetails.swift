import Foundation

/// Everything the app's results screen shows beyond the Live Activity: every candidate,
/// with votes, and the section counts. Only in `v4/election/live`, never in a push, which
/// has a 5 KB limit and doesn't need it.
struct ElectionLiveDetails: Codable, Equatable {

    let sectionsCounted: Int
    let sectionsTotal: Int
    let validVotes: Int
    /// Every candidate in the TSE ranking.
    let candidates: [Candidate]

    struct Candidate: Codable, Equatable {
        let number: Int
        let name: String
        let party: String
        let votes: Int
        let percent: Double
        let status: ElectionSnapshot.Status
        let colorHex: String?
        /// False for "Anulado" and "Anulado sub judice".
        let hasValidVotes: Bool
    }

    init(snapshot: ElectionSnapshot, candidateColors: [String: String]) {
        sectionsCounted = snapshot.sectionsCounted
        sectionsTotal = snapshot.sectionsTotal
        validVotes = snapshot.validVotes
        candidates = snapshot.candidates.map { candidate in
            Candidate(
                number: candidate.number,
                name: candidate.name,
                party: candidate.party,
                votes: candidate.votes,
                percent: candidate.percent,
                status: candidate.status,
                colorHex: candidateColors[String(candidate.number)],
                hasValidVotes: candidate.hasValidVotes
            )
        }
    }
}
