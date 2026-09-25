import Vapor

/// Follows the TSE President result file and keeps the latest `ElectionSnapshot` in
/// `app.electionLiveStore`.
///
/// TSE rules to keep in mind: 100 requests/s per IP (304s count too), a 10 minute block
/// when exceeded, and repeated 404s can also block the IP. One request every 10s is far
/// below the limit; 404s are what we really have to avoid, hence resolving URLs from
/// `ele-c.json` and backing off when one fails.
struct ElectionPollingService {

    static let pollingInterval: TimeInterval = 10
    /// `ele-c.json` barely changes. While the round isn't published yet (or after a 404),
    /// check it at most once a minute.
    static let configCheckInterval: TimeInterval = 60
    static let errorBackoff: TimeInterval = 60
    static let requestTimeoutSeconds: Int64 = 8

    let app: Application

    private var store: ElectionLiveStore {
        app.electionLiveStore
    }

    func run() async {
        app.logger.info("Election poll: started")
        while !Task.isCancelled {
            let delay = await tick()
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        app.logger.info("Election poll: stopped")
    }

    /// Returns how long to wait before the next tick.
    func tick(now: Date = .now) async -> TimeInterval {
        do {
            let settings = try await ElectionSettingsRepository.load(db: app.db)
            if await store.prepare(for: .init(source: settings.source, round: settings.round)) {
                app.logger.info("Election poll: following \(settings.source.rawValue), round \(settings.round)")
            }

            switch settings.source {
            case .simulation, .official:
                try await pollTSE(settings: settings, now: now)
            case .replay:
                try await pollReplay(settings: settings, now: now)
            }
            return Self.pollingInterval
        } catch {
            app.logger.error("Election poll: \(error)")
            await store.markError(String(describing: error))
            return Self.errorBackoff
        }
    }

    // MARK: - TSE

    private func pollTSE(settings: ElectionSettings, now: Date) async throws {
        guard let election = try await resolveElection(endpoint: settings.endpoint, round: settings.round, now: now) else {
            return
        }

        let url = settings.endpoint.presidentResultURL(cycle: election.cycle, electionCode: election.electionCode)
        let response = try await get(url, etag: await store.etag)

        switch response.status {
        case .ok:
            let file = try response.content.decode(TSEResultFile.self, using: JSONDecoder())
            let snapshot = try ElectionSnapshot(from: file)
            if await store.update(snapshot: snapshot, etag: response.headers.first(name: .eTag), at: now) {
                didReceive(snapshot)
            }
        case .notModified:
            await store.markNotModified(at: now)
        case .notFound:
            app.logger.warning("Election poll: 404 for \(url), will resolve the election again")
            await store.markNotFound(at: now)
        default:
            throw Abort(.badGateway, reason: "TSE answered \(response.status.code) for \(url)")
        }
    }

    private func resolveElection(endpoint: TSEEndpoint, round: Int, now: Date) async throws -> ElectionLiveStore.ResolvedElection? {
        if let resolved = await store.resolvedElection {
            return resolved
        }
        if let lastCheck = await store.lastConfigCheckAt, now.timeIntervalSince(lastCheck) < Self.configCheckInterval {
            return nil
        }

        let response = try await get(endpoint.electionConfigURL, etag: nil)
        guard response.status == .ok else {
            await store.setResolvedElection(nil, checkedAt: now)
            throw Abort(.badGateway, reason: "TSE answered \(response.status.code) for \(endpoint.electionConfigURL)")
        }

        let config = try response.content.decode(TSEElectionConfig.self, using: JSONDecoder())
        let resolved = config.presidentialElection(round: round).map {
            ElectionLiveStore.ResolvedElection(cycle: $0.cycle, electionCode: $0.electionCode)
        }
        await store.setResolvedElection(resolved, checkedAt: now)

        if let resolved {
            app.logger.info("Election poll: round \(round) is election \(resolved.electionCode) in \(resolved.cycle)")
        } else {
            app.logger.info("Election poll: round \(round) not published in \(endpoint.environment) yet")
        }
        return resolved
    }

    // MARK: - Replay

    /// Counts towards the final result of the TSE simulation, fetched once.
    private func pollReplay(settings: ElectionSettings, now: Date) async throws {
        let final: ElectionSnapshot
        if let cached = await store.replayFinal {
            final = cached
        } else {
            guard let election = try await resolveElection(endpoint: .simulation, round: 1, now: now) else {
                return
            }
            let url = TSEEndpoint.simulation.presidentResultURL(cycle: election.cycle, electionCode: election.electionCode)
            let response = try await get(url, etag: nil)
            guard response.status == .ok else {
                throw Abort(.badGateway, reason: "TSE answered \(response.status.code) for \(url)")
            }
            final = try ElectionSnapshot(from: response.content.decode(TSEResultFile.self, using: JSONDecoder()))
            await store.setReplayFinal(final)
        }

        let snapshot = ElectionReplay(final: final).snapshot(at: settings.replayProgress(at: now))
        if await store.update(snapshot: snapshot, etag: nil, at: now) {
            didReceive(snapshot)
        }
    }

    // MARK: - Helpers

    private func didReceive(_ snapshot: ElectionSnapshot) {
        let leader = snapshot.leader.map { "\($0.name) \(String(format: "%.2f", $0.percent))%" } ?? "none"
        app.logger.info("Election poll: generation \(snapshot.generationId), \(String(format: "%.2f", snapshot.sectionsCountedPercent))% counted, leader \(leader)\(snapshot.isFinal ? ", FINAL" : "")")
        // Next step: hand the snapshot to the Live Activity broadcaster.
    }

    /// The TSE CDN drops idle keep-alive connections and the client only finds out when it
    /// reuses one (`remoteConnectionClosed`). One immediate retry gets a fresh connection
    /// instead of waiting out the error backoff.
    private func get(_ url: URL, etag: String?) async throws -> ClientResponse {
        do {
            return try await send(url, etag: etag)
        } catch {
            app.logger.info("Election poll: retrying \(url.lastPathComponent) after \(error)")
            return try await send(url, etag: etag)
        }
    }

    private func send(_ url: URL, etag: String?) async throws -> ClientResponse {
        var headers = HTTPHeaders()
        headers.add(name: .userAgent, value: "MedoDelirioAPI")
        if let etag {
            headers.add(name: .ifNoneMatch, value: etag)
        }
        return try await app.client.get(URI(string: url.absoluteString), headers: headers) { request in
            request.timeout = .seconds(Self.requestTimeoutSeconds)
        }
    }
}
