@testable import App
import XCTVapor

final class ElectionLiveTests: XCTestCase {

    // MARK: - Content State

    func testContentStateKeepsTopFourInFirstRound() throws {
        let snapshot = try ElectionFixtures.finalPresidentSnapshot()
        let state = ElectionLiveContentState(snapshot: snapshot, candidateColors: [:])
        XCTAssertEqual(state.candidates.map(\.number), [57, 89, 68, 88])
        XCTAssertEqual(state.sectionsCountedPercent, 100)
        XCTAssertTrue(state.isFinal)
        XCTAssertEqual(state.updatedAt, 1790277154)
    }

    func testContentStateAppliesColorsByBallotNumber() throws {
        let snapshot = try ElectionFixtures.finalPresidentSnapshot()
        let state = ElectionLiveContentState(snapshot: snapshot, candidateColors: ["89": "#D62828"])
        XCTAssertEqual(state.candidates[1].colorHex, "#D62828")
        XCTAssertNil(state.candidates[0].colorHex)
    }

    func testContentStateUsesFallbackDateWithoutTotalizationTime() throws {
        let final = try ElectionFixtures.finalPresidentSnapshot()
        let snapshot = ElectionSnapshot(
            electionCode: final.electionCode, round: 2, generationId: "1", totalizedAt: nil, isFinal: false,
            sectionsTotal: 10, sectionsCounted: 0, sectionsCountedPercent: 0, validVotes: 0, candidates: final.candidates
        )
        let state = ElectionLiveContentState(snapshot: snapshot, candidateColors: [:], fallbackDate: Date(timeIntervalSince1970: 42))
        XCTAssertEqual(state.updatedAt, 42)
        XCTAssertEqual(state.candidates.count, 2)
    }

    /// Must match `ElectionActivityAttributes.ContentState` in the iOS app, or ActivityKit
    /// drops the push.
    func testContentStateWireFormat() throws {
        let snapshot = try ElectionFixtures.finalPresidentSnapshot()
        let state = ElectionLiveContentState(snapshot: snapshot, candidateColors: [:])
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        XCTAssertEqual(Set(json.keys), ["sectionsCountedPercent", "isFinal", "updatedAt", "candidates"])
        let candidate = try XCTUnwrap((json["candidates"] as? [[String: Any]])?.first)
        XCTAssertEqual(Set(candidate.keys), ["number", "name", "party", "percent", "status"])
        XCTAssertEqual(candidate["status"] as? String, "runoff")
    }

    // MARK: - Details

    func testDetailsKeepEveryCandidateWithVotes() throws {
        let snapshot = try ElectionFixtures.finalPresidentSnapshot()
        let details = ElectionLiveDetails(snapshot: snapshot, candidateColors: ["57": "#1D4E89"])
        XCTAssertEqual(details.candidates.map(\.number), snapshot.candidates.map(\.number))
        XCTAssertEqual(details.candidates.map(\.votes), snapshot.candidates.map(\.votes))
        XCTAssertEqual(details.sectionsTotal, snapshot.sectionsTotal)
        XCTAssertEqual(details.validVotes, snapshot.validVotes)
        XCTAssertEqual(details.candidates.first { $0.number == 57 }?.colorHex, "#1D4E89")
        XCTAssertGreaterThan(details.candidates.count, ElectionLiveContentState(snapshot: snapshot, candidateColors: [:]).candidates.count)
    }

    func testOfficialResultsURLDefaultsAndResets() throws {
        XCTAssertEqual(ElectionSettings().officialResultsURL, ElectionSettings.defaultOfficialResultsURL)
        let pointed = ElectionSettings().applying(.init(officialResultsURL: "https://resultados.tse.jus.br/oficial/app/index.html"))
        XCTAssertEqual(pointed.officialResultsURL, "https://resultados.tse.jus.br/oficial/app/index.html")
        XCTAssertEqual(pointed.applying(.init(officialResultsURL: "")).officialResultsURL, ElectionSettings.defaultOfficialResultsURL)
        // Settings saved before the field existed still load.
        let old = try JSONDecoder().decode(ElectionSettings.self, from: Data(#"{"enabled":true}"#.utf8))
        XCTAssertEqual(old.officialResultsURL, ElectionSettings.defaultOfficialResultsURL)
    }

    // MARK: - Settings

    func testSettingsDefaultsAreSafe() {
        let settings = ElectionSettings()
        XCTAssertFalse(settings.enabled)
        XCTAssertEqual(settings.source, .simulation)
        XCTAssertEqual(settings.round, 1)
        XCTAssertEqual(settings.endpoint, .simulation)
    }

    func testSettingsPartialUpdateKeepsOtherFields() {
        let settings = ElectionSettings(enabled: true, channelIds: ["app": "abc"], candidateColors: ["13": "#FF0000"])
        let updated = settings.applying(.init(source: .official))
        XCTAssertEqual(updated.source, .official)
        XCTAssertEqual(updated.endpoint, .official)
        XCTAssertTrue(updated.enabled)
        XCTAssertEqual(updated.channelIds, ["app": "abc"])
        XCTAssertEqual(updated.candidateColors, ["13": "#FF0000"])
    }

    func testChannelIdsMergeByBundleAndEmptyClears() {
        let settings = ElectionSettings(channelIds: ["prod": "abc", "beta": "def"])
        XCTAssertEqual(settings.applying(.init(channelIds: ["beta": "xyz"])).channelIds, ["prod": "abc", "beta": "xyz"])
        XCTAssertEqual(settings.applying(.init(channelIds: ["prod": ""])).channelIds, ["beta": "def"])
    }

    func testChannelLookupHasNoFallbackBetweenApps() {
        let settings = ElectionSettings(channelIds: [ElectionSettings.productionBundleId: "prod-channel"])
        XCTAssertEqual(settings.channelId(forBundleId: ElectionSettings.productionBundleId), "prod-channel")
        XCTAssertEqual(settings.channelId(forBundleId: nil), "prod-channel")
        // The beta app can't subscribe to production's channel.
        XCTAssertNil(settings.channelId(forBundleId: ElectionSettings.betaBundleId))
    }

    /// Settings saved before a field existed must still load, or the poller stops.
    func testSettingsDecodeWithMissingKeys() throws {
        let json = #"{"enabled":true,"source":"official","round":1,"candidateColors":{}}"#
        let settings = try JSONDecoder().decode(ElectionSettings.self, from: Data(json.utf8))
        XCTAssertTrue(settings.enabled)
        XCTAssertEqual(settings.source, .official)
        XCTAssertEqual(settings.channelIds, [:])
        XCTAssertEqual(settings.broadcastMode, .dryRun)
        XCTAssertEqual(settings.minPushIntervalSeconds, 30)
        XCTAssertEqual(settings.replayDurationMinutes, 20)
        XCTAssertEqual(settings.replayStepSeconds, 60)
        XCTAssertFalse(settings.replayOffline)
        XCTAssertEqual(settings.finalMessages, [:])
        XCTAssertEqual(settings.previewVersions, [])
    }

    // MARK: - Preview versions

    /// The version in App Review sees the feature while the one in the store doesn't.
    func testPreviewVersionsSeeTheFeatureBeforeTheLaunch() {
        let settings = ElectionSettings(previewVersions: ["13.2"])
        XCTAssertTrue(settings.isEnabled(forAppVersion: "13.2"))
        XCTAssertFalse(settings.isEnabled(forAppVersion: "13.1"))
        // 13.0 doesn't send its version.
        XCTAssertFalse(settings.isEnabled(forAppVersion: nil))
        XCTAssertFalse(ElectionSettings().isEnabled(forAppVersion: "13.2"))
        // After the launch, everyone.
        let launched = ElectionSettings(enabled: true)
        XCTAssertTrue(launched.isEnabled(forAppVersion: "13.1"))
        XCTAssertTrue(launched.isEnabled(forAppVersion: nil))
    }

    func testPreviewVersionsUpdateReplacesTheList() {
        let settings = ElectionSettings(previewVersions: ["13.1"])
        XCTAssertEqual(settings.applying(.init(previewVersions: ["13.2", "13.3"])).previewVersions, ["13.2", "13.3"])
        XCTAssertEqual(settings.applying(.init(previewVersions: [])).previewVersions, [])
        XCTAssertEqual(settings.applying(.init(source: .replay)).previewVersions, ["13.1"])
    }

    func testBroadcastSettingsUpdate() {
        let updated = ElectionSettings().applying(.init(broadcastMode: .live, minPushIntervalSeconds: 60))
        XCTAssertEqual(updated.broadcastMode, .live)
        XCTAssertEqual(updated.minPushIntervalSeconds, 60)
    }

    func testSwitchingToReplayStartsIt() {
        let now = Date(timeIntervalSince1970: 1000)
        let settings = ElectionSettings().applying(.init(source: .replay), now: now)
        XCTAssertEqual(settings.replayStartedAt, 1000)
        // Already on replay: only an explicit restart moves the start.
        XCTAssertEqual(settings.applying(.init(source: .replay), now: Date(timeIntervalSince1970: 2000)).replayStartedAt, 1000)
        XCTAssertEqual(settings.applying(.init(restartReplay: true), now: Date(timeIntervalSince1970: 2000)).replayStartedAt, 2000)
    }

    func testReplayMovesInSteps() {
        let settings = ElectionSettings(replayStartedAt: 1000, replayDurationMinutes: 10, replayStepSeconds: 60)
        func position(_ seconds: Double) -> ElectionSettings.ReplayPosition {
            settings.replayPosition(at: Date(timeIntervalSince1970: seconds))
        }
        XCTAssertEqual(position(500), .init(progress: 0, publishedAt: Date(timeIntervalSince1970: 1000)))
        XCTAssertEqual(position(1059), .init(progress: 0, publishedAt: Date(timeIntervalSince1970: 1000)))
        XCTAssertEqual(position(1061), .init(progress: 0.1, publishedAt: Date(timeIntervalSince1970: 1060)))
        XCTAssertEqual(position(1300), .init(progress: 0.5, publishedAt: Date(timeIntervalSince1970: 1300)))
        XCTAssertEqual(position(9999), .init(progress: 1, publishedAt: Date(timeIntervalSince1970: 1600)))
    }

    func testReplayLastStepLandsOnTheEnd() {
        // 10 minutes in steps of 7 minutes: 0, 7, then straight to 10.
        let settings = ElectionSettings(replayStartedAt: 0, replayDurationMinutes: 10, replayStepSeconds: 420)
        XCTAssertEqual(settings.replayPosition(at: Date(timeIntervalSince1970: 599)).progress, 0.7)
        XCTAssertEqual(settings.replayPosition(at: Date(timeIntervalSince1970: 600)).progress, 1)
    }

    func testReplayLoopsAfterThePauseOnTheFinalResult() {
        // 10-minute count, 5-minute pause: laps of 15 minutes starting at 1000, 1900, 2800…
        let settings = ElectionSettings(replayStartedAt: 1000, replayDurationMinutes: 10, replayStepSeconds: 60, replayLoop: true, replayLoopPauseMinutes: 5)
        func position(_ seconds: Double) -> ElectionSettings.ReplayPosition {
            settings.replayPosition(at: Date(timeIntervalSince1970: seconds))
        }
        XCTAssertEqual(position(1600), .init(progress: 1, publishedAt: Date(timeIntervalSince1970: 1600)))
        XCTAssertEqual(position(1899), .init(progress: 1, publishedAt: Date(timeIntervalSince1970: 1600)))
        XCTAssertEqual(position(1900), .init(progress: 0, publishedAt: Date(timeIntervalSince1970: 1900)))
        XCTAssertEqual(position(2200), .init(progress: 0.5, publishedAt: Date(timeIntervalSince1970: 2200)))
        XCTAssertEqual(position(2800 + 61), .init(progress: 0.1, publishedAt: Date(timeIntervalSince1970: 2860)))
        // Without the loop, it stays on the result.
        var once = settings
        once.replayLoop = false
        XCTAssertEqual(once.replayPosition(at: Date(timeIntervalSince1970: 2200)).progress, 1)
    }

    /// The whole lap as the poller and the planner see it: the final push once per lap, then
    /// the count starting over.
    func testReplayLoopEndsAndRestartsTheCount() throws {
        let settings = ElectionSettings(replayStartedAt: 0, replayDurationMinutes: 10, replayStepSeconds: 60, replayLoop: true, replayLoopPauseMinutes: 5)
        let replay = ElectionReplay(final: try ElectionFixtures.finalPresidentSnapshot())
        let planner = ElectionBroadcastPlanner(minInterval: 30)
        func state(_ seconds: Double) -> ElectionLiveContentState {
            ElectionLiveContentState(snapshot: replay.snapshot(at: settings.replayPosition(at: Date(timeIntervalSince1970: seconds))), settings: settings)
        }
        let beforeEnd = ElectionBroadcastPlanner.Sent(state: state(540), at: Date(timeIntervalSince1970: 540))
        XCTAssertEqual(planner.decide(state(600), lastSent: beforeEnd, now: Date(timeIntervalSince1970: 600))?.event, .end)
        let end = ElectionBroadcastPlanner.Sent(state: state(600), at: Date(timeIntervalSince1970: 600))
        XCTAssertNil(planner.decide(state(899), lastSent: end, now: Date(timeIntervalSince1970: 899)))
        let restart = planner.decide(state(900), lastSent: end, now: Date(timeIntervalSince1970: 900))
        XCTAssertEqual(restart?.event, .update)
        XCTAssertEqual(restart?.reason, "count restarted")
        XCTAssertEqual(state(900).sectionsCountedPercent, 0)
    }

    func testReplayWithoutStepsMovesEveryPoll() {
        let settings = ElectionSettings(replayStartedAt: 1000, replayDurationMinutes: 10, replayStepSeconds: 0)
        XCTAssertEqual(settings.replayPosition(at: Date(timeIntervalSince1970: 1030)).progress, 0.05)
    }

    // MARK: - Runoff replay

    func testFirstRoundReplayKeepsTheSimulationResult() throws {
        let first = try ElectionFixtures.finalPresidentSnapshot()
        XCTAssertEqual(ElectionReplay.final(forRound: 1, from: first), first)
    }

    /// The 2nd round is made up from the simulation's two finalists, 57 and 89.
    func testRunoffReplayHasTheTwoFinalistsAndAWinner() throws {
        let first = try ElectionFixtures.finalPresidentSnapshot()
        let runoff = ElectionReplay.final(forRound: 2, from: first)
        XCTAssertEqual(runoff.round, 2)
        XCTAssertTrue(runoff.isFinal)
        XCTAssertEqual(runoff.candidates.map(\.number), [89, 57])
        XCTAssertEqual(runoff.candidates.map(\.status), [.elected, .notElected])
        XCTAssertTrue(runoff.candidates.allSatisfy(\.hasValidVotes))
        // Every vote minus blank and null ones: the simulation's own "vvc".
        XCTAssertEqual(runoff.validVotes, 120_704_576)
        XCTAssertEqual(runoff.candidates.map(\.votes).reduce(0, +), runoff.validVotes)
        XCTAssertEqual(runoff.candidates[0].percent, 50.83, accuracy: 0.01)
        XCTAssertEqual(runoff.turnout, first.turnout)
        XCTAssertNotEqual(runoff.generationId, first.generationId)
    }

    func testRunoffReplayLeadChangesLateInTheCount() throws {
        let runoff = ElectionReplay.final(forRound: 2, from: try ElectionFixtures.finalPresidentSnapshot())
        let replay = ElectionReplay(final: runoff)
        XCTAssertEqual(replay.snapshot(at: 0.5).leader?.number, 57)
        XCTAssertEqual(replay.snapshot(at: 0.99).leader?.number, 89)
        XCTAssertEqual(replay.snapshot(at: 1).candidates.first?.status, .elected)
        XCTAssertEqual(replay.snapshot(at: 0.5).candidates.count, 2)
    }

    func testRunoffContentStateShowsTheTwoFinalists() throws {
        let runoff = ElectionReplay.final(forRound: 2, from: try ElectionFixtures.finalPresidentSnapshot())
        let state = ElectionLiveContentState(snapshot: runoff, settings: ElectionSettings(round: 2))
        XCTAssertEqual(state.candidates.map(\.number), [89, 57])
        XCTAssertTrue(state.isFinal)
    }

    func testReplayNotStarted() {
        let now = Date(timeIntervalSince1970: 42)
        XCTAssertEqual(ElectionSettings().replayPosition(at: now), .init(progress: 0, publishedAt: now))
    }

    func testReplaySettingsUpdate() {
        let updated = ElectionSettings().applying(.init(replayStepSeconds: 90, replayOffline: true, replayLoop: true, replayLoopPauseMinutes: 2))
        XCTAssertEqual(updated.replayStepSeconds, 90)
        XCTAssertTrue(updated.replayOffline)
        XCTAssertTrue(updated.replayLoop)
        XCTAssertEqual(updated.replayLoopPauseMinutes, 2)
        XCTAssertFalse(ElectionSettings().replayLoop)
    }

    func testSettingsRoundTripThroughJSON() throws {
        let settings = ElectionSettings(enabled: true, source: .replay, round: 2, channelIds: ["app": "abc"], broadcastMode: .live, minPushIntervalSeconds: 45, candidateColors: ["13": "#FF0000"], replayStartedAt: 5, replayStepSeconds: 30, replayOffline: true, finalMessages: ["default": .init(text: "x", alertTitle: "t", alertBody: nil)])
        let decoded = try JSONDecoder().decode(ElectionSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(decoded, settings)
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

    func testFinalMessagePrefersTheMostSpecificKey() throws {
        // The simulation ends in a runoff between 57 and 89.
        let runoff = try ElectionFixtures.finalPresidentSnapshot()
        var settings = ElectionSettings(finalMessages: ["default": message("d"), "runoff": message("r")])
        XCTAssertEqual(settings.finalMessage(for: runoff)?.text, "r")
        settings.finalMessages["runoff:57-89"] = message("57 x 89")
        XCTAssertEqual(settings.finalMessage(for: runoff)?.text, "57 x 89")

        let elected = try electedSnapshot(winner: 89)
        XCTAssertEqual(settings.finalMessage(for: elected)?.text, "d")
        settings.finalMessages["elected:89"] = message("89 eleito")
        settings.finalMessages["elected:57"] = message("57 eleito")
        XCTAssertEqual(settings.finalMessage(for: elected)?.text, "89 eleito")
    }

    func testNoFinalMessageBeforeTheEndOrWithoutAMatch() throws {
        let settings = ElectionSettings(finalMessages: ["elected:13": message("x")])
        XCTAssertNil(settings.finalMessage(for: try ElectionFixtures.finalPresidentSnapshot()))
        let counting = ElectionReplay(final: try ElectionFixtures.finalPresidentSnapshot()).snapshot(at: 0.5)
        XCTAssertNil(ElectionSettings(finalMessages: ["default": message("x")]).finalMessage(for: counting))
    }

    func testContentStateCarriesFinalMessageOnlyWhenFinal() throws {
        let settings = ElectionSettings(finalMessages: ["default": message("Acabou")])
        let final = try ElectionFixtures.finalPresidentSnapshot()
        XCTAssertEqual(ElectionLiveContentState(snapshot: final, settings: settings).finalMessage, "Acabou")

        let counting = ElectionReplay(final: final).snapshot(at: 0.5)
        let state = ElectionLiveContentState(snapshot: counting, settings: settings)
        XCTAssertNil(state.finalMessage)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        XCTAssertNil(json["finalMessage"], "left out of the JSON when nil")
    }

    func testFinalMessagesMergeAndNullRemoves() throws {
        let settings = ElectionSettings(finalMessages: ["default": message("a"), "runoff": message("b")])
        let json = #"{"finalMessages":{"runoff":null,"elected:13":{"text":"c","alertTitle":"t"}}}"#
        let update = try JSONDecoder().decode(ElectionSettings.Update.self, from: Data(json.utf8))
        let updated = settings.applying(update)
        XCTAssertEqual(Set(updated.finalMessages.keys), ["default", "elected:13"])
        XCTAssertEqual(updated.finalMessages["elected:13"]?.alertTitle, "t")
        XCTAssertNil(updated.finalMessages["elected:13"]?.alertBody)
    }

    // MARK: - Store

    func testStoreIgnoresSameGeneration() async throws {
        let store = ElectionLiveStore()
        let snapshot = try ElectionFixtures.finalPresidentSnapshot()
        let first = await store.update(snapshot: snapshot, etag: "a", at: .now)
        let second = await store.update(snapshot: snapshot, etag: "b", at: .now)
        XCTAssertTrue(first)
        XCTAssertFalse(second)
        let etag = await store.etag
        XCTAssertEqual(etag, "b")
    }

    func testStoreResetsWhenTargetChanges() async throws {
        let store = ElectionLiveStore()
        await store.prepare(for: .init(source: .simulation, round: 1))
        await store.setResolvedElection(.init(cycle: "ele2026", electionCode: "21270"), checkedAt: .now)
        await store.update(snapshot: try ElectionFixtures.finalPresidentSnapshot(), etag: "a", at: .now)

        let sameTarget = await store.prepare(for: .init(source: .simulation, round: 1))
        XCTAssertFalse(sameTarget)
        let snapshotAfterSameTarget = await store.snapshot
        XCTAssertNotNil(snapshotAfterSameTarget)

        let newTarget = await store.prepare(for: .init(source: .official, round: 1))
        XCTAssertTrue(newTarget)
        let snapshot = await store.snapshot
        let resolved = await store.resolvedElection
        let etag = await store.etag
        XCTAssertNil(snapshot)
        XCTAssertNil(resolved)
        XCTAssertNil(etag)
    }

    func testStoreForgetsElectionOnNotFound() async {
        let store = ElectionLiveStore()
        await store.setResolvedElection(.init(cycle: "ele2026", electionCode: "21270"), checkedAt: .now)
        await store.markNotFound(at: .now)
        let resolved = await store.resolvedElection
        let lastConfigCheckAt = await store.lastConfigCheckAt
        XCTAssertNil(resolved)
        // Kept, so the poller waits before asking ele-c.json again.
        XCTAssertNotNil(lastConfigCheckAt)
    }
}
