//
//  ReleaseConfigs.swift
//  medo-delirio-api
//
//  Created by Rafael Claycon Schmitt on 21/12/22.
//

import Foundation
import JWTKit
import Vapor

struct ReleaseConfigs {

    private static func required(_ key: String) -> String {
        guard let value = Environment.get(key) else {
            fatalError("Missing required environment variable: \(key)")
        }
        return value
    }

    struct Passwords {
        static let sendNotificationPassword = required("SEND_NOTIFICATION_PASSWORD")
        static let setDonorNamesPassword = required("SET_DONOR_NAMES_PASSWORD")
        static let assetOperationPassword = required("ASSET_OPERATION_PASSWORD")
        static let reactionsPassword = required("REACTIONS_PASSWORD")
        static let dynamicBannerPassword = required("DYNAMIC_BANNER_PASSWORD")
        static let analyticsPassword = required("ANALYTICS_PASSWORD")
    }

    struct Push {
        static let appleECP8PrivateKey: String = {
            let raw = required("APNS_PRIVATE_KEY")
            return raw.replacingOccurrences(of: "\\n", with: "\n")
        }()
        static let keyIdentifier: JWKIdentifier = .init(string: required("APNS_KEY_IDENTIFIER"))
        static let teamIdentifier = required("APNS_TEAM_IDENTIFIER")
        static let topic = required("APNS_TOPIC")
    }
}
