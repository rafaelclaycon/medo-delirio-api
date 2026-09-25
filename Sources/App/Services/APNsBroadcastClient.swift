import JWTKit
import Vapor

/// Live Activity broadcast pushes and channel management, which APNSwift 4 doesn't cover.
/// Plain HTTP/2 requests (AsyncHTTPClient negotiates it through ALPN) signed with the same
/// `.p8` key as the regular pushes.
///
/// Channels belong to one APNs environment, picked by `APNS_ENVIRONMENT` like everything
/// else: TestFlight and App Store builds only hear production channels.
struct APNsBroadcastClient {

    struct APNsError: Error, CustomStringConvertible {
        let status: HTTPResponseStatus
        let reason: String?

        var description: String {
            "APNs \(status.code)\(reason.map { " \($0)" } ?? "")"
        }
    }

    let app: Application

    static var environmentName: String {
        ReleaseConfigs.Push.useSandbox ? "sandbox" : "production"
    }

    private var pushHost: String {
        ReleaseConfigs.Push.useSandbox ? "https://api.sandbox.push.apple.com" : "https://api.push.apple.com"
    }

    private var managementHost: String {
        ReleaseConfigs.Push.useSandbox
            ? "https://api-manage-broadcast.sandbox.push.apple.com:2195"
            : "https://api-manage-broadcast.push.apple.com:2196"
    }

    // MARK: - Broadcast

    func send<Payload: Encodable>(
        _ payload: Payload,
        bundleId: String,
        channelId: String,
        priority: Int,
        expiration: Int
    ) async throws {
        var headers = try await authorizedHeaders()
        headers.add(name: "apns-push-type", value: "liveactivity")
        headers.add(name: "apns-channel-id", value: channelId)
        headers.add(name: "apns-priority", value: String(priority))
        headers.add(name: "apns-expiration", value: String(expiration))

        let response = try await app.client.post(URI(string: "\(pushHost)/4/broadcasts/apps/\(bundleId)"), headers: headers) { request in
            try request.content.encode(payload, using: JSONEncoder())
            request.timeout = .seconds(10)
        }
        try check(response, expecting: .ok)
    }

    // MARK: - Channels

    /// Keeps only the most recent message for devices that were offline, which is all a
    /// live count needs.
    func createChannel(bundleId: String) async throws -> String {
        struct Body: Content {
            let messageStoragePolicy: Int
            let pushType: String

            enum CodingKeys: String, CodingKey {
                case messageStoragePolicy = "message-storage-policy"
                case pushType = "push-type"
            }
        }

        let headers = try await authorizedHeaders()
        let response = try await app.client.post(URI(string: "\(managementHost)/1/apps/\(bundleId)/channels"), headers: headers) { request in
            try request.content.encode(Body(messageStoragePolicy: 1, pushType: "LiveActivity"), using: JSONEncoder())
            request.timeout = .seconds(10)
        }
        try check(response, expecting: .created)
        guard let channelId = response.headers.first(name: "apns-channel-id") else {
            throw APNsError(status: response.status, reason: "no apns-channel-id in the response")
        }
        return channelId
    }

    func listChannels(bundleId: String) async throws -> [String] {
        struct Body: Decodable {
            let channels: [String]
        }

        let headers = try await authorizedHeaders()
        let response = try await app.client.get(URI(string: "\(managementHost)/1/apps/\(bundleId)/all-channels"), headers: headers) { request in
            request.timeout = .seconds(10)
        }
        try check(response, expecting: .ok)
        return try response.content.decode(Body.self, using: JSONDecoder()).channels
    }

    // MARK: - Helpers

    private func authorizedHeaders() async throws -> HTTPHeaders {
        var headers = HTTPHeaders()
        headers.add(name: .authorization, value: "bearer \(try await APNsProviderToken.shared.current())")
        headers.add(name: .contentType, value: "application/json")
        return headers
    }

    private func check(_ response: ClientResponse, expecting status: HTTPResponseStatus) throws {
        guard response.status != status else { return }
        struct ErrorBody: Decodable {
            let reason: String
        }
        let reason = try? response.content.decode(ErrorBody.self, using: JSONDecoder()).reason
        throw APNsError(status: response.status, reason: reason)
    }
}

/// APNs rejects provider tokens older than an hour and throttles ones refreshed more often
/// than every 20 minutes, so one token is reused for 50 minutes.
actor APNsProviderToken {

    static let shared = APNsProviderToken()

    private static let lifetime: TimeInterval = 50 * 60

    private struct Payload: JWTPayload {
        let iss: IssuerClaim
        let iat: IssuedAtClaim

        func verify(using signer: JWTSigner) throws { }
    }

    private var token: String?
    private var issuedAt: Date?

    func current(now: Date = .now) throws -> String {
        if let token, let issuedAt, now.timeIntervalSince(issuedAt) < Self.lifetime {
            return token
        }
        let signers = JWTSigners()
        let keyId = ReleaseConfigs.Push.keyIdentifier
        signers.use(.es256(key: try .private(pem: ReleaseConfigs.Push.appleECP8PrivateKey)), kid: keyId)
        let token = try signers.sign(Payload(iss: .init(value: ReleaseConfigs.Push.teamIdentifier), iat: .init(value: now)), kid: keyId)
        self.token = token
        self.issuedAt = now
        return token
    }
}
