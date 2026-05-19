//
//  AuditLogEvent.swift
//  VerkadaKit
//

import Foundation

/**
 A row from `/core/v1/audit_log` — one administrator action recorded
 against the organisation. The event payload is intentionally loose: the
 schema differs from action to action and is decoded as ``payload``
 (`[String: AnyJSON]`) rather than a typed sum.
 */
public struct AuditLogEvent: Decodable, Sendable {
    public let eventId:   String?
    public let timestamp: Date?
    public let user:      String?
    public let action:    String?
    public let target:    String?

    enum CodingKeys: String, CodingKey {
        case eventId    = "event_id"
        case timestamp
        case user       = "user_email"
        case action     = "event_name"
        case target     = "target"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.eventId = try c.decodeIfPresent(String.self, forKey: .eventId)
        self.user    = try c.decodeIfPresent(String.self, forKey: .user)
        self.action  = try c.decodeIfPresent(String.self, forKey: .action)
        self.target  = try c.decodeIfPresent(String.self, forKey: .target)

        // Verkada serialises audit timestamps as either an ISO-8601 string
        // or epoch seconds — accept both.
        if let iso = try? c.decodeIfPresent(String.self, forKey: .timestamp) {
            self.timestamp = ISO8601DateFormatter().date(from: iso)
        } else if let epoch = try? c.decodeIfPresent(TimeInterval.self, forKey: .timestamp) {
            self.timestamp = Date(timeIntervalSince1970: epoch)
        } else {
            self.timestamp = nil
        }
    }
}
