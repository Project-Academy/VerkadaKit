//
//  API+Cameras.swift
//  VerkadaKit
//
//  `/cameras/v1/devices` — list cameras and look up by ID.
//

import Foundation
import Tapioca

extension API {
    internal enum Cameras: Endpoints {
        typealias API = Verkada
        static var base: URL { Verkada.baseURL.appending(path: "cameras/v1") }

        case devices

        var path: URL {
            switch self {
            case .devices: Self.base.appending(path: "devices")
            }
        }
    }
}

internal enum CamerasKey: PageEnvelopeKey {
    static let itemsKey = "cameras"
}
internal typealias CamerasPage = PageEnvelope<[Camera], CamerasKey>

//--------------------------------------
// MARK: - PUBLIC API -
//--------------------------------------
extension Camera {

    /// Lists every camera on the organisation.
    public static func list(retryPolicy policy: RetryPolicy = .retryWithLimit(maxAttempts: 3)) async throws -> [Camera] {
        try await Verkada.paginated(
            from:        API.Cameras.devices.GET,
            envelope:    CamerasPage.self,
            retryPolicy: policy
        )
    }

    /**
     Looks up cameras by ID. Returns only those that matched (silently
     drops unknown IDs — Verkada returns a 200 with an empty list rather
     than 404 for missing entries).
     */
    public static func list(ids: [String], retryPolicy policy: RetryPolicy = .retryWithLimit(maxAttempts: 3)) async throws -> [Camera] {
        try await API.Cameras.devices.GET
            .params(["camera_ids": ids.joined(separator: ",")])
            .retryPolicy(policy)
            .response()
            .asType(CamerasPage.self)
            .items
    }
}
