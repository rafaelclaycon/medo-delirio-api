import Foundation

/// `ele-c.json` (EA11): lists every "pleito" and its elections. Used to discover the
/// cycle folder and election code instead of hardcoding them, since guessing URLs that
/// 404 can get our IP blocked by the TSE CDN.
struct TSEElectionConfig: Decodable {

    let pl: [Pleito]

    struct Pleito: Decodable {
        /// Pleito code, e.g. "3220".
        let cd: String
        /// Cycle folder, e.g. "ele2026".
        let c: String
        /// Election date, "dd/MM/yyyy".
        let dt: String
        let e: [Election]
    }

    struct Election: Decodable {
        /// Election code, e.g. "6257".
        let cd: String
        /// Election code of the 2nd round, empty when there is none.
        let cdt2: String?
        let nm: String
        /// Round: "1" or "2".
        let t: String
        let abr: [Scope]?
    }

    struct Scope: Decodable {
        /// "br" or a state abbreviation.
        let cd: String
        let cp: [Office]?
    }

    struct Office: Decodable {
        let cd: String
        let ds: String
    }

    static let presidentOfficeCode = "1"

    /// The election that counts votes for President in the given round, if already published.
    func presidentialElection(round: Int) -> (cycle: String, electionCode: String)? {
        for pleito in pl {
            for election in pleito.e where election.t == String(round) {
                let hasPresident = election.abr?.contains { scope in
                    scope.cd == "br" && (scope.cp?.contains { $0.cd == Self.presidentOfficeCode } ?? false)
                } ?? false
                if hasPresident {
                    return (pleito.c, election.cd)
                }
            }
        }
        return nil
    }
}
