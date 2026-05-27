//
//  DynamicBannerController.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 30/04/25.
//

import Vapor

struct DynamicBannerController {

    // MARK: - Setters

    func postSetBannerDontShowVersionHandlerV4(req: Request) async throws -> HTTPStatus {
        let newValue = try req.content.decode(String.self)
        guard newValue.isEmpty == false else {
            return HTTPStatus.badRequest
        }
        try await ServerSettingRepository.set(key: "dynamic-banner-dont-show-version", value: newValue, db: req.db)
        return .ok
    }

    func postSetBannerDataHandlerV4(req: Request) async throws -> HTTPStatus {
        guard let password = req.parameters.get("password") else {
            throw Abort(.internalServerError)
        }
        guard password == ReleaseConfigs.Passwords.dynamicBannerPassword else {
            throw Abort(.forbidden)
        }

        let newValue = try req.content.decode(String.self)
        guard newValue.isEmpty == false else {
            return HTTPStatus.badRequest
        }
        try await ServerSettingRepository.set(key: "dynamic-banner", value: newValue, db: req.db)
        return .ok
    }

    func postSetAnniversaryBannerDataHandlerV4(req: Request) async throws -> HTTPStatus {
        guard let password = req.parameters.get("password") else {
            throw Abort(.internalServerError)
        }
        guard password == ReleaseConfigs.Passwords.dynamicBannerPassword else {
            throw Abort(.forbidden)
        }

        let newValue = try req.content.decode(String.self)
        guard newValue.isEmpty == false else {
            return HTTPStatus.badRequest
        }
        try await ServerSettingRepository.set(key: "anniversary-banner", value: newValue, db: req.db)
        return .ok
    }

    // MARK: - Getters

    func getBannerDontShowVersionHandlerV4(req: Request) async throws -> String {
        guard let value = try await ServerSettingRepository.get(key: "dynamic-banner-dont-show-version", db: req.db) else {
            throw Abort(.notFound)
        }
        return value
    }

    func getBannerDataHandlerV4(req: Request) async throws -> String {
        guard let value = try await ServerSettingRepository.get(key: "dynamic-banner", db: req.db) else {
            throw Abort(.notFound)
        }
        return value
    }

    func getAnniversaryBannerDataHandlerV4(req: Request) async throws -> String {
        guard let value = try await ServerSettingRepository.get(key: "anniversary-banner", db: req.db) else {
            throw Abort(.notFound)
        }
        return value
    }
}
