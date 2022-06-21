import Vapor
import APNS

extension Application {

    func configurePush() throws {
        let appleECP8PrivateKey =
        """
        -----BEGIN PRIVATE KEY-----
        MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQg1n9+zy2kqRsK6cI7
        Mgf+5yMp6+TOsQbcEcMeEdTDthmgCgYIKoZIzj0DAQehRANCAAT+15ys+OkrOCqF
        O9+1AmP6P8KucHku2UmayLAUtMNTX1mb2hudestdWOfry8mA1L4jnss8M4TRhuSf
        k7qiLk77
        -----END PRIVATE KEY-----
        """
        
        apns.configuration = try .init(
            authenticationMethod: .jwt(
                key: .private(pem: Data(appleECP8PrivateKey.utf8)),
                keyIdentifier: "4J549VAQDA",
                teamIdentifier: "L8X3H5XA82"
            ),
            topic: "com.rafaelschmitt.MedoDelirioBrasilia",
            environment: .sandbox // Change environment in release
        )
    }

}
