@testable import App
import XCTVapor

final class ElectionBroadcastPlannerTests: XCTestCase {

    private let planner = ElectionBroadcastPlanner(minInterval: 30)
    private let start = Date(timeIntervalSince1970: 1_790_000_000)

    private func state(at progress: Double) throws -> ElectionLiveContentState {
        let final = try ElectionFixtures.finalPresidentSnapshot()
        return ElectionLiveContentState(snapshot: ElectionReplay(final: final).snapshot(at: progress), candidateColors: [:])
    }

    private func sent(_ state: ElectionLiveContentState, secondsAgo: TimeInterval) -> ElectionBroadcastPlanner.Sent {
        .init(state: state, at: start.addingTimeInterval(-secondsAgo))
    }

    // MARK: - Decisions

    func testFirstPushIsHighPriority() throws {
        let decision = planner.decide(try state(at: 0.3), lastSent: nil, now: start)
        XCTAssertEqual(decision?.event, .update)
        XCTAssertEqual(decision?.priority, 10)
    }

    func testAlreadyFinalResultIsNotAnnounced() throws {
        XCTAssertNil(planner.decide(try state(at: 1), lastSent: nil, now: start))
    }

    func testSameStateIsNotSentAgain() throws {
        let current = try state(at: 0.3)
        XCTAssertNil(planner.decide(current, lastSent: sent(current, secondsAgo: 600), now: start))
    }

    func testOrdinaryUpdateWaitsForTheInterval() throws {
        let previous = try state(at: 0.31)
        let current = try state(at: 0.32)
        XCTAssertNil(planner.decide(current, lastSent: sent(previous, secondsAgo: 10), now: start))

        let decision = planner.decide(current, lastSent: sent(previous, secondsAgo: 30), now: start)
        XCTAssertEqual(decision?.event, .update)
        XCTAssertEqual(decision?.priority, 5)
    }

    func testCrossingTenPercentIsHighPriority() throws {
        let decision = planner.decide(try state(at: 0.41), lastSent: sent(try state(at: 0.39), secondsAgo: 60), now: start)
        XCTAssertEqual(decision?.priority, 10)
        XCTAssertEqual(decision?.reason, "40% counted")
    }

    func testNewLeaderIsHighPriority() throws {
        let before = try state(at: 0.51)
        var after = try state(at: 0.52)
        after.candidates.swapAt(0, 1)
        XCTAssertEqual(ElectionBroadcastPlanner.milestone(of: before), ElectionBroadcastPlanner.milestone(of: after))

        XCTAssertNil(planner.decide(after, lastSent: sent(before, secondsAgo: 10), now: start), "a new leader still waits for the interval")
        let decision = planner.decide(after, lastSent: sent(before, secondsAgo: 60), now: start)
        XCTAssertEqual(decision?.priority, 10)
        XCTAssertEqual(decision?.reason, "new leader")
    }

    func testFinalResultEndsRightAwayIgnoringTheInterval() throws {
        let decision = planner.decide(try state(at: 1), lastSent: sent(try state(at: 0.99), secondsAgo: 1), now: start)
        XCTAssertEqual(decision?.event, .end)
        XCTAssertEqual(decision?.priority, 10)
    }

    func testReplayRestartAfterTheEndIsSentRightAway() throws {
        let decision = planner.decide(try state(at: 0), lastSent: sent(try state(at: 1), secondsAgo: 1), now: start)
        XCTAssertEqual(decision?.event, .update)
        XCTAssertEqual(decision?.priority, 10)
    }

    // MARK: - Payload

    func testUpdatePayload() throws {
        let current = try state(at: 0.5)
        let decision = ElectionBroadcastPlanner.Decision(event: .update, priority: 5, reason: "progress")
        let json = try payloadJSON(current, decision)
        let aps = try XCTUnwrap(json["aps"] as? [String: Any])

        XCTAssertEqual(Set(aps.keys), ["timestamp", "event", "content-state", "stale-date"])
        XCTAssertEqual(aps["event"] as? String, "update")
        XCTAssertEqual(aps["timestamp"] as? Int, 1_790_000_000)
        XCTAssertEqual(aps["stale-date"] as? Int, 1_790_000_000 + 15 * 60)
        XCTAssertEqual(ElectionBroadcastPlanner.expiration(for: decision, now: start), 1_790_000_000 + 15 * 60)

        // Must decode exactly like the app's ContentState.
        let contentState = try XCTUnwrap(aps["content-state"] as? [String: Any])
        XCTAssertEqual(Set(contentState.keys), ["sectionsCountedPercent", "isFinal", "updatedAt", "candidates"])
        let decoded = try JSONDecoder().decode(ElectionLiveContentState.self, from: JSONSerialization.data(withJSONObject: contentState))
        XCTAssertEqual(decoded, current)
    }

    func testEndPayloadHasDismissalDateAndAlert() throws {
        let decision = ElectionBroadcastPlanner.Decision(event: .end, priority: 10, reason: "final result")
        let aps = try XCTUnwrap(try payloadJSON(try state(at: 1), decision)["aps"] as? [String: Any])

        XCTAssertEqual(Set(aps.keys), ["timestamp", "event", "content-state", "dismissal-date", "alert"])
        XCTAssertEqual(aps["event"] as? String, "end")
        XCTAssertEqual(aps["dismissal-date"] as? Int, 1_790_000_000 + 4 * 60 * 60)
        let alert = try XCTUnwrap(aps["alert"] as? [String: String])
        XCTAssertEqual(alert["title"], "Apuração encerrada")
        // The simulation goes to a runoff.
        XCTAssertTrue(try XCTUnwrap(alert["body"]).hasSuffix("vão para o 2º turno."))
    }

    func testPayloadFitsInBroadcastLimit() throws {
        let decision = ElectionBroadcastPlanner.Decision(event: .end, priority: 10, reason: "final result")
        let data = try JSONEncoder().encode(ElectionBroadcastPlanner.payload(for: try state(at: 1), decision: decision, now: start))
        XCTAssertLessThan(data.count, 5_120)
    }

    func testElectedAlert() throws {
        let winner = ElectionLiveContentState.Candidate(number: 13, name: "FULANO", party: "ABC", percent: 52.31, status: .elected, colorHex: nil)
        let other = ElectionLiveContentState.Candidate(number: 22, name: "CICLANO", party: "XYZ", percent: 47.69, status: .notElected, colorHex: nil)
        var content = try state(at: 1)
        content.candidates = [winner, other]
        XCTAssertEqual(ElectionBroadcastPlanner.finalAlert(for: content).body, "FULANO (ABC) vence com 52,31% dos votos válidos.")
    }

    private func payloadJSON(_ state: ElectionLiveContentState, _ decision: ElectionBroadcastPlanner.Decision) throws -> [String: Any] {
        let data = try JSONEncoder().encode(ElectionBroadcastPlanner.payload(for: state, decision: decision, now: start))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
