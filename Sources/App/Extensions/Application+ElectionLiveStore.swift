import Vapor

extension Application {

    private struct ElectionLiveStoreKey: StorageKey {
        typealias Value = ElectionLiveStore
    }

    /// Set up once in `configure`, so the poller and the routes share the same instance.
    var electionLiveStore: ElectionLiveStore {
        get {
            guard let store = storage[ElectionLiveStoreKey.self] else {
                fatalError("electionLiveStore not configured. Set it in configure(_:).")
            }
            return store
        }
        set {
            storage[ElectionLiveStoreKey.self] = newValue
        }
    }
}
