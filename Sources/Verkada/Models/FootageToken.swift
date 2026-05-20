//
//  FootageToken.swift
//  VerkadaKit
//
//  Short-lived JWT that authenticates HLS stream and thumbnail requests.
//  Distinct from the bearer used for the REST API: footage tokens are
//  minted via `GET /cameras/v1/footage/token` (authed with the long-lived
//  `x-api-key`) and carried on stream URLs as a `?jwt=…` query item, not
//  in a header. Both lifecycles are 30 minutes, but they expire on
//  independent clocks — we cache them separately.
//

import Foundation

/**
 A short-lived JWT used to authenticate against the HLS footage stream
 and the thumbnail endpoints. Verkada returns these with a 30-minute TTL.
 You generally won't construct these yourself — the kit refreshes them
 transparently inside ``Camera/streamURL(for:resolution:)`` and friends.
 */
public struct FootageToken: Sendable, Codable {
    public let value: String
    public let expiresAt: Date

    public init(value: String, ttl: TimeInterval = 1800, safetyMargin: TimeInterval = 60) {
        self.value = value
        self.expiresAt = Date().addingTimeInterval(max(0, ttl - safetyMargin))
    }

    public init(value: String, expiresAt: Date) {
        self.value = value
        self.expiresAt = expiresAt
    }

    public var isValid: Bool { Date() < expiresAt }
}

extension FootageToken: CustomStringConvertible {
    public var description: String {
        let preview = value.count > 16
            ? "\(value.prefix(8))…\(value.suffix(8))"
            : value
        return "FootageToken(\(preview), expiresAt: \(expiresAt))"
    }
}
