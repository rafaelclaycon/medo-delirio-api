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

    // MARK: - Settings

    func testSettingsDefaultsAreSafe() {
        let settings = ElectionSettings()
        XCTAssertFalse(settings.enabled)
        XCTAssertEqual(settings.source, .simulation)
        XCTAssertEqual(settings.round, 1)
        XCTAssertEqual(settings.endpoint, .simulation)
    }

    func testSettingsPartialUpdateKeepsOtherFields() {
        let settings = ElectionSettings(enabled: true, channelId: "abc", candidateColors: ["13": "#FF0000"])
        let updated = settings.applying(.init(source: .official))
        XCTAssertEqual(updated.source, .official)
        XCTAssertEqual(updated.endpoint, .official)
        XCTAssertTrue(updated.enabled)
        XCTAssertEqual(updated.channelId, "abc")
        XCTAssertEqual(updated.candidateColors, ["13": "#FF0000"])
    }

    func testEmptyChannelIdClearsIt() {
        let settings = ElectionSettings(channelId: "abc")
        XCTAssertNil(settings.applying(.init(channelId: "")).channelId)
    }

    func testSwitchingToReplayStartsIt() {
        let now = Date(timeIntervalSince1970: 1000)
        let settings = ElectionSettings().applying(.init(source: .replay), now: now)
        XCTAssertEqual(settings.replayStartedAt, 1000)
        // Already on replay: only an explicit restart moves the start.
        XCTAssertEqual(settings.applying(.init(source: .replay), now: Date(timeIntervalSince1970: 2000)).replayStartedAt, 1000)
        XCTAssertEqual(settings.applying(.init(restartReplay: true), now: Date(timeIntervalSince1970: 2000)).replayStartedAt, 2000)
    }

    func testReplayProgress() {
        let settings = ElectionSettings(replayStartedAt: 1000, replayDurationMinutes: 10)
        XCTAssertEqual(settings.replayProgress(at: Date(timeIntervalSince1970: 500)), 0)
        XCTAssertEqual(settings.replayProgress(at: Date(timeIntervalSince1970: 1300)), 0.5)
        XCTAssertEqual(settings.replayProgress(at: Date(timeIntervalSince1970: 9999)), 1)
        XCTAssertEqual(ElectionSettings().replayProgress(at: .now), 0)
    }

    func testSettingsRoundTripThroughJSON() throws {
        let settings = ElectionSettings(enabled: true, source: .replay, round: 2, channelId: "abc", candidateColors: ["13": "#FF0000"], replayStartedAt: 5)
        let decoded = try JSONDecoder().decode(ElectionSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(decoded, settings)
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
