import Vapor
import APNS

extension Application {

    func configurePush() throws {
        let appleECP8PrivateKey =
        """
        // Insert here your private push notification key generated at developer.apple.com > Account > Certificates, Identifiers & Profiles > Keys
        """
        
        apns.configuration = try .init(
            authenticationMethod: .jwt(
                key: .private(pem: Data(appleECP8PrivateKey.utf8)),
                keyIdentifier: "", // Here goes the Key ID, also provided at developer.apple.com when you generate the key
                teamIdentifier: "" // Here goes the Team ID, which can be found below your account name on developer.apple.com (or just Google it)
            ),
            topic: "com.rafaelschmitt.MedoDelirioBrasilia",
            environment: .production
        )
    }

}
