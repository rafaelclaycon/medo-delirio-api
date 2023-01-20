import Vapor
import APNS

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
//            environment: .production
//        )
//    }

}
