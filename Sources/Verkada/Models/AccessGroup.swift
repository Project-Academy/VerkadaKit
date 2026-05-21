//
//  AccessGroup.swift
//  VerkadaKit
//

import Foundation

/**
 An access cohort within Verkada Access — a named bag of users that can
 be granted the same set of door permissions. Created and managed in the
 Verkada Command UI; the API only exposes membership operations and a
 read-only list endpoint.
 */
public struct AccessGroup: Codable, Sendable, Hashable, Identifiable {
    public let id:   String
    public let name: String
    public let userCount: Int?
    /// Verkada-issued user IDs that belong to this group. Populated
    /// only when the record was fetched via
    /// ``AccessGroup/fetch(id:retryPolicy:)`` — the list endpoint
    /// returns only `group_id` + `name`, no membership.
    public let userIds: [String]?

    public init(id: String, name: String, userCount: Int? = nil, userIds: [String]? = nil) {
        self.id = id
        self.name = name
        self.userCount = userCount
        self.userIds = userIds
    }

    enum CodingKeys: String, CodingKey {
        case id        = "group_id"
        case name
        case userCount = "user_count"
        case userIds   = "user_ids"
    }
}
