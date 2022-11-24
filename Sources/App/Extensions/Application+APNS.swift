import Vapor
import APNS

extension Application {

    func configurePush() throws {
        let appleECP8PrivateKey =
        """
        -----BEGIN PRIVATE KEY-----
        
        -----END PRIVATE KEY-----
        """
        
        apns.configuration = try .init(
            authenticationMethod: .jwt(
                key: .private(pem: Data(appleECP8PrivateKey.utf8)),
                keyIdentifier: "",
                teamIdentifier: ""
            ),
            topic: "com.rafaelschmitt.MedoDelirioBrasilia",
            environment: .production
        )
    }

}
