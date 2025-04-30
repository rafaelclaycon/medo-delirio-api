//
//  DynamicBannerController.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 30/04/25.
//

import Vapor

struct DynamicBannerController {

    // MARK: - Setters

    func postSetBannerStartingVersionHandlerV4(req: Request) throws -> HTTPStatus {
        let newValue = try req.content.decode(String.self)
        guard newValue.isEmpty == false else {
            return HTTPStatus.badRequest
        }
        UserDefaults.standard.set(newValue, forKey: "dynamic-banner-starting-version")
        return .ok
    }

    func postSetBannerDataHandlerV4(req: Request) throws -> HTTPStatus {
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
        UserDefaults.standard.set(newValue, forKey: "dynamic-banner")
        return .ok
    }

    // MARK: - Getters

    func getBannerStartingVersionHandlerV4(req: Request) throws -> String {
        guard let value = UserDefaults.standard.object(forKey: "dynamic-banner-starting-version") else {
            throw Abort(.notFound)
        }
        return String(value as! String)
    }

    func getBannerDataHandlerV4(req: Request) throws -> String {
        guard let value = UserDefaults.standard.object(forKey: "dynamic-banner") else {
            throw Abort(.notFound)
        }
        return String(value as! String)
    }
}
