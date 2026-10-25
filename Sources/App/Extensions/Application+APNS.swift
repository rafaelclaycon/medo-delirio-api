import Vapor
import APNS
import NIOCore

extension Application {
    
    func configurePush() throws {
        apns.configuration = try .init(
            authenticationMethod: .jwt(
                key: .private(pem: Data(ReleaseConfigs.Push.appleECP8PrivateKey.utf8)),
                keyIdentifier: ReleaseConfigs.Push.keyIdentifier,
                teamIdentifier: ReleaseConfigs.Push.teamIdentifier
            ),
            topic: ReleaseConfigs.Push.topic,
            environment: ReleaseConfigs.Push.useSandbox ? .sandbox : .production,
            timeout: TimeAmount.seconds(5)
        )
    }
}

enum PushTokenErrors {

    /// APNs answers meaning the token will never work for our topic, so its device can be
    /// deleted. DeviceTokenNotForTopic comes from tokens issued for another bundle ID.
    static func isInvalidToken(_ error: Error) -> Bool {
        let description = String(describing: error).lowercased()
        return description.contains("baddevicetoken")
            || description.contains("unregistered")
            || description.contains("devicetokennotfortopic")
    }
}
