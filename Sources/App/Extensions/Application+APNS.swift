import Vapor
import APNS
import NIOCore

extension Application {
    
    // Commented out just for development. Comment back in upon release.
//    func configurePush() throws {
//        apns.configuration = try .init(
//            authenticationMethod: .jwt(
//                key: .private(pem: Data(ReleaseConfigs.Push.appleECP8PrivateKey.utf8)),
//                keyIdentifier: ReleaseConfigs.Push.keyIdentifier,
//                teamIdentifier: ReleaseConfigs.Push.teamIdentifier
//            ),
//            topic: "com.rafaelschmitt.MedoDelirioBrasilia",
//            environment: .production,
//            timeout: TimeAmount.seconds(5)
//        )
//    }
}
