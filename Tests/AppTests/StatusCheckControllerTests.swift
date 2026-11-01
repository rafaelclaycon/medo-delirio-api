@testable import App
import XCTVapor

final class StatusCheckControllerTests: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        TestEnvironment.configurePasswords()
        app = try await Application.make(.testing)
        try await configure(app)
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

    func testStatusCheckV1ReturnsAPlainTextMessage() async throws {
        try await app.test(.GET, "api/v1/status-check", afterResponse: { res async in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.headers.contentType, .plainText)
            XCTAssertEqual(res.body.string, "Conexão com o servidor OK.")
        })
    }

    func testStatusCheckV2ReturnsAnEmptyOK() async throws {
        try await app.test(.GET, "api/v2/status-check", afterResponse: { res async in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.readableBytes, 0)
        })
    }
}
