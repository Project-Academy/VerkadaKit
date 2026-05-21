//
//  AuditLogEvent.swift
//  VerkadaKit
//
//  One row from `/core/v1/audit_log` — an administrator (or API key)
//  action recorded against the organisation. The `details` field carries
//  per-action structured data that Verkada hasn't promised stable;
//  exposed as `[String: Any]` for callers that want to spelunk.
//

import Foundation

public struct AuditLogEvent: Decodable, Sendable {

    //--------------------------------------
    // MARK: - WHEN / WHO -
    //--------------------------------------
    public let timestamp:          Date?
    public let processedTimestamp: Date?

    public let userId:    String?
    public let userEmail: String?
    public let userName:  String?

    /// The org that owns this event. Helpful when an integration spans
    /// multiple Verkada orgs — otherwise redundant.
    public let organizationId: String?

    /// Source IP of the actor. `nil` for API-key driven actions.
    public let ipAddress: String?

    //--------------------------------------
    // MARK: - WHAT -
    //--------------------------------------
    /// Stable machine identifier for the event (e.g. `door_unlocked`,
    /// `user_created`). Match on this for filtering.
    public let eventName: String?

    /// Human-readable description Verkada renders in Command.
    public let eventDescription: String?

    /// Devices implicated in this event, if any. Verkada returns
    /// these as nested objects (id + name + type), not bare strings.
    public let devices: [Device]?

    public struct Device: Decodable, Sendable, Hashable {
        public let deviceId:   String?
        public let name:       String?
        public let deviceType: String?
        public let productType: String?

        enum CodingKeys: String, CodingKey {
            case deviceId    = "device_id"
            case name
            case deviceType  = "device_type"
            case productType = "product_type"
        }
    }

    /// Verkada's optional support reference for this event.
    public let verkadaSupportId: String?

    //--------------------------------------
    // MARK: - DECODING -
    //--------------------------------------
    enum CodingKeys: String, CodingKey {
        case timestamp
        case processedTimestamp = "processed_timestamp"
        case userId             = "user_id"
        case userEmail          = "user_email"
        case userName           = "user_name"
        case organizationId     = "organization_id"
        case ipAddress          = "ip_address"
        case eventName          = "event_name"
        case eventDescription   = "event_description"
        case devices
        case verkadaSupportId   = "verkada_support_id"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.timestamp          = AuditLogEvent.decodeDate(c, .timestamp)
        self.processedTimestamp = AuditLogEvent.decodeDate(c, .processedTimestamp)

        self.userId           = try c.decodeIfPresent(String.self, forKey: .userId)
        self.userEmail        = try c.decodeIfPresent(String.self, forKey: .userEmail)
        self.userName         = try c.decodeIfPresent(String.self, forKey: .userName)
        self.organizationId   = try c.decodeIfPresent(String.self, forKey: .organizationId)
        self.ipAddress        = try c.decodeIfPresent(String.self, forKey: .ipAddress)
        self.eventName        = try c.decodeIfPresent(String.self, forKey: .eventName)
        self.eventDescription = try c.decodeIfPresent(String.self, forKey: .eventDescription)
        // Be lenient: if Verkada's device shape changes again, swallow
        // the decode failure on this field alone so the rest of the
        // row still surfaces. Better to lose `devices` than the row.
        self.devices          = try? c.decodeIfPresent([Device].self, forKey: .devices)
        self.verkadaSupportId = try c.decodeIfPresent(String.self, forKey: .verkadaSupportId)
    }

    /// Verkada serialises audit timestamps as either ISO-8601 strings or
    /// epoch seconds depending on which sub-endpoint you hit — accept both.
    private static func decodeDate(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Date? {
        if let iso = try? c.decodeIfPresent(String.self, forKey: key),
           let date = ISO8601DateFormatter().date(from: iso) {
            return date
        }
        if let epoch = try? c.decodeIfPresent(TimeInterval.self, forKey: key) {
            return Date(timeIntervalSince1970: epoch)
        }
        return nil
    }
}
