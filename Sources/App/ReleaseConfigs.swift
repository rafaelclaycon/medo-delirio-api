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
        
        static let sendNotificationPassword = "uncouple-more-shun-vinous"
        static let setDonorNamesPassword = "wishbone-onion-vicinage-foible"
        
    }
    
    struct Push {
        
        static let appleECP8PrivateKey =
        """
        -----BEGIN PRIVATE KEY-----
        MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQgmjHwIz06ppuQ8GeM
        6njL/bWXSs6oSyCofUOmEDncloagCgYIKoZIzj0DAQehRANCAAQUhZxEV02e5gZj
        jBpCCo9NkvqnagFOpRIaDs9WxIGzotTf6MemOZH4aRXtwEFQivCcUW8+AGJ83J+w
        ZJvWtQh1
        -----END PRIVATE KEY-----
        """
        static let keyIdentifier: JWKIdentifier = "C8TASTP6MD" // Here goes the Key ID, also provided at developer.apple.com when you generate the key
        static let teamIdentifier = "L8X3H5XA82" // Here goes the Team ID, which can be found below your account name on developer.apple.com (or just Google it)
        
    }

}
