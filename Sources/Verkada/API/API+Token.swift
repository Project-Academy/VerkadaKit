//
//  API+Token.swift
//  VerkadaKit
//
//  The `POST /token` endpoint and the in-kit machinery that uses it:
//  `currentAPIKey()`, `refreshToken()`, and `currentToken()`. These are
//  the only places that read or write ``Verkada/apiKey`` / ``Verkada/token``
//  / ``Verkada/refreshTask``; everything else goes through
//  ``Verkada/currentToken()`` and gets the coalesced answer.
//

import Foundation
import Tapioca

extension API {
    internal enum TokenAPI: Endpoints {
        typealias API = Verkada
        static var base: URL { Verkada.baseURL }

        case mint

        var path: URL {
            switch self {
            case .mint: Self.base.appending(path: "token")
            }
        }
    }
}

//--------------------------------------
// MARK: - TOKEN RESPONSE DECODER -
//--------------------------------------
private struct TokenResponse: Decodable {
    let token: String
    let expiresInSeconds: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case token
        case expiresInSeconds = "expires_in"
    }
}

//--------------------------------------
// MARK: - VERKADA: TOKEN OPERATIONS -
//--------------------------------------
extension Verkada {

    /**
     Returns the long-lived API key, fetching it from ``keysFetcher`` if
     necessary. Throws ``ConfigError/apiKeyNotSet`` if neither path yields
     a key.
     */
    internal static func currentAPIKey() async throws -> String {
        if let apiKey, !apiKey.isEmpty { return apiKey }

        guard let fetcher = keysFetcher
        else { throw ConfigError.apiKeyNotSet }

        let creds = try await fetcher()
        guard !creds.apiKey.isEmpty
        else { throw ConfigError.keysFetcherReturnedEmptyKey }

        apiKey = creds.apiKey
        if let preloaded = creds.preloadedToken,
           preloaded.expiresAt > Date() {
            let ttl = Int(preloaded.expiresAt.timeIntervalSinceNow)
            storeToken(preloaded.value, ttl: ttl)
        }
        return creds.apiKey
    }

    /**
     The cached bearer JWT for the current organisation, refreshing it
     transparently if missing or expired. Concurrent callers coalesce
     onto a single `/token` round-trip.
     */
    internal static func currentToken() async throws -> String {
        if let token { return token }   // `@Expires` returns nil when expired
        return try await refreshToken()
    }

    /**
     Mints a new bearer via `POST /token`. If another caller is already
     refreshing, attaches to that in-flight task instead of starting a
     second round-trip.
     */
    @discardableResult
    internal static func refreshToken() async throws -> String {
        if let existing = refreshTask { return try await existing.value }

        let task = Task<String, Error> {
            defer { refreshTask = nil }

            _ = try await currentAPIKey()

            let resp = try await API.TokenAPI.mint.POST
                .markedAsAPIKeyAuthed()
                .retryPolicy(.retryWithLimit(maxAttempts: 1))
                .response()
                .asType(TokenResponse.self)

            let ttl = Int(resp.expiresInSeconds ?? 1800)
            storeToken(resp.token, ttl: ttl)
            log("Token refreshed (expires in \(ttl)s)")
            return resp.token
        }
        refreshTask = task
        return try await task.value
    }
}
