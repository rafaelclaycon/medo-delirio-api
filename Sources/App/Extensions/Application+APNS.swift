import Vapor
import APNS

extension Application {

    func configurePush() throws {
        let appleECP8PrivateKey =
        """
        
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
