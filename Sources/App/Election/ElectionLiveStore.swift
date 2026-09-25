import Foundation

/// In-memory state of the election poller. Nothing here needs to survive a restart:
/// the first poll after boot fills it back in within seconds.
actor ElectionLiveStore {

    /// Where the current snapshot came from. When the admin switches source or round,
    /// everything learned about the previous one is thrown away.
    struct Target: Equatable {
        let source: ElectionSettings.Source
        let round: Int
    }

    struct ResolvedElection: Equatable {
        let cycle: String
        let electionCode: String
    }

    private(set) var target: Target?
    private(set) var resolvedElection: ResolvedElection?
    private(set) var snapshot: ElectionSnapshot?
    private(set) var etag: String?
    private(set) var lastConfigCheckAt: Date?
    private(set) var lastFetchAt: Date?
    private(set) var lastError: String?
    /// Final simulation result the replay counts towards.
    private(set) var replayFinal: ElectionSnapshot?

    /// Returns true when the target changed and the state was reset.
    @discardableResult
    func prepare(for target: Target) -> Bool {
        guard target != self.target else { return false }
        self.target = target
        resolvedElection = nil
        snapshot = nil
        etag = nil
        lastConfigCheckAt = nil
        lastError = nil
        return true
    }

    func setResolvedElection(_ election: ResolvedElection?, checkedAt: Date) {
        resolvedElection = election
        lastConfigCheckAt = checkedAt
    }

    /// Returns true when the snapshot is new (different TSE generation).
    @discardableResult
    func update(snapshot: ElectionSnapshot, etag: String?, at date: Date) -> Bool {
        self.etag = etag
        lastFetchAt = date
        lastError = nil
        guard snapshot.generationId != self.snapshot?.generationId else { return false }
        self.snapshot = snapshot
        return true
    }

    func markNotModified(at date: Date) {
        lastFetchAt = date
        lastError = nil
    }

    /// Forgets the resolved election too: a 404 means our URL is wrong, and repeating it
    /// can get the server's IP blocked by the TSE.
    func markNotFound(at date: Date) {
        lastFetchAt = date
        lastError = "404 at \(date)"
        resolvedElection = nil
        etag = nil
    }

    func markError(_ error: String) {
        lastError = error
    }

    func setReplayFinal(_ snapshot: ElectionSnapshot) {
        replayFinal = snapshot
    }
}
