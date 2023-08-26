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
    let isRecurringDonorBelow30: Bool?
    let isRecurringDonor30OrOver: Bool?

    init(
        name: String,
        hasDonatedBefore: Bool = false,
        isRecurringDonorBelow30: Bool? = false,
        isRecurringDonor30OrOver: Bool? = false
    ) {
        self.name = name
        self.hasDonatedBefore = hasDonatedBefore
        self.isRecurringDonorBelow30 = isRecurringDonorBelow30
        self.isRecurringDonor30OrOver = isRecurringDonor30OrOver
    }
}
