import Foundation

/// Fakes the progression of a count, from 0% to the given final snapshot, so we can
/// exercise the poller and Live Activity pushes outside the TSE test windows.
///
/// Every other candidate starts over or under their final share and converges to it,
/// which forces lead changes early in the count, like on a real election night.
struct ElectionReplay {

    let final: ElectionSnapshot
    /// How far off the final share candidates start, e.g. 0.3 = ±30%.
    var skew: Double = 0.3

    /// Share of sections counted after `timeProgress` of the replay. Electronic voting makes
    /// real counts fast at first and slow at the end, when the remote sections come in:
    /// half the count takes a quarter of the time.
    static func countedFraction(at timeProgress: Double) -> Double {
        let timeProgress = min(max(timeProgress, 0), 1)
        return 1 - (1 - timeProgress) * (1 - timeProgress)
    }

    /// The replay as the TSE would publish it at `position`: counted along
    /// `countedFraction(at:)`, with the step time as the totalization time.
    func snapshot(at position: ElectionSettings.ReplayPosition) -> ElectionSnapshot {
        let snapshot = snapshot(at: Self.countedFraction(at: position.progress))
        return ElectionSnapshot(
            electionCode: snapshot.electionCode,
            round: snapshot.round,
            generationId: snapshot.generationId,
            totalizedAt: position.publishedAt,
            isFinal: snapshot.isFinal,
            sectionsTotal: snapshot.sectionsTotal,
            sectionsCounted: snapshot.sectionsCounted,
            sectionsCountedPercent: snapshot.sectionsCountedPercent,
            validVotes: snapshot.validVotes,
            candidates: snapshot.candidates
        )
    }

    /// - Parameter progress: share of sections counted, 0 to 1.
    func snapshot(at progress: Double) -> ElectionSnapshot {
        let progress = min(max(progress, 0), 1)
        guard progress < 1 else { return final }

        let remaining = 1 - progress
        let votes = final.candidates.enumerated().map { index, candidate in
            let direction: Double = index.isMultiple(of: 2) ? -1 : 1
            let factor = progress * (1 + skew * remaining * direction)
            return Int((Double(candidate.votes) * factor).rounded())
        }
        let validVotes = zip(final.candidates, votes)
            .filter { $0.0.hasValidVotes }
            .reduce(0) { $0 + $1.1 }

        let candidates = zip(final.candidates, votes)
            .map { candidate, votes in
                ElectionSnapshot.Candidate(
                    number: candidate.number,
                    name: candidate.name,
                    party: candidate.party,
                    votes: votes,
                    percent: validVotes > 0 ? Double(votes) / Double(validVotes) * 100 : 0,
                    status: .counting,
                    hasValidVotes: candidate.hasValidVotes
                )
            }
            .sorted { $0.votes > $1.votes }

        let sectionsCounted = Int((Double(final.sectionsTotal) * progress).rounded(.down))
        let permille = Int((progress * 1000).rounded(.down))

        return ElectionSnapshot(
            electionCode: final.electionCode,
            round: final.round,
            generationId: "replay-\(permille)",
            totalizedAt: final.totalizedAt,
            isFinal: false,
            sectionsTotal: final.sectionsTotal,
            sectionsCounted: sectionsCounted,
            sectionsCountedPercent: final.sectionsTotal > 0 ? Double(sectionsCounted) / Double(final.sectionsTotal) * 100 : 0,
            validVotes: validVotes,
            candidates: candidates
        )
    }
}
