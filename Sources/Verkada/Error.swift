//
//  Error.swift
//  VerkadaKit
//

import Foundation

/**
 The umbrella protocol that every error thrown by VerkadaKit conforms to.

 Catch this if you only care that something went wrong; switch on the concrete
 cases below when you need to react differently to (e.g.) rate-limits vs auth
 failures vs decode mismatches.
 */
public protocol VerkadaError: Error, Sendable {}

//--------------------------------------
// MARK: - CONFIG -
//--------------------------------------
public enum ConfigError: VerkadaError {
    /// Thrown when a request is fired before ``Verkada/apiKey`` is set and no
    /// ``Verkada/keysFetcher`` is registered.
    case apiKeyNotSet
    /// Thrown when ``Verkada/keysFetcher`` is required but has not been registered.
    case keysFetcherNotImplemented
    /// Thrown when the fetcher returns an empty/blank API key.
    case keysFetcherReturnedEmptyKey
    /// Thrown when a request that requires ``Verkada/orgId`` (e.g. an HLS
    /// stream URL) is fired without it being set.
    case orgIdNotSet
}

//--------------------------------------
// MARK: - AUTH -
//--------------------------------------
public enum AuthError: VerkadaError {
    /// Thrown when minting a token via `POST /token` fails with no decoded body.
    case failedToFetchToken
    /// Thrown after a token-refresh-and-retry still surfaces a 401.
    case unauthorizedAfterRefresh
}

//--------------------------------------
// MARK: - HTTP -
//--------------------------------------
public enum HTTPError: VerkadaError {
    /// 429 — the retry budget was exhausted before the rate-limit window cleared.
    case rateLimited(retryAfter: Int)
    /// Any other non-2xx response that we don't model more specifically.
    case otherError(statusCode: Int)
}

//--------------------------------------
// MARK: - API -
//--------------------------------------
/**
 A structured representation of Verkada's standard error body:
 ```json
 { "id": "0e2d", "message": "Token expired", "data": null }
 ```
 - `id` is a short opaque code Verkada uses to identify the failure mode.
   We expose it as both the raw string and, where we recognise it, a
   ``KnownCode`` for pattern-matching.
 - `message` is the human-readable description.
 - `statusCode` is the HTTP status that carried the error.
 */
public struct APIError: VerkadaError, CustomStringConvertible {
    public let id: String?
    public let message: String?
    public let statusCode: Int

    public var known: KnownCode? { KnownCode(rawValue: id ?? "") }

    public init(id: String?, message: String?, statusCode: Int) {
        self.id = id
        self.message = message
        self.statusCode = statusCode
    }

    public var description: String {
        "Verkada APIError(status: \(statusCode), id: \(id ?? "-"), message: \(message ?? "-"))"
    }

    /**
     A small enum over the error `id` values Verkada documents (or that
     existing internal code has observed in production). New codes can
     still be matched on the raw ``id`` string.
     */
    public enum KnownCode: String, Sendable {
        case tokenExpired   = "token_expired"
        case invalidApiKey  = "invalid_api_key"
        case notFound       = "not_found"
        case forbidden      = "forbidden"
    }
}

//--------------------------------------
// MARK: - DECODING -
//--------------------------------------
public enum DecodeError: VerkadaError {
    /// Thrown when a list endpoint returned 200 but the envelope didn't parse.
    case envelopeMismatch(context: String)
}

//--------------------------------------
// MARK: - RESOURCE -
//--------------------------------------
public enum ResourceError: VerkadaError {
    case notFound
    case multipleFound
    case missingExternalID
}
