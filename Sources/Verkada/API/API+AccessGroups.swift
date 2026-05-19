//
//  API+AccessGroups.swift
//  VerkadaKit
//
//  `/access/v1/access_groups` — list groups, add/remove users.
//

import Foundation
import Tapioca

extension API {
    internal enum AccessGroups: Endpoints {
        typealias API = Verkada
        static var base: URL { Verkada.baseURL.appending(path: "access/v1") }

        case list
        case membership

        var path: URL {
            switch self {
            case .list:       Self.base.appending(path: "access_groups")
            case .membership: Self.base.appending(path: "access_groups/group/user")
            }
        }
    }
}

internal enum AccessGroupsKey: PageEnvelopeKey {
    static let itemsKey = "access_groups"
}
internal typealias AccessGroupsPage = PageEnvelope<[AccessGroup], AccessGroupsKey>

//--------------------------------------
// MARK: - PUBLIC API -
//--------------------------------------
extension AccessGroup {

    /// Fetches every access group on the organisation.
    public static func list(retryPolicy policy: RetryPolicy = .retryWithLimit(maxAttempts: 3)) async throws -> [AccessGroup] {
        try await Verkada.paginated(
            from:        API.AccessGroups.list.GET,
            envelope:    AccessGroupsPage.self,
            retryPolicy: policy
        )
    }

    //--------------------------------------
    // MARK: - MEMBERSHIP -
    //--------------------------------------
    /**
     Adds the user (identified by `external_id`) to this group.

     Verkada's response includes a `successful_adds` array; this method
     returns `true` iff that array contains the user. Idempotent —
     re-adding an existing member is not an error.
     */
    @discardableResult
    public func add(_ user: AccessUser, retryPolicy policy: RetryPolicy = .retryWithLimit(maxAttempts: 3)) async throws -> Bool {
        guard let externalId = user.externalId, !externalId.isEmpty
        else { throw ResourceError.missingExternalID }

        let resp = try await API.AccessGroups.membership.PUT
            .params(["group_id": id])
            .params(["external_id": externalId])
            .retryPolicy(policy)
            .response()

        guard let json = resp.json,
              let adds = json["successful_adds"] as? [Any]
        else { return false }
        return !adds.isEmpty
    }

    /**
     Removes the user (identified by `external_id`) from this group.

     A successful removal returns an empty body — `true` reflects that.
     */
    @discardableResult
    public func remove(_ user: AccessUser, retryPolicy policy: RetryPolicy = .retryWithLimit(maxAttempts: 3)) async throws -> Bool {
        guard let externalId = user.externalId, !externalId.isEmpty
        else { throw ResourceError.missingExternalID }

        let resp = try await API.AccessGroups.membership.DELETE
            .params(["group_id": id, "external_id": externalId])
            .retryPolicy(policy)
            .response()

        return (resp.json ?? [:]).isEmpty
    }
}

//--------------------------------------
// MARK: - ACCESSUSER CONVENIENCE -
//--------------------------------------
extension AccessUser {
    /**
     Removes the user from every group they currently belong to. Useful
     for off-boarding without deleting the underlying user record.

     Returns `true` iff every removal succeeded.
     */
    @discardableResult
    public func revokeAllAccess(retryPolicy policy: RetryPolicy = .retryWithLimit(maxAttempts: 3)) async throws -> Bool {
        let groupIds = try await accessGroupIds(retryPolicy: policy)
        var allOK = true
        for groupId in groupIds {
            let group = AccessGroup(id: groupId, name: "")
            let ok = try await group.remove(self, retryPolicy: policy)
            if !ok { allOK = false }
        }
        return allOK
    }
}
