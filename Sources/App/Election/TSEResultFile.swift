import Foundation

/// Subset of the unified result file (EA20, `-u.json`) we need for the President race.
/// The TSE sends every value as a string, with Brazilian decimal commas.
///
/// Only what identifies the file and each candidate is required. Everything else is
/// optional: files published during the count leave fields out that the final file has
/// (the 28/09 simulation dropped `dvt` mid-count), and one missing key used to reject the
/// whole file. `ElectionSnapshot` fills the gaps with safe defaults.
struct TSEResultFile: Decodable {

    /// Election code.
    let ele: String
    /// Round.
    let t: String
    /// Generation id, unique per generated file.
    let idg: String
    /// Totalization date ("dd/MM/yyyy") and time ("HH:mm:ss"), Brasília time. Empty before
    /// the count starts.
    let dt: String?
    let ht: String?
    /// When the TSE generated this file, same formats. Stands in for the totalization time
    /// when that's empty.
    let dg: String?
    let hg: String?
    /// Counting status: "f" once the totalization for this scope is final.
    let and: String?
    let s: Sections?
    /// Electorate and turnout, for the sections counted so far.
    let e: Electorate?
    let v: Votes?
    let carg: [Office]

    struct Sections: Decodable {
        /// Total sections.
        let ts: String?
        /// Totalized sections.
        let st: String?
        /// Totalized sections percentage, e.g. "97,31".
        let pst: String?
    }

    struct Electorate: Decodable {
        /// Registered voters.
        let te: String?
        /// Voters who showed up (comparecimento).
        let c: String?
        /// Voters who didn't (abstenção).
        let a: String?
    }

    struct Votes: Decodable {
        /// Valid votes.
        let vv: String?
        /// Every vote cast: valid, blank and null.
        let tv: String?
        /// Blank votes.
        let vb: String?
        /// Null votes, all kinds.
        let tvn: String?
    }

    struct Office: Decodable {
        let cd: String
        let agr: [Grouping]
    }

    /// Federation, coalition or standalone party.
    struct Grouping: Decodable {
        let par: [Party]
    }

    struct Party: Decodable {
        let sg: String?
        let cand: [Candidate]
    }

    struct Candidate: Decodable {
        /// Ballot number.
        let n: String
        /// Ballot name.
        let nmu: String?
        /// Full name, used when the ballot name is missing.
        let nm: String?
        /// Vote destination: "Válido", "Anulado", "Anulado sub judice", ...
        let dvt: String?
        /// Ranking position computed by the TSE.
        let seq: String?
        /// "s" when elected (or qualified for the 2nd round).
        let e: String?
        /// Situation: "Eleito", "2º turno", "Não eleito", ...
        let st: String?
        /// Votes.
        let vap: String?
        /// Percentage with full precision, e.g. "7,527528669".
        let pvapn: String?
    }
}
