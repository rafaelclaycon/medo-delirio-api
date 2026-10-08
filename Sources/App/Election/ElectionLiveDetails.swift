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
    /// Blank and null votes and who didn't vote, for the sections counted so far. Nil when
    /// the TSE file doesn't have them. Apps from before it ignore the key.
    let turnout: Turnout?

    struct Turnout: Codable, Equatable {
        let electorate: Int
        let attended: Int
        let abstentions: Int
        /// Of the voters in counted sections, 0 to 100.
        let abstentionPercent: Double
        let totalVotes: Int
        let blankVotes: Int
        /// Of every vote cast, 0 to 100.
        let blankPercent: Double
        let nullVotes: Int
        let nullPercent: Double

        init(_ turnout: ElectionSnapshot.Turnout) {
            electorate = turnout.electorate
            attended = turnout.attended
            abstentions = turnout.abstentions
            abstentionPercent = turnout.abstentionPercent
            totalVotes = turnout.totalVotes
            blankVotes = turnout.blankVotes
            blankPercent = turnout.blankPercent
            nullVotes = turnout.nullVotes
            nullPercent = turnout.nullPercent
        }
    }

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
        turnout = snapshot.turnout.map(Turnout.init)
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
