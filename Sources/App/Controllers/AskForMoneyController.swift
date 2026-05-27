//
//  AskForMoneyController.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 22/05/23.
//

import Vapor

struct AskForMoneyController {

    // MARK: - Getters

    func getDisplayAskForMoneyViewHandlerV1(req: Request) async throws -> String {
        return try await ServerSettingRepository.get(key: "display-ask-for-money-view", db: req.db) ?? "0"
    }

    func getCurrentTestVersionHandlerV2(req: Request) async throws -> String {
        guard let value = try await ServerSettingRepository.get(key: "current-test-version", db: req.db) else {
            throw Abort(.notFound)
        }
        return value
    }

    func getMoneyInfoHandlerV4(req: Request) async throws -> String {
        guard let value = try await ServerSettingRepository.get(key: "money-info", db: req.db) else {
            throw Abort(.notFound)
        }
        return value
    }

    // MARK: - Setters

    func postDisplayAskForMoneyViewHandlerV1(req: Request) async throws -> String {
        let newValue = try req.content.decode(String.self)
        let sanitized = newValue.contains("1") ? "1" : "0"
        try await ServerSettingRepository.set(key: "display-ask-for-money-view", value: sanitized, db: req.db)
        return "Novo valor setado."
    }

    func postSetTestVersionHandlerV2(req: Request) async throws -> HTTPStatus {
        let newValue = try req.content.decode(String.self)
        guard newValue.isEmpty == false else {
            return HTTPStatus.badRequest
        }
        try await ServerSettingRepository.set(key: "current-test-version", value: newValue, db: req.db)
        return .ok
    }

    func postMoneyInfoHandlerV4(req: Request) async throws -> HTTPStatus {
        guard let password = req.parameters.get("password") else {
            throw Abort(.internalServerError)
        }
        guard password == ReleaseConfigs.Passwords.setDonorNamesPassword else {
            throw Abort(.forbidden)
        }

        let newValue = try req.content.decode(String.self)
        guard newValue.isEmpty == false else {
            return HTTPStatus.badRequest
        }
        try await ServerSettingRepository.set(key: "money-info", value: newValue, db: req.db)
        return .ok
    }
}
