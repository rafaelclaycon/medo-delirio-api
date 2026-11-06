@testable import App
import Testing
import VaporTesting
import Foundation

struct ShareControllerTests {

    @Test func `Apple app site association is JSON listing the share pages`() async throws {
        try await withTestApp { app in
            try await app.testing().test(.GET, ".well-known/apple-app-site-association") { res async throws in
                #expect(res.status == .ok)
                #expect(res.headers.first(name: .contentType) == "application/json")
                let json = try #require(JSONSerialization.jsonObject(with: Data(res.body.readableBytesView)) as? [String: Any])
                let applinks = try #require(json["applinks"] as? [String: Any])
                let details = try #require((applinks["details"] as? [[String: Any]])?.first)
                #expect(details["appIDs"] as? [String] == [TestEnvironment.appleAppID])
                let components = try #require(details["components"] as? [[String: String]])
                #expect(components.map { $0["/"] } == ["/reacao/*", "/episodio/*"])
            }
        }
    }
}
