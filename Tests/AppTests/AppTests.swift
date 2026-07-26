@testable import App
import XCTVapor

final class AppTests: XCTestCase {
    func testStatusCheckV1() async throws {
        let app = try await Application.make(.testing)
        do {
            try await configure(app)
            try await app.test(.GET, "api/v1/status-check", afterResponse: { res async in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(res.body.string, "Conexão com o servidor OK.")
            })
        } catch {
            try await app.asyncShutdown()
            throw error
        }
        try await app.asyncShutdown()
    }

    func testStatusCheckV2() async throws {
        let app = try await Application.make(.testing)
        do {
            try await configure(app)
            try await app.test(.GET, "api/v2/status-check", afterResponse: { res async in
                XCTAssertEqual(res.status, .ok)
            })
        } catch {
            try await app.asyncShutdown()
            throw error
        }
        try await app.asyncShutdown()
    }
}
