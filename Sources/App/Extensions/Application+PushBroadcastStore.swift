import Vapor

extension Application {

    private struct PushBroadcastStoreKey: StorageKey {
        typealias Value = PushBroadcastStore
    }

    /// Set up once in `configure`, so the broadcast running in the background and the
    /// progress routes share the same instance.
    var pushBroadcastStore: PushBroadcastStore {
        get {
            guard let store = storage[PushBroadcastStoreKey.self] else {
                fatalError("pushBroadcastStore not configured. Set it in configure(_:).")
            }
            return store
        }
        set {
            storage[PushBroadcastStoreKey.self] = newValue
        }
    }
}
