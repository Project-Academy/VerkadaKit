//
//  API+Doors.swift
//  VerkadaKit
//
//  `/access/v1/doors`, `/access/v1/door/admin_unlock`,
//  `/access/v1/door/user_unlock`.
//

import Foundation
import Tapioca

extension API {
    internal enum Doors: Endpoints {
        typealias API = Verkada
        static var base: URL { Verkada.baseURL.appending(path: "access/v1") }

        case list
        case adminUnlock
        case userUnlock

        var path: URL {
            switch self {
            case .list:        Self.base.appending(path: "doors")
            case .adminUnlock: Self.base.appending(path: "door/admin_unlock")
            case .userUnlock:  Self.base.appending(path: "door/user_unlock")
            }
        }
    }
}

internal enum DoorsKey: PageEnvelopeKey {
    static let itemsKey = "doors"
}
internal typealias DoorsPage = PageEnvelope<[Door], DoorsKey>

//--------------------------------------
// MARK: - PUBLIC API -
//--------------------------------------
extension Door {

    /// Lists every door on the organisation.
    public static func list(retryPolicy policy: RetryPolicy = .retryWithLimit(maxAttempts: 3)) async throws -> [Door] {
        try await Verkada.paginated(
            from:        API.Doors.list.GET,
            envelope:    DoorsPage.self,
            retryPolicy: policy
        )
    }

    /**
     Lists a specific subset of doors by ID. Skips pagination because the
     list endpoint accepts an inline filter for IDs.
     */
    public static func list(ids: [String], retryPolicy policy: RetryPolicy = .retryWithLimit(maxAttempts: 3)) async throws -> [Door] {
        try await API.Doors.list.GET
            .params(["door_ids": ids.joined(separator: ",")])
            .retryPolicy(policy)
            .response()
            .asType(DoorsPage.self)
            .items
    }

    //--------------------------------------
    // MARK: - UNLOCK -
    //--------------------------------------
    /**
     Unlocks the door using organisation-level admin privileges. No user
     context is recorded — the audit log entry shows the API key holder.

     Prefer ``unlock(for:)`` when an end-user initiated the action so the
     audit log identifies *who* unlocked.
     */
    public func adminUnlock(retryPolicy policy: RetryPolicy = .retryWithLimit(maxAttempts: 3)) async throws {
        _ = try await API.Doors.adminUnlock.POST
            .params(["door_id": id])
            .retryPolicy(policy)
            .response()
    }

    /**
     Unlocks the door on behalf of a specific user, identified by their
     `external_id`. The audit log entry records the user who unlocked.

     - Parameter user: The access user driving the unlock. Must have a
       non-empty ``AccessUser/externalId``.
     */
    public func unlock(for user: AccessUser, retryPolicy policy: RetryPolicy = .retryWithLimit(maxAttempts: 3)) async throws {
        guard let externalId = user.externalId, !externalId.isEmpty
        else { throw ResourceError.missingExternalID }

        _ = try await API.Doors.userUnlock.POST
            .params([
                "door_id":     id,
                "external_id": externalId
            ])
            .retryPolicy(policy)
            .response()
    }
}
