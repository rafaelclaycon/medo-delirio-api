import Foundation

/// Our own view of the President race at a point in time, decoupled from the TSE format.
/// This is what feeds the app endpoint and the Live Activity content state.
struct ElectionSnapshot: Codable, Equatable {

    let electionCode: String
    let round: Int
    /// TSE generation id (`idg`), changes with every new file.
    let generationId: String
    let totalizedAt: Date?
    let isFinal: Bool
    let sectionsTotal: Int
    let sectionsCounted: Int
    let sectionsCountedPercent: Double
    let validVotes: Int
    /// Sorted by the TSE ranking.
    let candidates: [Candidate]

    struct Candidate: Codable, Equatable {
        let number: Int
        let name: String
        let party: String
        let votes: Int
        let percent: Double
        let status: Status
        /// False for "Anulado" and "Anulado sub judice": the TSE still ranks them.
        let hasValidVotes: Bool
    }

    enum Status: String, Codable {
        case counting
        case elected
        case runoff
        case notElected
    }

    var leader: Candidate? {
        candidates.first
    }

    enum ParsingError: Error {
        case presidentOfficeNotFound
        case invalidNumber(field: String, value: String)
    }
}

extension ElectionSnapshot {

    init(from file: TSEResultFile) throws {
        guard let office = file.carg.first(where: { $0.cd == TSEElectionConfig.presidentOfficeCode }) else {
            throw ParsingError.presidentOfficeNotFound
        }

        let isFinal = file.and == "f"

        var ranked: [(rank: Int, candidate: Candidate)] = []
        for party in office.agr.flatMap(\.par) {
            for candidate in party.cand {
                ranked.append((
                    // Without a position yet, candidates go last, by votes.
                    try Self.int(candidate.seq, field: "seq", emptyAs: .max),
                    Candidate(
                        number: try Self.int(candidate.n, field: "n"),
                        name: candidate.nmu,
                        party: party.sg,
                        votes: try Self.int(candidate.vap, field: "vap", emptyAs: 0),
                        percent: try Self.double(candidate.pvapn, field: "pvapn", emptyAs: 0),
                        status: Self.status(elected: candidate.e, situation: candidate.st, isFinal: isFinal),
                        hasValidVotes: candidate.dvt == "Válido"
                    )
                ))
            }
        }

        self.init(
            electionCode: file.ele,
            round: try Self.int(file.t, field: "t"),
            generationId: file.idg,
            totalizedAt: Self.date(day: file.dt, time: file.ht),
            isFinal: isFinal,
            sectionsTotal: try Self.int(file.s.ts, field: "ts", emptyAs: 0),
            sectionsCounted: try Self.int(file.s.st, field: "st", emptyAs: 0),
            sectionsCountedPercent: try Self.double(file.s.pst, field: "pst", emptyAs: 0),
            validVotes: try Self.int(file.v.vv, field: "vv", emptyAs: 0),
            candidates: ranked
                .sorted { ($0.rank, -$0.candidate.votes) < ($1.rank, -$1.candidate.votes) }
                .map(\.candidate)
        )
    }

    /// `e == "s"` can show up before the count is final (mathematically decided race),
    /// so only call someone "not elected" once the TSE says the count is over.
    static func status(elected: String, situation: String, isFinal: Bool) -> Status {
        if elected == "s" {
            return situation.localizedCaseInsensitiveContains("turno") ? .runoff : .elected
        }
        return isFinal ? .notElected : .counting
    }

    /// Counting fields can come empty before the count starts, and `emptyAs` reads them as
    /// that value instead of failing the whole file: one blank field would leave the app
    /// without a state at 17h. Fields that say who the data belongs to (ballot number,
    /// round) have no fallback, since guessing those would show the wrong candidate.
    private static func int(_ value: String, field: String, emptyAs fallback: Int? = nil) throws -> Int {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty, let fallback {
            return fallback
        }
        guard let number = Int(trimmed) else {
            throw ParsingError.invalidNumber(field: field, value: value)
        }
        return number
    }

    private static func double(_ value: String, field: String, emptyAs fallback: Double? = nil) throws -> Double {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty, let fallback {
            return fallback
        }
        guard let number = Double(trimmed.replacingOccurrences(of: ",", with: ".")) else {
            throw ParsingError.invalidNumber(field: field, value: value)
        }
        return number
    }

    private static let brasiliaFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        // Fixed UTC-3 fallback for Linux boxes without tzdata. Brazil dropped DST in 2019.
        formatter.timeZone = TimeZone(identifier: "America/Sao_Paulo") ?? TimeZone(secondsFromGMT: -3 * 60 * 60)
        formatter.dateFormat = "dd/MM/yyyy HH:mm:ss"
        return formatter
    }()

    private static func date(day: String, time: String) -> Date? {
        brasiliaFormatter.date(from: "\(day) \(time)")
    }
}
