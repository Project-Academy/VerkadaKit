//
//  Door.swift
//  VerkadaKit
//

import Foundation

/**
 A door controlled by a Verkada Access Control Unit (ACU).

 Modelled after `/access/v1/doors`. A door belongs to exactly one ACU
 and (usually) to a ``Site``.
 */
public struct Door: Codable, Sendable, Hashable, Identifiable {
    public let id:      String
    public let name:    String?
    public let acuId:   String?
    public let acuName: String?
    public let site:    Site?

    public init(id: String, name: String? = nil, acuId: String? = nil, acuName: String? = nil, site: Site? = nil) {
        self.id      = id
        self.name    = name
        self.acuId   = acuId
        self.acuName = acuName
        self.site    = site
    }

    enum CodingKeys: String, CodingKey {
        case id      = "door_id"
        case name
        case acuId   = "acu_id"
        case acuName = "acu_name"
        case site
    }
}
