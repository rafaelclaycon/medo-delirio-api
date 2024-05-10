//
//  FloodDonationsController.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 09/05/24.
//

import Vapor

// MARK: - Setters

struct FloodDonationsController {

    func postSetBannerStartingVersionHandlerV4(req: Request) throws -> HTTPStatus {
        let newValue = try req.content.decode(String.self)
        guard newValue.isEmpty == false else {
            return HTTPStatus.badRequest
        }
        UserDefaults.standard.set(newValue, forKey: "flood-banner-starting-version")
        return .ok
    }

    func postSetBannerDataHandlerV4(req: Request) throws -> HTTPStatus {
        let newValue = try req.content.decode(String.self)
        guard newValue.isEmpty == false else {
            return HTTPStatus.badRequest
        }
        UserDefaults.standard.set(newValue, forKey: "flood-banner")
        return .ok
    }
}

// MARK: - Getters

extension FloodDonationsController {

    func getBannerStartingVersionHandlerV4(req: Request) throws -> String {
        guard let value = UserDefaults.standard.object(forKey: "flood-banner-starting-version") else {
            throw Abort(.notFound)
        }
        return String(value as! String)
    }

    func getBannerDataHandlerV4(req: Request) throws -> String {
        guard let value = UserDefaults.standard.object(forKey: "flood-banner") else {
            throw Abort(.notFound)
        }
        return String(value as! String)
    }
}
