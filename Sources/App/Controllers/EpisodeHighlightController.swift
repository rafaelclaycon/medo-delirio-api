//
//  EpisodeHighlightController.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 27/10/26.
//

import Vapor

/// One episode the app dresses up in its Episodes list, like the one about Lula's win:
/// which episode, how (`style`, a look the app knows) and the badge's text, empty for no
/// badge.
/// The app draws nothing for a style it doesn't know, so new styles are safe to add here
/// before the app that draws them is out.
struct EpisodeHighlight: Content, Equatable {

    static let styles = ["lulaWin"]
    static let maxLabelLength = 30

    let episodeId: String
    let style: String
    let label: String

    init(episodeId: String, style: String, label: String) {
        self.episodeId = episodeId
        self.style = style
        self.label = label
    }

    /// A missing `label` reads as an empty one.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        episodeId = try container.decode(String.self, forKey: .episodeId)
        style = try container.decode(String.self, forKey: .style)
        label = try container.decodeIfPresent(String.self, forKey: .label) ?? ""
    }
}

struct EpisodeHighlightController {

    private static let settingKey = "episode-highlight"

    /// 404 while nothing is highlighted.
    func getHandlerV4(req: Request) async throws -> EpisodeHighlight {
        guard
            let value = try await ServerSettingRepository.get(key: Self.settingKey, db: req.db),
            !value.isEmpty,
            let highlight = try? JSONDecoder().decode(EpisodeHighlight.self, from: Data(value.utf8))
        else {
            throw Abort(.notFound)
        }
        return highlight
    }

    /// `{"episodeId": "...", "style": "lulaWin", "label": "Lula eleito"}`. Leave `label` out,
    /// or send it empty, for no badge. Replaces whatever was highlighted before.
    func postHandlerV4(req: Request) async throws -> EpisodeHighlight {
        try checkPassword(req)
        let highlight = try req.content.decode(EpisodeHighlight.self)
        guard !highlight.episodeId.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw Abort(.badRequest, reason: "episodeId can't be empty")
        }
        guard EpisodeHighlight.styles.contains(highlight.style) else {
            throw Abort(.badRequest, reason: "style must be one of \(EpisodeHighlight.styles.joined(separator: ", "))")
        }
        let label = highlight.label.trimmingCharacters(in: .whitespaces)
        guard label.count <= EpisodeHighlight.maxLabelLength else {
            throw Abort(.badRequest, reason: "label can't pass \(EpisodeHighlight.maxLabelLength) characters")
        }
        let stored = EpisodeHighlight(episodeId: highlight.episodeId, style: highlight.style, label: label)
        let value = String(decoding: try JSONEncoder().encode(stored), as: UTF8.self)
        try await ServerSettingRepository.set(key: Self.settingKey, value: value, db: req.db)
        req.logger.info("Episode highlight set: \(stored.episodeId) as \(stored.style), \"\(stored.label)\"")
        return stored
    }

    /// Takes the highlight off. The setting is emptied rather than deleted, which reads the same.
    func deleteHandlerV4(req: Request) async throws -> HTTPStatus {
        try checkPassword(req)
        try await ServerSettingRepository.set(key: Self.settingKey, value: "", db: req.db)
        req.logger.info("Episode highlight cleared")
        return .noContent
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
