@testable import App
import XCTVapor
import Fluent
import Foundation

final class ClientDeviceStatsTests: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        TestEnvironment.configurePasswords()
        app = try await Application.make(.testing)
        try await configure(app)
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

    func testAllClientDeviceInfoReturnsEveryRow() async throws {
        try await ClientDeviceInfo(installId: "INSTALL-1", modelName: "iPhone 17", isWatchPaired: true).create(on: app.db)
        try await ClientDeviceInfo(installId: "INSTALL-2", modelName: "iPhone Simulator").create(on: app.db)

        try await app.test(.GET, "api/v1/all-client-device-info") { res async throws in
            XCTAssertEqual(res.status, .ok)
            let list = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(res.body.readableBytesView)) as? [[String: Any]])
            XCTAssertEqual(Set(list.compactMap { $0["installId"] as? String }), ["INSTALL-1", "INSTALL-2"])
            let json = try XCTUnwrap(list.first { $0["installId"] as? String == "INSTALL-1" })
            XCTAssertEqual(json["modelName"] as? String, "iPhone 17")
            XCTAssertEqual(json["isWatchPaired"] as? Bool, true)
        }
    }

    /// Removed in Nov 2026: it always failed (double-quoted ids read as column names
    /// under `SQLITE_DQS=0`), and no client called it.
    func testInstallIdCountIsGone() async throws {
        try await app.test(.GET, "api/v1/install-id-count") { res async in
            XCTAssertEqual(res.status, .notFound)
        }
    }
}
