//
//  AdminPassword.swift
//  medo-delirio-api
//

import Vapor

// Admin routes used to take their password as the last path segment
// (`set-donor-names/:password`), which puts it in every access log. Clients now send
// `Authorization: Bearer <password>` instead. While older clients still use the
// path, each admin route is served at both URLs.

extension Request {
    /// The `:password` path segment, or else the `Authorization: Bearer` token.
    /// An empty token counts as no password.
    var adminPassword: String? {
        if let fromPath = parameters.get("password") {
            return fromPath
        }
        guard let token = headers.bearerAuthorization?.token, !token.isEmpty else {
            return nil
        }
        return token
    }
}

extension RoutesBuilder {
    /// Registers an admin route twice: as written, with its `:password` segment, for
    /// older clients, and without that segment, for clients that send the password
    /// in the `Authorization` header. To drop the path variant, register only the second.
    func admin<Response: AsyncResponseEncodable>(
        _ method: HTTPMethod,
        _ path: PathComponent...,
        use closure: @Sendable @escaping (Request) async throws -> Response
    ) {
        // Only a trailing segment: the shorter path is then a prefix of the longer one, so the
        // router never sees two different parameter names in the same position.
        precondition(path.last?.description == ":password", "Admin route must end in :password")
        on(method, path, use: closure)
        on(method, Array(path.dropLast()), use: closure)
    }
}
