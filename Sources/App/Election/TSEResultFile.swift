import Foundation

/// Subset of the unified result file (EA20, `-u.json`) we need for the President race.
/// The TSE sends every value as a string, with Brazilian decimal commas.
struct TSEResultFile: Decodable {

    /// Election code.
    let ele: String
    /// Round.
    let t: String
    /// Generation id, unique per generated file.
    let idg: String
    /// Totalization date ("dd/MM/yyyy") and time ("HH:mm:ss"), Brasília time.
    let dt: String
    let ht: String
    /// Counting status: "f" once the totalization for this scope is final.
    let and: String
    let s: Sections
    let v: Votes
    let carg: [Office]

    struct Sections: Decodable {
        /// Total sections.
        let ts: String
        /// Totalized sections.
        let st: String
        /// Totalized sections percentage, e.g. "97,31".
        let pst: String
    }

    struct Votes: Decodable {
        /// Valid votes.
        let vv: String
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
        let sg: String
        let cand: [Candidate]
    }

    struct Candidate: Decodable {
        /// Ballot number.
        let n: String
        /// Ballot name.
        let nmu: String
        /// Vote destination: "Válido", "Anulado", "Anulado sub judice", ...
        let dvt: String
        /// Ranking position computed by the TSE.
        let seq: String
        /// "s" when elected (or qualified for the 2nd round).
        let e: String
        /// Situation: "Eleito", "2º turno", "Não eleito", ...
        let st: String
        /// Votes.
        let vap: String
        /// Percentage with full precision, e.g. "7,527528669".
        let pvapn: String
    }
}
