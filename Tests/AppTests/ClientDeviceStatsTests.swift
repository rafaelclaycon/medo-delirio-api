@testable import App
import Testing
import VaporTesting
import Fluent
import Foundation

struct ClientDeviceStatsTests {

    @Test func `All client device info returns every row`() async throws {
        try await withTestApp { app in
            try await ClientDeviceInfo(installId: "INSTALL-1", modelName: "iPhone 17", isWatchPaired: true).create(on: app.db)
            try await ClientDeviceInfo(installId: "INSTALL-2", modelName: "iPhone Simulator").create(on: app.db)

            try await app.testing().test(.GET, "api/v1/all-client-device-info") { res async throws in
                #expect(res.status == .ok)
                let list = try #require(JSONSerialization.jsonObject(with: Data(res.body.readableBytesView)) as? [[String: Any]])
                #expect(Set(list.compactMap { $0["installId"] as? String }) == ["INSTALL-1", "INSTALL-2"])
                let json = try #require(list.first { $0["installId"] as? String == "INSTALL-1" })
                #expect(json["modelName"] as? String == "iPhone 17")
                #expect(json["isWatchPaired"] as? Bool == true)
            }
        }
    }

    /// Removed in Nov 2026: it always failed (double-quoted ids read as column names
    /// under `SQLITE_DQS=0`), and no client called it.
    @Test func `Install id count is gone`() async throws {
        try await withTestApp { app in
            try await app.testing().test(.GET, "api/v1/install-id-count") { res async in
                #expect(res.status == .notFound)
            }
        }
    }
}
