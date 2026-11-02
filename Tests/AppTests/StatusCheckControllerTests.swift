@testable import App
import Testing
import VaporTesting
import Foundation

struct StatusCheckControllerTests {

    @Test func `Status check V1 returns a plain text message`() async throws {
        try await withTestApp { app in
            try await app.testing().test(.GET, "api/v1/status-check", afterResponse: { res async in
                #expect(res.status == .ok)
                #expect(res.headers.contentType == .plainText)
                #expect(res.body.string == "Conexão com o servidor OK.")
            })
        }
    }

    @Test func `Status check V2 returns an empty OK`() async throws {
        try await withTestApp { app in
            try await app.testing().test(.GET, "api/v2/status-check", afterResponse: { res async in
                #expect(res.status == .ok)
                #expect(res.body.readableBytes == 0)
            })
        }
    }
}
