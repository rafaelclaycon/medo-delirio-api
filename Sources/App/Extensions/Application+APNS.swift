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
            environment: .production,
            timeout: TimeAmount.seconds(5)
        )
    }
}
