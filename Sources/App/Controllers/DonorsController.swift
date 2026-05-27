//
//  DonorsController.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 22/05/23.
//

import Vapor

struct DonorsController {

    func getDonorNamesHandlerV3(req: Request) async throws -> [Donor] {
        guard let rawInputString = try await ServerSettingRepository.get(key: "donors", db: req.db) else {
            throw Abort(.notFound)
        }
        guard let data = rawInputString.data(using: .utf8) else {
            throw Abort(.internalServerError)
        }
        guard let donors = try? JSONDecoder().decode([Donor].self, from: data) else {
            throw Abort(.internalServerError)
        }
        return donors
    }

    func getDisplayRecurringDonationBannerHandlerV3(req: Request) async throws -> String {
        return try await ServerSettingRepository.get(key: "display-recurring-donation-banner", db: req.db) ?? "0"
    }

    func postSetDonorNamesHandlerV3(req: Request) async throws -> HTTPStatus {
        guard let password = req.parameters.get("password") else {
            throw Abort(.internalServerError)
        }
        guard password == ReleaseConfigs.Passwords.setDonorNamesPassword else {
            throw Abort(.forbidden)
        }
        let rawInputString = try req.content.decode(String.self)
        guard rawInputString.isEmpty == false else {
            throw Abort(.badRequest)
        }
        try await ServerSettingRepository.set(key: "donors", value: rawInputString, db: req.db)
        return .ok
    }

    func postSetDisplayRecurringDonationBannerHandlerV3(req: Request) async throws -> HTTPStatus {
        let newValue = try req.content.decode(String.self)
        guard !newValue.isEmpty, ["0", "1"].contains(newValue) else {
            return HTTPStatus.badRequest
        }
        try await ServerSettingRepository.set(key: "display-recurring-donation-banner", value: newValue, db: req.db)
        return .ok
    }
}
