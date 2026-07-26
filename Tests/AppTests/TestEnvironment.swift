import Foundation

/// `ReleaseConfigs.Passwords.*` crash the process via `fatalError` if their
/// backing environment variables are missing. Xcode's Test action doesn't load
/// `.env` (it runs with a working directory unrelated to the project), so any
/// test that exercises a password-protected route must set these itself.
enum TestEnvironment {
    static let testPassword = "test-password"

    static func configurePasswords() {
        for key in [
            "SEND_NOTIFICATION_PASSWORD",
            "SET_DONOR_NAMES_PASSWORD",
            "ASSET_OPERATION_PASSWORD",
            "REACTIONS_PASSWORD",
            "DYNAMIC_BANNER_PASSWORD",
            "ANALYTICS_PASSWORD"
        ] {
            setenv(key, testPassword, 1)
        }
    }
}
