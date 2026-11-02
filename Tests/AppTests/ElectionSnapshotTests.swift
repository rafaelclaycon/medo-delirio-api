@testable import App
import Testing
import VaporTesting
import Foundation

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

struct ElectionSnapshotTests {

    // MARK: - Config

    @Test func `Config finds first round presidential election`() throws {
        let config = try JSONDecoder().decode(TSEElectionConfig.self, from: ElectionFixtures.data("ele-c.json"))
        let election = try #require(config.presidentialElection(round: 1))
        #expect(election.cycle == "ele2026")
        #expect(election.electionCode == "21270")
    }

    @Test func `Config returns nil when round is not published`() throws {
        let config = try JSONDecoder().decode(TSEElectionConfig.self, from: ElectionFixtures.data("ele-c.json"))
        #expect(config.presidentialElection(round: 2) == nil)
    }

    // MARK: - Endpoint

    @Test func `Simulation president URL`() {
        let url = TSEEndpoint.simulation.presidentResultURL(cycle: "ele2026", electionCode: "21270")
        #expect(url.absoluteString == "https://resultados-sim.tse.jus.br/simulado/simulado2026/ele2026/21270/dados/br/br-c0001-e021270-u.json")
    }

    @Test func `Official president URL pads election code`() {
        let url = TSEEndpoint.official.presidentResultURL(cycle: "ele2026", electionCode: "6257")
        #expect(url.absoluteString == "https://resultados.tse.jus.br/oficial/ele2026/6257/dados/br/br-c0001-e006257-u.json")
    }

    @Test func `Election config URL`() {
        #expect(TSEEndpoint.official.electionConfigURL.absoluteString == "https://resultados.tse.jus.br/oficial/comum/config/ele-c.json")
    }

    // MARK: - Snapshot

    @Test func `Snapshot totals`() throws {
        let snapshot = try ElectionFixtures.finalPresidentSnapshot()
        #expect(snapshot.electionCode == "21270")
        #expect(snapshot.round == 1)
        #expect(snapshot.generationId == "172098798")
        #expect(snapshot.isFinal)
        #expect(snapshot.sectionsTotal == 528951)
        #expect(snapshot.sectionsCounted == 528951)
        #expect(snapshot.sectionsCountedPercent == 100)
        #expect(snapshot.validVotes == 100982116)
        #expect(snapshot.candidates.count == 13)
    }

    @Test func `Snapshot totalized at is Brasília time`() throws {
        let snapshot = try ElectionFixtures.finalPresidentSnapshot()
        // 24/09/2026 16:12:34 in Brasília (UTC-3).
        #expect(snapshot.totalizedAt == Date(timeIntervalSince1970: 1790277154))
    }

    @Test func `Candidates follow TSE ranking`() throws {
        let snapshot = try ElectionFixtures.finalPresidentSnapshot()
        let first = try #require(snapshot.leader)
        #expect(first.number == 57)
        #expect(first.name == "CANDIDATO 9999")
        #expect(first.party == "P 9998")
        #expect(first.votes == 10503573)
        #expect(abs(first.percent - 8.712251427) <= 0.000000001)
        #expect(snapshot.candidates[1].number == 89)
        #expect(snapshot.candidates.map(\.votes) == snapshot.candidates.map(\.votes).sorted(by: >))
    }

    @Test func `Runoff and not elected statuses`() throws {
        let snapshot = try ElectionFixtures.finalPresidentSnapshot()
        #expect(snapshot.candidates[0].status == .runoff)
        #expect(snapshot.candidates[1].status == .runoff)
        #expect(snapshot.candidates.dropFirst(2).allSatisfy { $0.status == .notElected })
    }

    @Test func `Annulled candidates are kept but flagged`() throws {
        let snapshot = try ElectionFixtures.finalPresidentSnapshot()
        #expect(!(snapshot.candidates.first { $0.number == 57 }!.hasValidVotes)) // Anulado sub judice
        #expect(!(snapshot.candidates.first { $0.number == 60 }!.hasValidVotes)) // Anulado
        #expect(snapshot.candidates.first { $0.number == 89 }!.hasValidVotes)
    }

    @Test func `Keeps special characters in names`() throws {
        let snapshot = try ElectionFixtures.finalPresidentSnapshot()
        #expect(snapshot.candidates[1].name == "Candidato string 1234!@#$\"TSE\"")
    }

    @Test func `Status during count`() {
        #expect(ElectionSnapshot.status(elected: "n", situation: "", isFinal: false) == .counting)
        #expect(ElectionSnapshot.status(elected: "n", situation: "Não eleito", isFinal: false) == .counting)
        #expect(ElectionSnapshot.status(elected: "s", situation: "Eleito", isFinal: false) == .elected)
        #expect(ElectionSnapshot.status(elected: "n", situation: "Não eleito", isFinal: true) == .notElected)
    }

    @Test func `Rejects garbage numbers`() throws {
        var json = try #require(String(data: ElectionFixtures.data("br-c0001-e021270-u.json"), encoding: .utf8))
        // Empty is fine (see testEmptyCountingFieldsReadAsZero); garbage is not.
        json = json.replacingOccurrences(of: "\"ts\" : \"528951\"", with: "\"ts\" : \"abc\"")
        let file = try JSONDecoder().decode(TSEResultFile.self, from: Data(json.utf8))
        #expect(throws: (any Error).self) {
            try ElectionSnapshot(from: file)
        }
    }

    // MARK: - Replay

    // MARK: - Empty Fields

    /// The fixture with some fields blanked, like a file published before the count starts.
    private func fixtureFile(blanking fields: Set<String>) throws -> TSEResultFile {
        var json = try #require(JSONSerialization.jsonObject(with: ElectionFixtures.data("br-c0001-e021270-u.json")) as? [String: Any])
        func blank(_ object: inout [String: Any]) {
            for key in object.keys where fields.contains(key) && object[key] is String {
                object[key] = ""
            }
        }
        var sections = try #require(json["s"] as? [String: Any]); blank(&sections); json["s"] = sections
        var votes = try #require(json["v"] as? [String: Any]); blank(&votes); json["v"] = votes
        var offices = try #require(json["carg"] as? [[String: Any]])
        for o in offices.indices {
            var groupings = try #require(offices[o]["agr"] as? [[String: Any]])
            for g in groupings.indices {
                var parties = try #require(groupings[g]["par"] as? [[String: Any]])
                for p in parties.indices {
                    var candidates = try #require(parties[p]["cand"] as? [[String: Any]])
                    for c in candidates.indices { blank(&candidates[c]) }
                    parties[p]["cand"] = candidates
                }
                groupings[g]["par"] = parties
            }
            offices[o]["agr"] = groupings
        }
        json["carg"] = offices
        return try JSONDecoder().decode(TSEResultFile.self, from: JSONSerialization.data(withJSONObject: json))
    }

    // MARK: - Turnout

    /// The fixture's own percentages (pa 14,85, pvb 6,57, ptvn 6,51) check ours.
    @Test func `Reads blank and null votes and abstentions`() throws {
        let turnout = try #require(ElectionFixtures.finalPresidentSnapshot().turnout)
        #expect(turnout.electorate == 163_079_139)
        #expect(turnout.attended == 138_863_131)
        #expect(turnout.abstentions == 24_215_741)
        #expect(turnout.totalVotes == 138_863_131)
        #expect(turnout.blankVotes == 9_118_018)
        #expect(turnout.nullVotes == 9_040_537)
        #expect(abs(turnout.abstentionPercent - 14.85) <= 0.005)
        #expect(abs(turnout.blankPercent - 6.57) <= 0.005)
        #expect(abs(turnout.nullPercent - 6.51) <= 0.005)
    }

    @Test func `A file without turnout still reads`() throws {
        let snapshot = try ElectionSnapshot(from: fixtureFile(removing: ["e"]))
        #expect(snapshot.turnout == nil)
        #expect(!snapshot.candidates.isEmpty)
    }

    /// Turnout is extra: an odd value there leaves it out instead of failing the count.
    @Test func `An odd turnout value doesn't reject the file`() throws {
        var json = try #require(JSONSerialization.jsonObject(with: ElectionFixtures.data("br-c0001-e021270-u.json")) as? [String: Any])
        var electorate = try #require(json["e"] as? [String: Any])
        electorate["c"] = "n/d"
        json["e"] = electorate
        let file = try JSONDecoder().decode(TSEResultFile.self, from: JSONSerialization.data(withJSONObject: json))
        let snapshot = try ElectionSnapshot(from: file)
        #expect(snapshot.turnout == nil)
        #expect(snapshot.sectionsCountedPercent == 100)
    }

    @Test func `Details carry turnout with percentages`() throws {
        let details = ElectionLiveDetails(snapshot: try ElectionFixtures.finalPresidentSnapshot(), candidateColors: [:])
        let turnout = try #require(details.turnout)
        #expect(turnout.blankVotes == 9_118_018)
        #expect(abs(turnout.blankPercent - 6.57) <= 0.005)
        #expect(abs(turnout.abstentionPercent - 14.85) <= 0.005)
    }

    @Test func `Replay scales turnout with the count`() throws {
        let final = try ElectionFixtures.finalPresidentSnapshot()
        let half = try #require(ElectionReplay(final: final).snapshot(at: 0.5).turnout)
        #expect(half.blankVotes == 9_118_018 / 2)
        #expect(half.abstentions == 24_215_741 / 2)
        #expect(abs(half.blankPercent - (final.turnout?.blankPercent ?? 0)) <= 0.01)
    }

    @Test func `Empty counting fields read as zero`() throws {
        let file = try fixtureFile(blanking: ["vap", "pvapn", "st", "pst", "vv", "ts"])
        let snapshot = try ElectionSnapshot(from: file)
        #expect(snapshot.sectionsCountedPercent == 0)
        #expect(snapshot.sectionsCounted == 0)
        #expect(snapshot.validVotes == 0)
        #expect(try snapshot.candidates.count == ElectionFixtures.finalPresidentSnapshot().candidates.count)
        #expect(snapshot.candidates.allSatisfy { $0.votes == 0 && $0.percent == 0 })
    }

    @Test func `Empty positions keep every candidate`() throws {
        let snapshot = try ElectionSnapshot(from: fixtureFile(blanking: ["seq"]))
        let final = try ElectionFixtures.finalPresidentSnapshot()
        #expect(Set(snapshot.candidates.map(\.number)) == Set(final.candidates.map(\.number)))
        // Without positions, the order falls back to votes.
        #expect(snapshot.candidates.map(\.votes) == snapshot.candidates.map(\.votes).sorted(by: >))
    }

    /// The fixture with some keys removed, like the mid-count files of the 28/09 simulation.
    private func fixtureFile(removing fields: Set<String>) throws -> TSEResultFile {
        var json = try #require(JSONSerialization.jsonObject(with: ElectionFixtures.data("br-c0001-e021270-u.json")) as? [String: Any])
        for key in fields { json.removeValue(forKey: key) }
        var offices = try #require(json["carg"] as? [[String: Any]])
        for o in offices.indices {
            var groupings = try #require(offices[o]["agr"] as? [[String: Any]])
            for g in groupings.indices {
                var parties = try #require(groupings[g]["par"] as? [[String: Any]])
                for p in parties.indices {
                    for key in fields { parties[p].removeValue(forKey: key) }
                    var candidates = try #require(parties[p]["cand"] as? [[String: Any]])
                    for c in candidates.indices {
                        for key in fields { candidates[c].removeValue(forKey: key) }
                    }
                    parties[p]["cand"] = candidates
                }
                groupings[g]["par"] = parties
            }
            offices[o]["agr"] = groupings
        }
        json["carg"] = offices
        return try JSONDecoder().decode(TSEResultFile.self, from: JSONSerialization.data(withJSONObject: json))
    }

    /// What broke the 28/09 simulation: `dvt` missing from the candidates mid-count.
    @Test func `Missing vote destination still parses`() throws {
        let snapshot = try ElectionSnapshot(from: fixtureFile(removing: ["dvt"]))
        let final = try ElectionFixtures.finalPresidentSnapshot()
        #expect(snapshot.candidates.map(\.number) == final.candidates.map(\.number))
        #expect(snapshot.candidates.map(\.percent) == final.candidates.map(\.percent))
        #expect(snapshot.candidates.allSatisfy { $0.hasValidVotes })
    }

    @Test func `Missing optional fields fall back to defaults`() throws {
        let file = try fixtureFile(removing: ["dvt", "seq", "e", "st", "vap", "pvapn", "nmu", "sg", "dt", "ht", "and", "s", "v"])
        let snapshot = try ElectionSnapshot(from: file)
        #expect(!snapshot.isFinal)
        // No totalization time: the generation time (dg/hg) stands in.
        #expect(snapshot.totalizedAt != nil)
        #expect(snapshot.sectionsCountedPercent == 0)
        #expect(snapshot.candidates.allSatisfy { $0.status == .counting && $0.votes == 0 })
        // The full name stands in for the ballot name.
        #expect(!(snapshot.candidates.contains { $0.name.isEmpty }))
    }

    /// The 29/09 simulation's 0% file had empty dt/ht, so the time came from the clock and
    /// changed every tick. The generation time is fixed per file.
    @Test func `Empty totalization time falls back to generation time`() throws {
        let snapshot = try ElectionSnapshot(from: fixtureFile(removing: ["dt", "ht"]))
        let generated = try #require(snapshot.totalizedAt)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Sao_Paulo"))
        let parts = calendar.dateComponents([.day, .month, .year, .hour, .minute, .second], from: generated)
        // The fixture's dg/hg: 24/09/2026 16:12:52.
        #expect([parts.day, parts.month, parts.year, parts.hour, parts.minute, parts.second] == [24, 9, 2026, 16, 12, 52])

        // Same file, same content state, whenever it's built.
        let settings = ElectionSettings()
        #expect(
            ElectionLiveContentState(snapshot: snapshot, settings: settings, fallbackDate: Date(timeIntervalSince1970: 0))
                == ElectionLiveContentState(snapshot: snapshot, settings: settings, fallbackDate: Date(timeIntervalSince1970: 999))
        )
    }

    @Test func `Empty ballot number still fails`() throws {
        #expect(throws: (any Error).self) {
            try ElectionSnapshot(from: fixtureFile(blanking: ["n"]))
        }
    }

    @Test func `Replay counts fast at first`() {
        #expect(ElectionReplay.countedFraction(at: 0) == 0)
        #expect(ElectionReplay.countedFraction(at: 0.5) == 0.75)
        #expect(ElectionReplay.countedFraction(at: 1) == 1)
        #expect(ElectionReplay.countedFraction(at: 2) == 1)
        let curve = stride(from: 0.0, through: 1, by: 0.05).map(ElectionReplay.countedFraction(at:))
        #expect(curve == curve.sorted())
    }

    @Test func `Replay uses step time as totalization time`() throws {
        let final = try ElectionFixtures.finalPresidentSnapshot()
        let replay = ElectionReplay(final: final)
        let publishedAt = Date(timeIntervalSince1970: 1_800_000_000)

        let halfway = replay.snapshot(at: .init(progress: 0.5, publishedAt: publishedAt))
        #expect(halfway.totalizedAt == publishedAt)
        #expect(!halfway.isFinal)
        #expect(abs(halfway.sectionsCountedPercent - 75) <= 0.1)

        let end = replay.snapshot(at: .init(progress: 1, publishedAt: publishedAt))
        #expect(end.isFinal)
        #expect(end.totalizedAt == publishedAt)
        #expect(end.candidates == final.candidates)
    }

    /// The offline replay must count towards the same result the tests use.
    @Test func `Built in replay result matches fixture`() throws {
        let fixture = String(decoding: try ElectionFixtures.data("br-c0001-e021270-u.json"), as: UTF8.self)
        #expect(ElectionReplayFixture.json.trimmingCharacters(in: .whitespacesAndNewlines) == fixture.trimmingCharacters(in: .whitespacesAndNewlines))
        #expect(try ElectionReplayFixture.finalSnapshot() == ElectionFixtures.finalPresidentSnapshot())
    }

    @Test func `Replay starts empty`() throws {
        let snapshot = ElectionReplay(final: try ElectionFixtures.finalPresidentSnapshot()).snapshot(at: 0)
        #expect(snapshot.sectionsCounted == 0)
        #expect(snapshot.validVotes == 0)
        #expect(!snapshot.isFinal)
        #expect(snapshot.candidates.allSatisfy { $0.votes == 0 && $0.status == .counting })
    }

    @Test func `Replay ends on final snapshot`() throws {
        let final = try ElectionFixtures.finalPresidentSnapshot()
        #expect(ElectionReplay(final: final).snapshot(at: 1) == final)
        #expect(ElectionReplay(final: final).snapshot(at: 1.5) == final)
    }

    @Test func `Replay progresses monotonically`() throws {
        let replay = ElectionReplay(final: try ElectionFixtures.finalPresidentSnapshot())
        let steps = stride(from: 0.0, through: 0.99, by: 0.01).map { replay.snapshot(at: $0) }
        for (previous, next) in zip(steps, steps.dropFirst()) {
            #expect(next.sectionsCounted >= previous.sectionsCounted)
            #expect(next.generationId != previous.generationId)
        }
    }

    @Test func `Replay changes leader along the way`() throws {
        let final = try ElectionFixtures.finalPresidentSnapshot()
        let replay = ElectionReplay(final: final)
        #expect(replay.snapshot(at: 0.1).leader?.number != final.leader?.number)
    }
}
