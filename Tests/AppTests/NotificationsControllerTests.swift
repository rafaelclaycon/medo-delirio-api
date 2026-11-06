@testable import App
import Testing
import VaporTesting
import Foundation

struct NotificationsControllerTests {

    // MARK: - send-push-notification

    @Test(arguments: [#"{"title": "Oi", "description": "Tchau", "password": "wrong"}"#, #"{"title": "Oi", "description": "Tchau"}"#])
    func `Sending a push needs the password in the body`(body: String) async throws {
        try await withTestApp { app in
            try await app.testing().test(.POST, "api/v1/send-push-notification", beforeRequest: { req in
                req.headers.contentType = .json
                req.body = ByteBuffer(string: body)
            }) { res async in
                #expect(res.status == .unauthorized)
            }
        }
    }

    @Test func `Sending a push to no devices is OK`() async throws {
        try await withTestApp { app in
            let body = #"{"title": "Oi", "description": "Tchau", "password": "\#(TestEnvironment.testPassword)"}"#
            try await app.testing().test(.POST, "api/v1/send-push-notification", beforeRequest: { req in
                req.headers.contentType = .json
                req.body = ByteBuffer(string: body)
            }) { res async in
                #expect(res.status == .ok)
            }
        }
    }

    // MARK: - test-weekly-highlights-push

    @Test func `Testing the weekly highlights push needs the password`() async throws {
        try await withTestApp { app in
            try await app.testing().test(.POST, "api/v4/test-weekly-highlights-push/wrong") { res async in
                #expect(res.status == .forbidden)
            }
        }
    }
}
