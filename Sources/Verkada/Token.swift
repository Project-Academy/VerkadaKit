//
//  Token.swift
//  VerkadaKit
//
//  Short-lived bearer token returned by `POST /token`. Verkada tokens
//  are JWT-shaped strings with a 30-minute TTL; they're stored alongside
//  their absolute expiry so the kit can decide locally whether it's safe
//  to reuse one without round-tripping the server.
//

import Foundation

/**
 A short-lived API token minted by `POST /token`. Verkada returns these
 with a 30-minute TTL. Stored opaquely; you generally won't construct
 these yourself — the kit refreshes them transparently in
 ``Verkada/preProcess(request:)``.
 */
public struct Token: Sendable, Codable {
    /// The raw token string. Goes into the `x-verkada-auth` header on
    /// subsequent requests.
    public let value: String

    /// The absolute moment at which this token stops being valid. Computed
    /// at mint time as `now + ttl`.
    public let expiresAt: Date

    /**
     Convenience constructor used by ``Verkada/refreshToken()`` after
     decoding the `/token` response. Subtracts a small safety margin from
     the server-reported TTL so we don't try to re-use a token that's
     about to expire mid-flight.

     - Parameters:
       - value: The raw token string.
       - ttl: The token lifetime in seconds, as reported by the server (default 1800).
       - safetyMargin: Seconds shaved off the TTL to avoid races against
         expiry. Default 60 — matches Verkada's worst-case skew tolerance.
     */
    public init(value: String, ttl: TimeInterval = 1800, safetyMargin: TimeInterval = 60) {
        self.value = value
        self.expiresAt = Date().addingTimeInterval(max(0, ttl - safetyMargin))
    }

    public init(value: String, expiresAt: Date) {
        self.value = value
        self.expiresAt = expiresAt
    }

    /// `true` if the token is still inside its valid window.
    public var isValid: Bool { Date() < expiresAt }
}

extension Token: CustomStringConvertible {
    public var description: String {
        let preview = value.count > 16
            ? "\(value.prefix(8))…\(value.suffix(8))"
            : value
        return "Token(\(preview), expiresAt: \(expiresAt))"
    }
}
