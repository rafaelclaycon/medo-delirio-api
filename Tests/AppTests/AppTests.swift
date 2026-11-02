@testable import App
import Testing
import VaporTesting
import Foundation

struct AppTests {
    @Test func `Status check V1`() async throws {
        try await withTestApp { app in
            try await app.testing().test(.GET, "api/v1/status-check", afterResponse: { res async in
                #expect(res.status == .ok)
                #expect(res.body.string == "Conexão com o servidor OK.")
            })
        }
    }

    @Test func `Status check V2`() async throws {
        try await withTestApp { app in
            try await app.testing().test(.GET, "api/v2/status-check", afterResponse: { res async in
                #expect(res.status == .ok)
            })
        }
    }
}
