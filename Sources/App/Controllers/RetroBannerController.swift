//
//  RetroBannerController.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 05/11/26.
//

import Vapor

/// Whether the app shows the year's Retrospectiva banner at the top of Vírgulas, and from which
/// version on. Bump `minimumVersion` after fixing something in the Retrospectiva, and the
/// versions before the fix stop showing it.
struct RetroBannerSettings: Content, Equatable {

    let enabled: Bool
    /// "13.9". Versions below it don't get the banner.
    let minimumVersion: String
}

/// The app's question: may this version show the banner right now?
struct RetroBannerVisibility: Content, Equatable {

    let show: Bool
}

struct RetroBannerController {

    private static let settingKey = "retro-banner"

    /// `?appVersion=13.9`. Always answers, `false` while nothing is set, it's turned off, the
    /// version is below the minimum or the app didn't say which version it is.
    func getHandlerV4(req: Request) async throws -> RetroBannerVisibility {
        guard
            let appVersion = req.query[String.self, at: "appVersion"],
            let settings = try await storedSettings(req)
        else {
            return RetroBannerVisibility(show: false)
        }
        return RetroBannerVisibility(show: Self.isVisible(settings, for: appVersion))
    }

    /// What's stored, to check before changing it. 404 while nothing is set.
    func getSettingsHandlerV4(req: Request) async throws -> RetroBannerSettings {
        try checkPassword(req)
        guard let settings = try await storedSettings(req) else {
            throw Abort(.notFound)
        }
        return settings
    }

    /// `{"enabled": true, "minimumVersion": "13.9"}`. Replaces whatever was set before.
    func postHandlerV4(req: Request) async throws -> RetroBannerSettings {
        try checkPassword(req)
        let settings = try req.content.decode(RetroBannerSettings.self)
        let minimumVersion = settings.minimumVersion.trimmingCharacters(in: .whitespaces)
        guard Self.versionComponents(minimumVersion) != nil else {
            throw Abort(.badRequest, reason: "minimumVersion must look like 13.9")
        }
        let stored = RetroBannerSettings(enabled: settings.enabled, minimumVersion: minimumVersion)
        let value = String(decoding: try JSONEncoder().encode(stored), as: UTF8.self)
        try await ServerSettingRepository.set(key: Self.settingKey, value: value, db: req.db)
        req.logger.info("Retro banner set: enabled \(stored.enabled), from version \(stored.minimumVersion)")
        return stored
    }

    /// Hides the banner everywhere. The setting is emptied rather than deleted, which reads the same.
    func deleteHandlerV4(req: Request) async throws -> HTTPStatus {
        try checkPassword(req)
        try await ServerSettingRepository.set(key: Self.settingKey, value: "", db: req.db)
        req.logger.info("Retro banner cleared")
        return .noContent
    }

    // MARK: - Rules

    static func isVisible(_ settings: RetroBannerSettings, for appVersion: String) -> Bool {
        guard
            settings.enabled,
            let version = versionComponents(appVersion),
            let minimum = versionComponents(settings.minimumVersion)
        else {
            return false
        }
        // "13.9" and "13.9.0" are the same version.
        let length = max(version.count, minimum.count)
        let padded = { (parts: [Int]) in parts + Array(repeating: 0, count: length - parts.count) }
        return !padded(version).lexicographicallyPrecedes(padded(minimum))
    }

    /// "13.9" → [13, 9]. Nil for anything that isn't numbers separated by dots.
    static func versionComponents(_ version: String) -> [Int]? {
        let parts = version.split(separator: ".", omittingEmptySubsequences: false)
        guard !parts.isEmpty else { return nil }
        let numbers = parts.compactMap { part in
            part.allSatisfy(\.isASCII) && part.allSatisfy(\.isNumber) ? Int(part) : nil
        }
        return numbers.count == parts.count ? numbers : nil
    }

    // MARK: - Private

    private func storedSettings(_ req: Request) async throws -> RetroBannerSettings? {
        guard
            let value = try await ServerSettingRepository.get(key: Self.settingKey, db: req.db),
            !value.isEmpty
        else {
            return nil
        }
        return try? JSONDecoder().decode(RetroBannerSettings.self, from: Data(value.utf8))
    }

    private func checkPassword(_ req: Request) throws {
        guard let password = req.parameters.get("password") else {
            throw Abort(.internalServerError)
        }
        guard password == ReleaseConfigs.Passwords.dynamicBannerPassword else {
            throw Abort(.forbidden)
        }
    }
}
