@testable import App
import Testing
import VaporTesting
import Foundation

/// Every admin route is served twice while clients move off passwords in the path:
/// `…/:password`, and the same path without it, with `Authorization: Bearer <password>`.
struct AdminPasswordTests {

    struct AdminRoute: CustomTestStringConvertible, Sendable {
        let method: HTTPMethod
        /// The path as registered, with its `:password` segment.
        let pattern: String

        var testDescription: String { "\(method) \(pattern)" }

        /// The URL with the path parameters filled in, and `password` in the path.
        func url(password: String) -> String {
            fill(pattern).replacingOccurrences(of: ":password", with: password)
        }

        /// The URL without the password segment, for the header. Parameters that came after
        /// the password (only `replace-device-model-name` has any) move to the query.
        var headerURL: String {
            let parts = pattern.components(separatedBy: "/:password")
            let query = parts[1].split(separator: "/").map { "\($0.dropFirst())=\(fill("/" + $0))" }
            return fill(parts[0]) + (query.isEmpty ? "" : "?" + query.joined(separator: "&"))
        }

        /// Plausible values, so a handler that reads them first still reaches the password check.
        private func fill(_ path: String) -> String {
            let values = [
                ":id": "8C4A7A77-3E5B-4D2B-9C1E-2B6F1B9A0F11",
                ":updateId": "8C4A7A77-3E5B-4D2B-9C1E-2B6F1B9A0F11",
                ":date": "2026-01-01",
                ":days": "7",
                ":majorVersion": "18",
                ":modelName": "iPhone",
                ":type": "sound",
                ":newValue": "1",
                ":oldName": "old",
                ":newName": "new",
            ]
            return String(path.dropFirst()).split(separator: "/").map { segment in
                values[String(segment)] ?? String(segment)
            }.joined(separator: "/")
        }
    }

    /// Taken from the route snapshot, so a new admin route is covered without editing this list.
    static let adminRoutes: [AdminRoute] = RoutesTests.expected.compactMap { entry in
        let route = entry.components(separatedBy: " → ")[0]
        guard route.contains("/:password") else { return nil }
        let parts = route.split(separator: " ", maxSplits: 1)
        return AdminRoute(method: HTTPMethod(rawValue: String(parts[0])), pattern: String(parts[1]))
    }

    @Test func `All 72 admin routes are covered`() {
        #expect(Self.adminRoutes.count == 72)
    }

    @Test(arguments: adminRoutes)
    func `A missing or wrong password is rejected the same way in the header and the path`(route: AdminRoute) async throws {
        try await withTestApp { app in
            var pathStatus: HTTPStatus?
            try await app.testing().test(route.method, route.url(password: "wrong")) { res async in
                pathStatus = res.status
            }
            let rejected = try #require(pathStatus)
            #expect([.unauthorized, .forbidden].contains(rejected))

            for authorization in [nil, "Bearer wrong", "Bearer ", "Basic \(Data("x:\(TestEnvironment.testPassword)".utf8).base64EncodedString())"] {
                try await app.testing().test(route.method, route.headerURL, beforeRequest: { req in
                    if let authorization { req.headers.replaceOrAdd(name: .authorization, value: authorization) }
                }) { res async in
                    #expect(res.status == rejected, "Authorization: \(authorization ?? "none")")
                }
            }
        }
    }

    @Test(arguments: adminRoutes)
    func `The right password works in the header and in the path`(route: AdminRoute) async throws {
        try await withTestApp { app in
            try await app.testing().test(route.method, route.headerURL, beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: TestEnvironment.testPassword)
            }) { res async in
                #expect(![.unauthorized, .forbidden].contains(res.status), "header: \(res.status)")
            }
            try await app.testing().test(route.method, route.url(password: TestEnvironment.testPassword)) { res async in
                #expect(![.unauthorized, .forbidden].contains(res.status), "path: \(res.status)")
            }
        }
    }
}
