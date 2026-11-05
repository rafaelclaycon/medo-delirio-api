@testable import App
import Testing
import VaporTesting
import Foundation

struct RetroBannerControllerTests {

    private let path = "api/v4/retro-banner"
    private var protectedPath: String { "\(path)/\(TestEnvironment.testPassword)" }

    // MARK: - Visibility

    @Test func `With nothing set the banner is hidden`() async throws {
        try await withTestApp { app in
            try await expectShow(false, appVersion: "13.9", on: app)
        }
    }

    @Test(arguments: [
        ("13.9", true),
        ("13.10", true),
        ("14.0", true),
        ("13.9.1", true),
        ("13.8", false),
        ("13.8.9", false),
        ("12.99", false),
        ("garbage", false),
        ("", false)
    ])
    func `Shows from the minimum version on`(appVersion: String, shows: Bool) async throws {
        try await withTestApp { app in
            try await set(RetroBannerSettings(enabled: true, minimumVersion: "13.9"), on: app) { res async in
                #expect(res.status == .ok)
            }
            try await expectShow(shows, appVersion: appVersion, on: app)
        }
    }

    @Test func `Turned off hides it for every version`() async throws {
        try await withTestApp { app in
            try await set(RetroBannerSettings(enabled: false, minimumVersion: "13.9"), on: app) { res async in
                #expect(res.status == .ok)
            }
            try await expectShow(false, appVersion: "99.0", on: app)
        }
    }

    @Test func `No app version hides it`() async throws {
        try await withTestApp { app in
            try await set(RetroBannerSettings(enabled: true, minimumVersion: "13.9"), on: app) { res async in
                #expect(res.status == .ok)
            }
            try await app.testing().test(.GET, path) { res async throws in
                #expect(res.status == .ok)
                #expect(try res.content.decode(RetroBannerVisibility.self).show == false)
            }
        }
    }

    @Test func `Delete hides it again`() async throws {
        try await withTestApp { app in
            try await set(RetroBannerSettings(enabled: true, minimumVersion: "13.9"), on: app) { res async in
                #expect(res.status == .ok)
            }
            try await app.testing().test(.DELETE, protectedPath) { res async in
                #expect(res.status == .noContent)
            }
            try await expectShow(false, appVersion: "13.9", on: app)
        }
    }

    // MARK: - Settings

    @Test func `Set then read the settings back`() async throws {
        try await withTestApp { app in
            try await set(RetroBannerSettings(enabled: true, minimumVersion: " 13.9 "), on: app) { res async throws in
                #expect(res.status == .ok)
                #expect(try res.content.decode(RetroBannerSettings.self).minimumVersion == "13.9")
            }
            try await app.testing().test(.GET, "\(path)/settings/\(TestEnvironment.testPassword)") { res async throws in
                #expect(res.status == .ok)
                #expect(try res.content.decode(RetroBannerSettings.self) == RetroBannerSettings(enabled: true, minimumVersion: "13.9"))
            }
        }
    }

    @Test func `Settings are not found while nothing is set`() async throws {
        try await withTestApp { app in
            try await app.testing().test(.GET, "\(path)/settings/\(TestEnvironment.testPassword)") { res async in
                #expect(res.status == .notFound)
            }
        }
    }

    @Test(arguments: ["", "13", "13.", "v13.9", "13.9-beta", "treze"])
    func `Only plain versions are accepted`(minimumVersion: String) async throws {
        try await withTestApp { app in
            try await set(RetroBannerSettings(enabled: true, minimumVersion: minimumVersion), on: app) { res async in
                #expect(res.status == (minimumVersion == "13" ? .ok : .badRequest))
            }
        }
    }

    @Test func `Wrong password is forbidden`() async throws {
        try await withTestApp { app in
            try await app.testing().test(.POST, "\(path)/wrong", beforeRequest: { req async throws in
                try req.content.encode(RetroBannerSettings(enabled: true, minimumVersion: "13.9"))
            }) { res async in
                #expect(res.status == .forbidden)
            }
            try await app.testing().test(.GET, "\(path)/settings/wrong") { res async in
                #expect(res.status == .forbidden)
            }
            try await app.testing().test(.DELETE, "\(path)/wrong") { res async in
                #expect(res.status == .forbidden)
            }
        }
    }

    // MARK: - Helpers

    private func set(
        _ settings: RetroBannerSettings,
        on app: Application,
        afterResponse: @escaping (TestingHTTPResponse) async throws -> Void
    ) async throws {
        try await app.testing().test(.POST, protectedPath, beforeRequest: { req async throws in
            try req.content.encode(settings)
        }, afterResponse: afterResponse)
    }

    private func expectShow(_ expected: Bool, appVersion: String, on app: Application) async throws {
        try await app.testing().test(.GET, "\(path)?appVersion=\(appVersion)") { res async throws in
            #expect(res.status == .ok)
            #expect(try res.content.decode(RetroBannerVisibility.self).show == expected)
        }
    }
}
