@testable import App
import VaporTesting
import Foundation

/// `ReleaseConfigs.Passwords.*` crash the process via `fatalError` if their
/// backing environment variables are missing. Xcode's Test action doesn't load
/// `.env` (it runs with a working directory unrelated to the project), so any
/// test that exercises a password-protected route must set these itself.
enum TestEnvironment {
    static let testPassword = "test-password"
    static let appleAppID = "TEAMID.com.example.medo"

    static func configurePasswords() {
        _ = passwordsConfigured
    }

    /// Set once per process: `setenv` isn't safe while other threads read the
    /// environment, and Swift Testing runs tests in parallel.
    private static let passwordsConfigured: Void = {
        for key in [
            "SEND_NOTIFICATION_PASSWORD",
            "SET_DONOR_NAMES_PASSWORD",
            "ASSET_OPERATION_PASSWORD",
            "REACTIONS_PASSWORD",
            "DYNAMIC_BANNER_PASSWORD",
            "ANALYTICS_PASSWORD",
            "ELECTION_PASSWORD"
        ] {
            setenv(key, testPassword, 1)
        }
        setenv("APPLE_APP_ID", appleAppID, 1)
    }()
}

/// Runs `test` against a freshly configured app with its own in-memory database,
/// and shuts the app down afterwards, even when the test throws.
@discardableResult
func withTestApp<T>(_ test: (Application) async throws -> T) async throws -> T {
    TestEnvironment.configurePasswords()
    return try await withApp(configure: configure, test)
}
