@testable import App
import XCTVapor

/// Fixtures are real files from the TSE simulation environment (simulado2026), captured
/// after the 24/09/2026 run finished with 100% of sections counted.
enum ElectionFixtures {

    static func data(_ name: String) throws -> Data {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Election/\(name)")
        return try Data(contentsOf: url)
    }

    static func finalPresidentSnapshot() throws -> ElectionSnapshot {
        let file = try JSONDecoder().decode(TSEResultFile.self, from: data("br-c0001-e021270-u.json"))
        return try ElectionSnapshot(from: file)
    }
}

final class ElectionSnapshotTests: XCTestCase {

    // MARK: - Config

    func testConfigFindsFirstRoundPresidentialElection() throws {
        let config = try JSONDecoder().decode(TSEElectionConfig.self, from: ElectionFixtures.data("ele-c.json"))
        let election = try XCTUnwrap(config.presidentialElection(round: 1))
        XCTAssertEqual(election.cycle, "ele2026")
        XCTAssertEqual(election.electionCode, "21270")
    }

    func testConfigReturnsNilWhenRoundIsNotPublished() throws {
        let config = try JSONDecoder().decode(TSEElectionConfig.self, from: ElectionFixtures.data("ele-c.json"))
        XCTAssertNil(config.presidentialElection(round: 2))
    }

    // MARK: - Endpoint

    func testSimulationPresidentURL() {
        let url = TSEEndpoint.simulation.presidentResultURL(cycle: "ele2026", electionCode: "21270")
        XCTAssertEqual(url.absoluteString, "https://resultados-sim.tse.jus.br/simulado/simulado2026/ele2026/21270/dados/br/br-c0001-e021270-u.json")
    }

    func testOfficialPresidentURLPadsElectionCode() {
        let url = TSEEndpoint.official.presidentResultURL(cycle: "ele2026", electionCode: "6257")
        XCTAssertEqual(url.absoluteString, "https://resultados.tse.jus.br/oficial/ele2026/6257/dados/br/br-c0001-e006257-u.json")
    }

    func testElectionConfigURL() {
        XCTAssertEqual(TSEEndpoint.official.electionConfigURL.absoluteString, "https://resultados.tse.jus.br/oficial/comum/config/ele-c.json")
    }

    // MARK: - Snapshot

    func testSnapshotTotals() throws {
        let snapshot = try ElectionFixtures.finalPresidentSnapshot()
        XCTAssertEqual(snapshot.electionCode, "21270")
        XCTAssertEqual(snapshot.round, 1)
        XCTAssertEqual(snapshot.generationId, "172098798")
        XCTAssertTrue(snapshot.isFinal)
        XCTAssertEqual(snapshot.sectionsTotal, 528951)
        XCTAssertEqual(snapshot.sectionsCounted, 528951)
        XCTAssertEqual(snapshot.sectionsCountedPercent, 100)
        XCTAssertEqual(snapshot.validVotes, 100982116)
        XCTAssertEqual(snapshot.candidates.count, 13)
    }

    func testSnapshotTotalizedAtIsBrasiliaTime() throws {
        let snapshot = try ElectionFixtures.finalPresidentSnapshot()
        // 24/09/2026 16:12:34 in Brasília (UTC-3).
        XCTAssertEqual(snapshot.totalizedAt, Date(timeIntervalSince1970: 1790277154))
    }

    func testCandidatesFollowTSERanking() throws {
        let snapshot = try ElectionFixtures.finalPresidentSnapshot()
        let first = try XCTUnwrap(snapshot.leader)
        XCTAssertEqual(first.number, 57)
        XCTAssertEqual(first.name, "CANDIDATO 9999")
        XCTAssertEqual(first.party, "P 9998")
        XCTAssertEqual(first.votes, 10503573)
        XCTAssertEqual(first.percent, 8.712251427, accuracy: 0.000000001)
        XCTAssertEqual(snapshot.candidates[1].number, 89)
        XCTAssertEqual(snapshot.candidates.map(\.votes), snapshot.candidates.map(\.votes).sorted(by: >))
    }

    func testRunoffAndNotElectedStatuses() throws {
        let snapshot = try ElectionFixtures.finalPresidentSnapshot()
        XCTAssertEqual(snapshot.candidates[0].status, .runoff)
        XCTAssertEqual(snapshot.candidates[1].status, .runoff)
        XCTAssertTrue(snapshot.candidates.dropFirst(2).allSatisfy { $0.status == .notElected })
    }

    func testAnnulledCandidatesAreKeptButFlagged() throws {
        let snapshot = try ElectionFixtures.finalPresidentSnapshot()
        XCTAssertFalse(snapshot.candidates.first { $0.number == 57 }!.hasValidVotes) // Anulado sub judice
        XCTAssertFalse(snapshot.candidates.first { $0.number == 60 }!.hasValidVotes) // Anulado
        XCTAssertTrue(snapshot.candidates.first { $0.number == 89 }!.hasValidVotes)
    }

    func testKeepsSpecialCharactersInNames() throws {
        let snapshot = try ElectionFixtures.finalPresidentSnapshot()
        XCTAssertEqual(snapshot.candidates[1].name, "Candidato string 1234!@#$\"TSE\"")
    }

    func testStatusDuringCount() {
        XCTAssertEqual(ElectionSnapshot.status(elected: "n", situation: "", isFinal: false), .counting)
        XCTAssertEqual(ElectionSnapshot.status(elected: "n", situation: "Não eleito", isFinal: false), .counting)
        XCTAssertEqual(ElectionSnapshot.status(elected: "s", situation: "Eleito", isFinal: false), .elected)
        XCTAssertEqual(ElectionSnapshot.status(elected: "n", situation: "Não eleito", isFinal: true), .notElected)
    }

    func testRejectsGarbageNumbers() throws {
        var json = try XCTUnwrap(String(data: ElectionFixtures.data("br-c0001-e021270-u.json"), encoding: .utf8))
        json = json.replacingOccurrences(of: "\"ts\" : \"528951\"", with: "\"ts\" : \"\"")
        let file = try JSONDecoder().decode(TSEResultFile.self, from: Data(json.utf8))
        XCTAssertThrowsError(try ElectionSnapshot(from: file))
    }

    // MARK: - Replay

    func testReplayStartsEmpty() throws {
        let snapshot = ElectionReplay(final: try ElectionFixtures.finalPresidentSnapshot()).snapshot(at: 0)
        XCTAssertEqual(snapshot.sectionsCounted, 0)
        XCTAssertEqual(snapshot.validVotes, 0)
        XCTAssertFalse(snapshot.isFinal)
        XCTAssertTrue(snapshot.candidates.allSatisfy { $0.votes == 0 && $0.status == .counting })
    }

    func testReplayEndsOnFinalSnapshot() throws {
        let final = try ElectionFixtures.finalPresidentSnapshot()
        XCTAssertEqual(ElectionReplay(final: final).snapshot(at: 1), final)
        XCTAssertEqual(ElectionReplay(final: final).snapshot(at: 1.5), final)
    }

    func testReplayProgressesMonotonically() throws {
        let replay = ElectionReplay(final: try ElectionFixtures.finalPresidentSnapshot())
        let steps = stride(from: 0.0, through: 0.99, by: 0.01).map { replay.snapshot(at: $0) }
        for (previous, next) in zip(steps, steps.dropFirst()) {
            XCTAssertGreaterThanOrEqual(next.sectionsCounted, previous.sectionsCounted)
            XCTAssertNotEqual(next.generationId, previous.generationId)
        }
    }

    func testReplayChangesLeaderAlongTheWay() throws {
        let final = try ElectionFixtures.finalPresidentSnapshot()
        let replay = ElectionReplay(final: final)
        XCTAssertNotEqual(replay.snapshot(at: 0.1).leader?.number, final.leader?.number)
    }
}
