//
//  AskForMoneyController.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 22/05/23.
//

import Vapor

struct AskForMoneyController {

    // MARK: - Getters

    func getDisplayAskForMoneyViewHandlerV1(req: Request) -> String {
        let userDefaults = UserDefaults.standard
        guard let value = userDefaults.object(forKey: "display-ask-for-money-view") else {
            return "0"
        }
        return String(value as! String)
    }
    
    func getCurrentTestVersionHandlerV2(req: Request) throws -> String {
        guard let value = UserDefaults.standard.object(forKey: "current-test-version") else {
            throw Abort(.notFound)
        }
        return String(value as! String)
    }

    func getMoneyInfoHandlerV4(req: Request) throws -> String {
        guard let value = UserDefaults.standard.object(forKey: "money-info") else {
            throw Abort(.notFound)
        }
        return String(value as! String)
    }

    // MARK: - Setters

    func postDisplayAskForMoneyViewHandlerV1(req: Request) throws -> String {
        let newValue = try req.content.decode(String.self)
        let userDefaults = UserDefaults.standard
        if newValue.contains("1") {
            userDefaults.set("1", forKey: "display-ask-for-money-view")
        } else {
            userDefaults.set("0", forKey: "display-ask-for-money-view")
        }
        return "Novo valor setado."
    }
    
    func postSetTestVersionHandlerV2(req: Request) throws -> HTTPStatus {
        let newValue = try req.content.decode(String.self)
        guard newValue.isEmpty == false else {
            return HTTPStatus.badRequest
        }
        UserDefaults.standard.set(newValue, forKey: "current-test-version")
        return .ok
    }

    func postMoneyInfoHandlerV4(req: Request) throws -> HTTPStatus {
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
        UserDefaults.standard.set(newValue, forKey: "money-info")
        return .ok
    }
}
