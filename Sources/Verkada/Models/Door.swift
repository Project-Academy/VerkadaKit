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
    public let id:                String
    public let name:              String?
    public let acuId:             String?
    public let acuName:           String?
    public let site:              Site?
    public let timezone:          String?

    /**
     `true` if Verkada Command's "API control" toggle is on for this
     door. When it's `false`, ``adminUnlock()`` and ``unlock(for:)``
     will be rejected by the server regardless of what API key you
     present. UI surfaces should mirror this — typically by disabling
     unlock buttons.
     */
    public let apiControlEnabled: Bool?

    /**
     The cameras Verkada Command has paired with this door under the
     door's "Pairing Cameras" settings. Used by Verkada's tailgating
     detection and to render the live thumbnail next to door events
     in Command. Mirroring it here lets a client app surface
     door-unlock controls inside the corresponding camera view.
     */
    public let cameras: CameraPairing?

    public struct CameraPairing: Codable, Sendable, Hashable {
        public let insideCameraId:   String?
        public let outsideCameraId:  String?
        public let intercomCameraId: String?

        public init(insideCameraId: String? = nil, outsideCameraId: String? = nil, intercomCameraId: String? = nil) {
            self.insideCameraId   = insideCameraId
            self.outsideCameraId  = outsideCameraId
            self.intercomCameraId = intercomCameraId
        }

        enum CodingKeys: String, CodingKey {
            case insideCameraId   = "inside_camera_id"
            case outsideCameraId  = "outside_camera_id"
            case intercomCameraId = "intercom_camera_id"
        }

        /// Every non-nil paired-camera id on this door, in inside →
        /// outside → intercom order.
        public var allCameraIds: [String] {
            [insideCameraId, outsideCameraId, intercomCameraId].compactMap { $0 }
        }
    }

    public init(
        id: String,
        name: String? = nil,
        acuId: String? = nil,
        acuName: String? = nil,
        site: Site? = nil,
        timezone: String? = nil,
        apiControlEnabled: Bool? = nil,
        cameras: CameraPairing? = nil
    ) {
        self.id                = id
        self.name              = name
        self.acuId             = acuId
        self.acuName           = acuName
        self.site              = site
        self.timezone          = timezone
        self.apiControlEnabled = apiControlEnabled
        self.cameras           = cameras
    }

    enum CodingKeys: String, CodingKey {
        case id                = "door_id"
        case name
        case acuId             = "acu_id"
        case acuName           = "acu_name"
        case site
        case timezone
        case apiControlEnabled = "api_control_enabled"
        case cameras           = "camera_info"
    }
}

//--------------------------------------
// MARK: - REVERSE LOOKUP -
//--------------------------------------
extension Sequence where Element == Door {
    /**
     Returns every door that Verkada Command has paired with the given
     camera (as its interior, exterior, or intercom camera). Most apps
     use this to surface door-unlock controls inside a camera view.
     */
    public func paired(withCamera cameraId: String) -> [Door] {
        filter { door in
            guard let cams = door.cameras else { return false }
            return cams.allCameraIds.contains(cameraId)
        }
    }
}
