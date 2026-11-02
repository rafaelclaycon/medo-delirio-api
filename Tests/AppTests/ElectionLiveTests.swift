@testable import App
import Testing
import VaporTesting
import Foundation

struct ElectionLiveTests {

    // MARK: - Content State

    @Test func `Content state keeps top four in first round`() throws {
        let snapshot = try ElectionFixtures.finalPresidentSnapshot()
        let state = ElectionLiveContentState(snapshot: snapshot, candidateColors: [:])
        #expect(state.candidates.map(\.number) == [57, 89, 68, 88])
        #expect(state.sectionsCountedPercent == 100)
        #expect(state.isFinal)
        #expect(state.updatedAt == 1790277154)
    }

    @Test func `Content state applies colors by ballot number`() throws {
        let snapshot = try ElectionFixtures.finalPresidentSnapshot()
        let state = ElectionLiveContentState(snapshot: snapshot, candidateColors: ["89": "#D62828"])
        #expect(state.candidates[1].colorHex == "#D62828")
        #expect(state.candidates[0].colorHex == nil)
    }

    @Test func `Content state uses fallback date without totalization time`() throws {
        let final = try ElectionFixtures.finalPresidentSnapshot()
        let snapshot = ElectionSnapshot(
            electionCode: final.electionCode, round: 2, generationId: "1", totalizedAt: nil, isFinal: false,
            sectionsTotal: 10, sectionsCounted: 0, sectionsCountedPercent: 0, validVotes: 0, candidates: final.candidates
        )
        let state = ElectionLiveContentState(snapshot: snapshot, candidateColors: [:], fallbackDate: Date(timeIntervalSince1970: 42))
        #expect(state.updatedAt == 42)
        #expect(state.candidates.count == 2)
    }

    /// Must match `ElectionActivityAttributes.ContentState` in the iOS app, or ActivityKit
    /// drops the push.
    @Test func `Content state wire format`() throws {
        let snapshot = try ElectionFixtures.finalPresidentSnapshot()
        let state = ElectionLiveContentState(snapshot: snapshot, candidateColors: [:])
        let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        #expect(Set(json.keys) == ["sectionsCountedPercent", "isFinal", "updatedAt", "candidates"])
        let candidate = try #require((json["candidates"] as? [[String: Any]])?.first)
        #expect(Set(candidate.keys) == ["number", "name", "party", "percent", "status"])
        #expect(candidate["status"] as? String == "runoff")
    }

    // MARK: - Details

    @Test func `Details keep every candidate with votes`() throws {
        let snapshot = try ElectionFixtures.finalPresidentSnapshot()
        let details = ElectionLiveDetails(snapshot: snapshot, candidateColors: ["57": "#1D4E89"])
        #expect(details.candidates.map(\.number) == snapshot.candidates.map(\.number))
        #expect(details.candidates.map(\.votes) == snapshot.candidates.map(\.votes))
        #expect(details.sectionsTotal == snapshot.sectionsTotal)
        #expect(details.validVotes == snapshot.validVotes)
        #expect(details.candidates.first { $0.number == 57 }?.colorHex == "#1D4E89")
        #expect(details.candidates.count > ElectionLiveContentState(snapshot: snapshot, candidateColors: [:]).candidates.count)
    }

    @Test func `Official results URL defaults and resets`() throws {
        #expect(ElectionSettings().officialResultsURL == ElectionSettings.defaultOfficialResultsURL)
        let pointed = ElectionSettings().applying(.init(officialResultsURL: "https://resultados.tse.jus.br/oficial/app/index.html"))
        #expect(pointed.officialResultsURL == "https://resultados.tse.jus.br/oficial/app/index.html")
        #expect(pointed.applying(.init(officialResultsURL: "")).officialResultsURL == ElectionSettings.defaultOfficialResultsURL)
        // Settings saved before the field existed still load.
        let old = try JSONDecoder().decode(ElectionSettings.self, from: Data(#"{"enabled":true}"#.utf8))
        #expect(old.officialResultsURL == ElectionSettings.defaultOfficialResultsURL)
    }

    // MARK: - Settings

    @Test func `Settings defaults are safe`() {
        let settings = ElectionSettings()
        #expect(!settings.enabled)
        #expect(settings.source == .simulation)
        #expect(settings.round == 1)
        #expect(settings.endpoint == .simulation)
    }

    @Test func `Settings partial update keeps other fields`() {
        let settings = ElectionSettings(enabled: true, channelIds: ["app": "abc"], candidateColors: ["13": "#FF0000"])
        let updated = settings.applying(.init(source: .official))
        #expect(updated.source == .official)
        #expect(updated.endpoint == .official)
        #expect(updated.enabled)
        #expect(updated.channelIds == ["app": "abc"])
        #expect(updated.candidateColors == ["13": "#FF0000"])
    }

    @Test func `Channel ids merge by bundle and empty clears`() {
        let settings = ElectionSettings(channelIds: ["prod": "abc", "beta": "def"])
        #expect(settings.applying(.init(channelIds: ["beta": "xyz"])).channelIds == ["prod": "abc", "beta": "xyz"])
        #expect(settings.applying(.init(channelIds: ["prod": ""])).channelIds == ["beta": "def"])
    }

    @Test func `Channel lookup has no fallback between apps`() async throws {
        try await withTestApp { app in
            let settings = ElectionSettings(channelIds: [ElectionSettings.productionBundleId: "prod-channel"])
            #expect(settings.channelId(forBundleId: ElectionSettings.productionBundleId) == "prod-channel")
            #expect(settings.channelId(forBundleId: nil) == "prod-channel")
            // The beta app can't subscribe to production's channel.
            #expect(settings.channelId(forBundleId: ElectionSettings.betaBundleId) == nil)
        }
    }

    /// Settings saved before a field existed must still load, or the poller stops.
    @Test func `Settings decode with missing keys`() throws {
        let json = #"{"enabled":true,"source":"official","round":1,"candidateColors":{}}"#
        let settings = try JSONDecoder().decode(ElectionSettings.self, from: Data(json.utf8))
        #expect(settings.enabled)
        #expect(settings.source == .official)
        #expect(settings.channelIds == [:])
        #expect(settings.broadcastMode == .dryRun)
        #expect(settings.minPushIntervalSeconds == 30)
        #expect(settings.replayDurationMinutes == 20)
        #expect(settings.replayStepSeconds == 60)
        #expect(!settings.replayOffline)
        #expect(settings.finalMessages == [:])
        #expect(settings.previewVersions == [])
    }

    // MARK: - Preview versions

    /// The version in App Review sees the feature while the one in the store doesn't.
    @Test func `Preview versions see the feature before the launch`() {
        let settings = ElectionSettings(previewVersions: ["13.2"])
        #expect(settings.isEnabled(forAppVersion: "13.2"))
        #expect(!settings.isEnabled(forAppVersion: "13.1"))
        // 13.0 doesn't send its version.
        #expect(!settings.isEnabled(forAppVersion: nil))
        #expect(!ElectionSettings().isEnabled(forAppVersion: "13.2"))
        // After the launch, everyone.
        let launched = ElectionSettings(enabled: true)
        #expect(launched.isEnabled(forAppVersion: "13.1"))
        #expect(launched.isEnabled(forAppVersion: nil))
    }

    @Test func `Preview versions update replaces the list`() {
        let settings = ElectionSettings(previewVersions: ["13.1"])
        #expect(settings.applying(.init(previewVersions: ["13.2", "13.3"])).previewVersions == ["13.2", "13.3"])
        #expect(settings.applying(.init(previewVersions: [])).previewVersions == [])
        #expect(settings.applying(.init(source: .replay)).previewVersions == ["13.1"])
    }

    @Test func `Broadcast settings update`() {
        let updated = ElectionSettings().applying(.init(broadcastMode: .live, minPushIntervalSeconds: 60))
        #expect(updated.broadcastMode == .live)
        #expect(updated.minPushIntervalSeconds == 60)
    }

    @Test func `Switching to replay starts it`() {
        let now = Date(timeIntervalSince1970: 1000)
        let settings = ElectionSettings().applying(.init(source: .replay), now: now)
        #expect(settings.replayStartedAt == 1000)
        // Already on replay: only an explicit restart moves the start.
        #expect(settings.applying(.init(source: .replay), now: Date(timeIntervalSince1970: 2000)).replayStartedAt == 1000)
        #expect(settings.applying(.init(restartReplay: true), now: Date(timeIntervalSince1970: 2000)).replayStartedAt == 2000)
    }

    @Test func `Replay moves in steps`() {
        let settings = ElectionSettings(replayStartedAt: 1000, replayDurationMinutes: 10, replayStepSeconds: 60)
        func position(_ seconds: Double) -> ElectionSettings.ReplayPosition {
            settings.replayPosition(at: Date(timeIntervalSince1970: seconds))
        }
        #expect(position(500) == .init(progress: 0, publishedAt: Date(timeIntervalSince1970: 1000)))
        #expect(position(1059) == .init(progress: 0, publishedAt: Date(timeIntervalSince1970: 1000)))
        #expect(position(1061) == .init(progress: 0.1, publishedAt: Date(timeIntervalSince1970: 1060)))
        #expect(position(1300) == .init(progress: 0.5, publishedAt: Date(timeIntervalSince1970: 1300)))
        #expect(position(9999) == .init(progress: 1, publishedAt: Date(timeIntervalSince1970: 1600)))
    }

    @Test func `Replay last step lands on the end`() {
        // 10 minutes in steps of 7 minutes: 0, 7, then straight to 10.
        let settings = ElectionSettings(replayStartedAt: 0, replayDurationMinutes: 10, replayStepSeconds: 420)
        #expect(settings.replayPosition(at: Date(timeIntervalSince1970: 599)).progress == 0.7)
        #expect(settings.replayPosition(at: Date(timeIntervalSince1970: 600)).progress == 1)
    }

    @Test func `Replay loops after the pause on the final result`() {
        // 10-minute count, 5-minute pause: laps of 15 minutes starting at 1000, 1900, 2800…
        let settings = ElectionSettings(replayStartedAt: 1000, replayDurationMinutes: 10, replayStepSeconds: 60, replayLoop: true, replayLoopPauseMinutes: 5)
        func position(_ seconds: Double) -> ElectionSettings.ReplayPosition {
            settings.replayPosition(at: Date(timeIntervalSince1970: seconds))
        }
        #expect(position(1600) == .init(progress: 1, publishedAt: Date(timeIntervalSince1970: 1600)))
        #expect(position(1899) == .init(progress: 1, publishedAt: Date(timeIntervalSince1970: 1600)))
        #expect(position(1900) == .init(progress: 0, publishedAt: Date(timeIntervalSince1970: 1900)))
        #expect(position(2200) == .init(progress: 0.5, publishedAt: Date(timeIntervalSince1970: 2200)))
        #expect(position(2800 + 61) == .init(progress: 0.1, publishedAt: Date(timeIntervalSince1970: 2860)))
        // Without the loop, it stays on the result.
        var once = settings
        once.replayLoop = false
        #expect(once.replayPosition(at: Date(timeIntervalSince1970: 2200)).progress == 1)
    }

    /// The whole lap as the poller and the planner see it: the final push once per lap, then
    /// the count starting over.
    @Test func `Replay loop ends and restarts the count`() throws {
        let settings = ElectionSettings(replayStartedAt: 0, replayDurationMinutes: 10, replayStepSeconds: 60, replayLoop: true, replayLoopPauseMinutes: 5)
        let replay = ElectionReplay(final: try ElectionFixtures.finalPresidentSnapshot())
        let planner = ElectionBroadcastPlanner(minInterval: 30)
        func state(_ seconds: Double) -> ElectionLiveContentState {
            ElectionLiveContentState(snapshot: replay.snapshot(at: settings.replayPosition(at: Date(timeIntervalSince1970: seconds))), settings: settings)
        }
        let beforeEnd = ElectionBroadcastPlanner.Sent(state: state(540), at: Date(timeIntervalSince1970: 540))
        #expect(planner.decide(state(600), lastSent: beforeEnd, now: Date(timeIntervalSince1970: 600))?.event == .end)
        let end = ElectionBroadcastPlanner.Sent(state: state(600), at: Date(timeIntervalSince1970: 600))
        #expect(planner.decide(state(899), lastSent: end, now: Date(timeIntervalSince1970: 899)) == nil)
        let restart = planner.decide(state(900), lastSent: end, now: Date(timeIntervalSince1970: 900))
        #expect(restart?.event == .update)
        #expect(restart?.reason == "count restarted")
        #expect(state(900).sectionsCountedPercent == 0)
    }

    @Test func `Replay without steps moves every poll`() {
        let settings = ElectionSettings(replayStartedAt: 1000, replayDurationMinutes: 10, replayStepSeconds: 0)
        #expect(settings.replayPosition(at: Date(timeIntervalSince1970: 1030)).progress == 0.05)
    }

    // MARK: - Runoff replay

    @Test func `First round replay keeps the simulation result`() throws {
        let first = try ElectionFixtures.finalPresidentSnapshot()
        #expect(ElectionReplay.final(forRound: 1, from: first) == first)
    }

    /// The 2nd round is made up from the simulation's two finalists, 57 and 89.
    @Test func `Runoff replay has the two finalists and a winner`() throws {
        let first = try ElectionFixtures.finalPresidentSnapshot()
        let runoff = ElectionReplay.final(forRound: 2, from: first)
        #expect(runoff.round == 2)
        #expect(runoff.isFinal)
        #expect(runoff.candidates.map(\.number) == [89, 57])
        #expect(runoff.candidates.map(\.status) == [.elected, .notElected])
        #expect(runoff.candidates.allSatisfy { $0.hasValidVotes })
        // Every vote minus blank and null ones: the simulation's own "vvc".
        #expect(runoff.validVotes == 120_704_576)
        #expect(runoff.candidates.map(\.votes).reduce(0, +) == runoff.validVotes)
        #expect(abs(runoff.candidates[0].percent - 50.83) <= 0.01)
        #expect(runoff.turnout == first.turnout)
        #expect(runoff.generationId != first.generationId)
    }

    @Test func `Runoff replay lead changes late in the count`() throws {
        let runoff = ElectionReplay.final(forRound: 2, from: try ElectionFixtures.finalPresidentSnapshot())
        let replay = ElectionReplay(final: runoff)
        #expect(replay.snapshot(at: 0.5).leader?.number == 57)
        #expect(replay.snapshot(at: 0.99).leader?.number == 89)
        #expect(replay.snapshot(at: 1).candidates.first?.status == .elected)
        #expect(replay.snapshot(at: 0.5).candidates.count == 2)
    }

    @Test func `Runoff content state shows the two finalists`() throws {
        let runoff = ElectionReplay.final(forRound: 2, from: try ElectionFixtures.finalPresidentSnapshot())
        let state = ElectionLiveContentState(snapshot: runoff, settings: ElectionSettings(round: 2))
        #expect(state.candidates.map(\.number) == [89, 57])
        #expect(state.isFinal)
    }

    @Test func `Replay not started`() {
        let now = Date(timeIntervalSince1970: 42)
        #expect(ElectionSettings().replayPosition(at: now) == .init(progress: 0, publishedAt: now))
    }

    @Test func `Replay settings update`() {
        let updated = ElectionSettings().applying(.init(replayStepSeconds: 90, replayOffline: true, replayLoop: true, replayLoopPauseMinutes: 2))
        #expect(updated.replayStepSeconds == 90)
        #expect(updated.replayOffline)
        #expect(updated.replayLoop)
        #expect(updated.replayLoopPauseMinutes == 2)
        #expect(!ElectionSettings().replayLoop)
    }

    @Test func `Settings round trip through JSON`() throws {
        let settings = ElectionSettings(enabled: true, source: .replay, round: 2, channelIds: ["app": "abc"], broadcastMode: .live, minPushIntervalSeconds: 45, candidateColors: ["13": "#FF0000"], replayStartedAt: 5, replayStepSeconds: 30, replayOffline: true, finalMessages: ["default": .init(text: "x", alertTitle: "t", alertBody: nil)])
        let decoded = try JSONDecoder().decode(ElectionSettings.self, from: JSONEncoder().encode(settings))
        #expect(decoded == settings)
    }

    // MARK: - Final Message

    private func message(_ text: String) -> ElectionSettings.FinalMessage {
        .init(text: text, alertTitle: nil, alertBody: nil)
    }

    private func electedSnapshot(winner: Int) throws -> ElectionSnapshot {
        let final = try ElectionFixtures.finalPresidentSnapshot()
        let candidates = final.candidates.map { candidate in
            ElectionSnapshot.Candidate(
                number: candidate.number, name: candidate.name, party: candidate.party, votes: candidate.votes,
                percent: candidate.percent, status: candidate.number == winner ? .elected : .notElected,
                hasValidVotes: candidate.hasValidVotes
            )
        }
        return ElectionSnapshot(
            electionCode: final.electionCode, round: 2, generationId: final.generationId, totalizedAt: final.totalizedAt,
            isFinal: true, sectionsTotal: final.sectionsTotal, sectionsCounted: final.sectionsCounted,
            sectionsCountedPercent: 100, validVotes: final.validVotes, candidates: candidates
        )
    }

    @Test func `Final message prefers the most specific key`() throws {
        // The simulation ends in a runoff between 57 and 89.
        let runoff = try ElectionFixtures.finalPresidentSnapshot()
        var settings = ElectionSettings(finalMessages: ["default": message("d"), "runoff": message("r")])
        #expect(settings.finalMessage(for: runoff)?.text == "r")
        settings.finalMessages["runoff:57-89"] = message("57 x 89")
        #expect(settings.finalMessage(for: runoff)?.text == "57 x 89")

        let elected = try electedSnapshot(winner: 89)
        #expect(settings.finalMessage(for: elected)?.text == "d")
        settings.finalMessages["elected:89"] = message("89 eleito")
        settings.finalMessages["elected:57"] = message("57 eleito")
        #expect(settings.finalMessage(for: elected)?.text == "89 eleito")
    }

    @Test func `Final message fills the vote margin`() throws {
        let elected = try electedSnapshot(winner: 89)
        let votes = elected.candidates.filter(\.hasValidVotes).map(\.votes).sorted(by: >)
        let margin = ElectionSettings.FinalMessage.formattedCount(votes[0] - votes[1])
        let settings = ElectionSettings(finalMessages: [
            "elected": .init(text: "Venceu por {diferença} votos. Um deles foi seu.", alertTitle: "{diferenca} votos!", alertBody: nil),
        ])

        let message = try #require(settings.finalMessage(for: elected))
        #expect(message.text == "Venceu por \(margin) votos. Um deles foi seu.")
        #expect(message.alertTitle == "\(margin) votos!")
        #expect(message.alertBody == nil)
        #expect(ElectionLiveContentState(snapshot: elected, settings: settings).finalMessage == message.text)
        #expect(settings.finalMessages["elected"]?.text == "Venceu por {diferença} votos. Um deles foi seu.", "the saved text keeps the placeholder")
    }

    @Test func `Final message keeps its theme and decodes without one`() throws {
        let elected = try electedSnapshot(winner: 89)
        let settings = ElectionSettings(finalMessages: [
            "elected:89": .init(text: "Por {diferença} votos", alertTitle: nil, alertBody: nil, theme: "celebration"),
        ])
        #expect(settings.finalMessage(for: elected)?.theme == "celebration", "filling the placeholders keeps it")

        // Messages saved before the theme existed.
        let saved = #"{"finalMessages":{"default":{"text":"Acabou"}}}"#
        let decoded = try JSONDecoder().decode(ElectionSettings.self, from: Data(saved.utf8))
        #expect(decoded.finalMessages["default"]?.theme == nil)
    }

    @Test func `Formatted count groups thousands with dots`() {
        #expect(ElectionSettings.FinalMessage.formattedCount(0) == "0")
        #expect(ElectionSettings.FinalMessage.formattedCount(999) == "999")
        #expect(ElectionSettings.FinalMessage.formattedCount(1_000) == "1.000")
        #expect(ElectionSettings.FinalMessage.formattedCount(2_003_696) == "2.003.696")
        #expect(ElectionSettings.FinalMessage.formattedCount(-12_345) == "-12.345")
    }

    @Test func `No final message before the end or without a match`() throws {
        let settings = ElectionSettings(finalMessages: ["elected:13": message("x")])
        #expect(settings.finalMessage(for: try ElectionFixtures.finalPresidentSnapshot()) == nil)
        let counting = ElectionReplay(final: try ElectionFixtures.finalPresidentSnapshot()).snapshot(at: 0.5)
        #expect(ElectionSettings(finalMessages: ["default": message("x")]).finalMessage(for: counting) == nil)
    }

    @Test func `Content state carries final message only when final`() throws {
        let settings = ElectionSettings(finalMessages: ["default": message("Acabou")])
        let final = try ElectionFixtures.finalPresidentSnapshot()
        #expect(ElectionLiveContentState(snapshot: final, settings: settings).finalMessage == "Acabou")

        let counting = ElectionReplay(final: final).snapshot(at: 0.5)
        let state = ElectionLiveContentState(snapshot: counting, settings: settings)
        #expect(state.finalMessage == nil)
        let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        #expect(json["finalMessage"] == nil, "left out of the JSON when nil")
    }

    @Test func `Final messages merge and null removes`() throws {
        let settings = ElectionSettings(finalMessages: ["default": message("a"), "runoff": message("b")])
        let json = #"{"finalMessages":{"runoff":null,"elected:13":{"text":"c","alertTitle":"t"}}}"#
        let update = try JSONDecoder().decode(ElectionSettings.Update.self, from: Data(json.utf8))
        let updated = settings.applying(update)
        #expect(Set(updated.finalMessages.keys) == ["default", "elected:13"])
        #expect(updated.finalMessages["elected:13"]?.alertTitle == "t")
        #expect(updated.finalMessages["elected:13"]?.alertBody == nil)
    }

    // MARK: - Store

    @Test func `Store ignores same generation`() async throws {
        let store = ElectionLiveStore()
        let snapshot = try ElectionFixtures.finalPresidentSnapshot()
        let first = await store.update(snapshot: snapshot, etag: "a", at: .now)
        let second = await store.update(snapshot: snapshot, etag: "b", at: .now)
        #expect(first)
        #expect(!second)
        let etag = await store.etag
        #expect(etag == "b")
    }

    @Test func `Store resets when target changes`() async throws {
        let store = ElectionLiveStore()
        await store.prepare(for: .init(source: .simulation, round: 1))
        await store.setResolvedElection(.init(cycle: "ele2026", electionCode: "21270"), checkedAt: .now)
        await store.update(snapshot: try ElectionFixtures.finalPresidentSnapshot(), etag: "a", at: .now)

        let sameTarget = await store.prepare(for: .init(source: .simulation, round: 1))
        #expect(!sameTarget)
        let snapshotAfterSameTarget = await store.snapshot
        #expect(snapshotAfterSameTarget != nil)

        let newTarget = await store.prepare(for: .init(source: .official, round: 1))
        #expect(newTarget)
        let snapshot = await store.snapshot
        let resolved = await store.resolvedElection
        let etag = await store.etag
        #expect(snapshot == nil)
        #expect(resolved == nil)
        #expect(etag == nil)
    }

    @Test func `Store forgets election on not found`() async {
        let store = ElectionLiveStore()
        await store.setResolvedElection(.init(cycle: "ele2026", electionCode: "21270"), checkedAt: .now)
        await store.markNotFound(at: .now)
        let resolved = await store.resolvedElection
        let lastConfigCheckAt = await store.lastConfigCheckAt
        #expect(resolved == nil)
        // Kept, so the poller waits before asking ele-c.json again.
        #expect(lastConfigCheckAt != nil)
    }
}
