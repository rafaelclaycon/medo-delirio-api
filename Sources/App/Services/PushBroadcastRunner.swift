import Foundation

/// Sends one broadcast device by device, reporting each result to the store. APNs and the
/// database come in as closures so tests can run it without either.
struct PushBroadcastRunner: Sendable {

    struct Target: Sendable, Equatable {
        let installId: String
        let token: String
    }

    let store: PushBroadcastStore
    let pauseBetweenDevices: Duration
    let send: @Sendable (_ token: String) async throws -> Void
    let removeDevice: @Sendable (_ installId: String) async -> Void

    func run(id: UUID, targets: [Target]) async {
        for (index, target) in targets.enumerated() {
            if await store.isCancelRequested(id: id) {
                await store.finish(id: id, as: .cancelled)
                return
            }

            do {
                try await send(target.token)
                await store.record(.sent, for: id)
            } catch where Self.isInvalidToken(error) {
                await removeDevice(target.installId)
                await store.record(.removedToken, for: id)
            } catch {
                await store.record(.failed("\(target.installId): \(error)"), for: id)
            }

            if index < targets.count - 1 {
                try? await Task.sleep(for: pauseBetweenDevices)
            }
        }
        await store.finish(id: id, as: .finished)
    }

    static func isInvalidToken(_ error: Error) -> Bool {
        let description = String(describing: error).lowercased()
        return description.contains("baddevicetoken") || description.contains("unregistered")
    }
}
