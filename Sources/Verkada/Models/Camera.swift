//
//  Camera.swift
//  VerkadaKit
//

import Foundation

/**
 A camera device on a Verkada organisation. Modelled after the
 `/cameras/v1/devices` listing shape.
 */
public struct Camera: Codable, Sendable, Hashable, Identifiable {
    public let id:      String
    public let name:    String?
    public let serial:  String?
    public let model:   String?
    public let status:  String?
    public let siteId:  String?

    public init(id: String, name: String? = nil, serial: String? = nil, model: String? = nil, status: String? = nil, siteId: String? = nil) {
        self.id     = id
        self.name   = name
        self.serial = serial
        self.model  = model
        self.status = status
        self.siteId = siteId
    }

    enum CodingKeys: String, CodingKey {
        case id     = "camera_id"
        case name
        case serial
        case model
        case status
        case siteId = "site_id"
    }
}
