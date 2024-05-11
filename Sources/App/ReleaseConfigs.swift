//
//  ReleaseConfigs.swift
//  medo-delirio-api
//
//  Created by Rafael Claycon Schmitt on 21/12/22.
//

import Foundation
import JWTKit

struct ReleaseConfigs {
    
    struct Passwords {
        
        static let sendNotificationPassword = "total-real-password"
        static let setDonorNamesPassword = "total-real-password-2"
        static let assetOperationPassword = "total-real-password-3"
        static let floodBannerPassword = "total-real-password-4"
    }
    
    struct Push {
        
        static let appleECP8PrivateKey =
        """
        // Insert here your private push notification key generated at developer.apple.com > Account > Certificates, Identifiers & Profiles > Keys
        """
        static let keyIdentifier: JWKIdentifier = "" // Here goes the Key ID, also provided at developer.apple.com when you generate the key
        static let teamIdentifier = "" // Here goes the Team ID, which can be found below your account name on developer.apple.com (or just Google it)
    }
}
