//
//  DonorsController.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 22/05/23.
//

import Vapor

struct DonorsController {
    func getDonorNamesHandlerV2(req: Request) throws -> String {
        guard let value = UserDefaults.standard.object(forKey: "donor-names") else {
            throw Abort(.notFound)
        }
        return String(value as! String)
    }
    
    func getDonorNamesHandlerV3(req: Request) throws -> [Donor] {
        guard let rawInputString = UserDefaults.standard.object(forKey: "donors") as? String else {
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

    func getDisplayRecurringDonationBannerHandlerV3(req: Request) throws -> String {
        let userDefaults = UserDefaults.standard
        guard let value = userDefaults.object(forKey: "display-recurring-donation-banner") else {
            return "0"
        }
        return String(value as! String)
    }
    
    func postSetDonorNamesHandlerV2(req: Request) throws -> HTTPStatus {
        guard let password = req.parameters.get("password") else {
            throw Abort(.internalServerError)
        }
        guard password == ReleaseConfigs.Passwords.setDonorNamesPassword else {
            return .forbidden
        }
        let newValue = try req.content.decode(String.self)
        guard newValue.isEmpty == false else {
            return HTTPStatus.badRequest
        }
        UserDefaults.standard.set(newValue, forKey: "donor-names")
        return .ok
    }
    
    func postSetDonorNamesHandlerV3(req: Request) throws -> HTTPStatus {
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
        UserDefaults.standard.set(rawInputString, forKey: "donors")
        return .ok
    }

    func postSetDisplayRecurringDonationBannerHandlerV3(req: Request) throws -> HTTPStatus {
        let newValue = try req.content.decode(String.self)
        guard !newValue.isEmpty, ["0", "1"].contains(newValue) else {
            return HTTPStatus.badRequest
        }
        UserDefaults.standard.set(newValue, forKey: "display-recurring-donation-banner")
        return .ok
    }
}
