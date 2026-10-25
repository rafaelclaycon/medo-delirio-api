import Foundation

/// Progress of the pushes sent from MedoHelper. Lives in memory only: a restart forgets
/// the history and stops a broadcast midway, which is no worse than the old blocking
/// endpoint dying with its request.
actor PushBroadcastStore {

    enum Outcome: Sendable {
        case sent
        case removedToken
        case failed(String)
    }

    private static let historyLimit = 20
    private static let errorLimit = 20

    /// Newest first.
    private var broadcasts: [PushBroadcastStatus] = []
    private var cancelRequests: Set<UUID> = []

    func all() -> [PushBroadcastStatus] {
        broadcasts
    }

    func status(id: UUID) -> PushBroadcastStatus? {
        broadcasts.first { $0.id == id }
    }

    /// Returns false when another broadcast is still sending, so a double click can't
    /// notify everyone twice.
    func begin(_ status: PushBroadcastStatus) -> Bool {
        guard !broadcasts.contains(where: { $0.state == .sending }) else { return false }
        broadcasts.insert(status, at: 0)
        if broadcasts.count > Self.historyLimit {
            broadcasts.removeLast(broadcasts.count - Self.historyLimit)
        }
        return true
    }

    func record(_ outcome: Outcome, for id: UUID) {
        update(id) { status in
            switch outcome {
            case .sent:
                status.sent += 1
            case .removedToken:
                status.removedTokens += 1
            case .failed(let message):
                status.failed += 1
                status.recentErrors.append(message)
                if status.recentErrors.count > Self.errorLimit {
                    status.recentErrors.removeFirst(status.recentErrors.count - Self.errorLimit)
                }
            }
            status.processed += 1
        }
    }

    /// Returns nil when there's no such broadcast. Asking to cancel one that already
    /// ended is harmless and returns it as it is.
    func requestCancel(id: UUID) -> PushBroadcastStatus? {
        guard let status = status(id: id) else { return nil }
        if status.state == .sending {
            cancelRequests.insert(id)
        }
        return status
    }

    func isCancelRequested(id: UUID) -> Bool {
        cancelRequests.contains(id)
    }

    func finish(id: UUID, as state: PushBroadcastStatus.State, at date: Date = .now) {
        cancelRequests.remove(id)
        update(id) { status in
            status.state = state
            status.finishedAt = date
        }
    }

    private func update(_ id: UUID, _ change: (inout PushBroadcastStatus) -> Void) {
        guard let index = broadcasts.firstIndex(where: { $0.id == id }) else { return }
        change(&broadcasts[index])
    }
}
