//
//  AskForMoneyController.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 22/05/23.
//

import Vapor

struct AskForMoneyController {
    
    func displayAskForMoneyViewHandlerV1(req: Request) -> String {
        let userDefaults = UserDefaults.standard
        guard let value = userDefaults.object(forKey: "display-ask-for-money-view") else {
            return "0"
        }
        return String(value as! String)
    }
}
