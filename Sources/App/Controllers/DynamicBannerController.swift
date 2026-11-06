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

    func postSetPromoBannerDataHandlerV4(req: Request) async throws -> HTTPStatus {
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
        try await ServerSettingRepository.set(key: "promo-banner", value: newValue, db: req.db)
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

    func getPromoBannerDataHandlerV4(req: Request) async throws -> String {
        guard let value = try await ServerSettingRepository.get(key: "promo-banner", db: req.db) else {
            throw Abort(.notFound)
        }
        return value
    }
}

// MARK: - Routes

extension DynamicBannerController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let v4 = routes.grouped("api", "v4")

        v4.get("dynamic-banner-dont-show-version", use: getBannerDontShowVersionHandlerV4)
        v4.get("dynamic-banner", use: getBannerDataHandlerV4)
        v4.get("anniversary-banner", use: getAnniversaryBannerDataHandlerV4)
        v4.get("promo-banner", use: getPromoBannerDataHandlerV4)
        v4.post("set-dynamic-banner-dont-show-version", use: postSetBannerDontShowVersionHandlerV4)
        v4.post("dynamic-banner", ":password", use: postSetBannerDataHandlerV4)
        v4.post("anniversary-banner", ":password", use: postSetAnniversaryBannerDataHandlerV4)
        v4.post("promo-banner", ":password", use: postSetPromoBannerDataHandlerV4)
    }
}
