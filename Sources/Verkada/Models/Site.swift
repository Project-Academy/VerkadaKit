//
//  Site.swift
//  VerkadaKit
//

import Foundation

/**
 A physical site (campus, building) within a Verkada organisation.

 Appears nested inside other resources (e.g. ``Door/site``,
 ``Camera/siteId``) — there isn't currently a top-level `/sites`
 endpoint exposed on this kit.
 */
public struct Site: Codable, Sendable, Hashable {
    public let id:   String?
    public let name: String?

    enum CodingKeys: String, CodingKey {
        case id   = "site_id"
        case name
    }
}
