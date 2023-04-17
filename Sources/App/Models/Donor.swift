//
//  Donor.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 17/04/23.
//

import Foundation
import Vapor

struct Donor: Content, Codable {
    
    let name: String
    let hasDonatedBefore: Bool
    
    init(name: String, isRecurringDonor: Bool = false) {
        self.name = name
        self.hasDonatedBefore = isRecurringDonor
    }
}
