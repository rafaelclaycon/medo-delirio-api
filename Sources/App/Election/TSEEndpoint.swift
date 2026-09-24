import Foundation

/// Where the TSE publishes result files.
///
/// Simulation: base `https://resultados-sim.tse.jus.br/simulado`, environment `simulado2026`.
/// Official: base `https://resultados.tse.jus.br`, environment `oficial`.
struct TSEEndpoint: Equatable {

    let baseURL: String
    let environment: String

    static let simulation = TSEEndpoint(baseURL: "https://resultados-sim.tse.jus.br/simulado", environment: "simulado2026")
    static let official = TSEEndpoint(baseURL: "https://resultados.tse.jus.br", environment: "oficial")

    var electionConfigURL: URL {
        URL(string: "\(baseURL)/\(environment)/comum/config/ele-c.json")!
    }

    /// Nationwide President result, e.g. `.../ele2026/21270/dados/br/br-c0001-e021270-u.json`.
    /// The TSE pads the election code to 6 digits and the office code to 4.
    func presidentResultURL(cycle: String, electionCode: String) -> URL {
        let paddedElection = Self.zeroPadded(electionCode, length: 6)
        let paddedOffice = Self.zeroPadded(TSEElectionConfig.presidentOfficeCode, length: 4)
        return URL(string: "\(baseURL)/\(environment)/\(cycle)/\(electionCode)/dados/br/br-c\(paddedOffice)-e\(paddedElection)-u.json")!
    }

    private static func zeroPadded(_ value: String, length: Int) -> String {
        String(repeating: "0", count: max(0, length - value.count)) + value
    }
}
