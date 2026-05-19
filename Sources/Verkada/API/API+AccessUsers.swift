//
//  API+AccessUsers.swift
//  VerkadaKit
//
//  CRUD against `/access/v1/access_users` and the related sub-resources.
//

import Foundation
import Tapioca

//--------------------------------------
// MARK: - ENDPOINTS -
//--------------------------------------
extension API {
    internal enum AccessUsers: Endpoints {
        typealias API = Verkada
        static var base: URL { Verkada.baseURL.appending(path: "access/v1") }

        case list
        case user
        case accessInfo

        var path: URL {
            switch self {
            case .list:       Self.base.appending(path: "access_users")
            case .user:       Self.base.appending(path: "access_users/user")
            case .accessInfo: Self.base.appending(path: "access_users/user")
            }
        }
    }
}

//--------------------------------------
// MARK: - PAGE ENVELOPE -
//--------------------------------------
internal enum AccessUsersKey: PageEnvelopeKey {
    static let itemsKey = "access_members"
}
internal typealias AccessUsersPage = PageEnvelope<[AccessUser], AccessUsersKey>

//--------------------------------------
// MARK: - PUBLIC API -
//--------------------------------------
extension AccessUser {

    //--------------------------------------
    // MARK: - LIST -
    //--------------------------------------
    /**
     Fetches every access user on the organisation, auto-paging until
     Verkada stops sending a `next_page_token`. For large directories
     this can be expensive; prefer ``with(externalId:)`` /
     ``with(userId:)`` when you already know which record you want.
     */
    public static func list(retryPolicy policy: RetryPolicy = .retryWithLimit(maxAttempts: 3)) async throws -> [AccessUser] {
        try await Verkada.paginated(
            from:        API.AccessUsers.list.GET,
            envelope:    AccessUsersPage.self,
            retryPolicy: policy
        )
    }

    //--------------------------------------
    // MARK: - FETCH -
    //--------------------------------------
    /**
     Fetches the access user whose `external_id` matches the supplied
     value. Throws ``ResourceError/notFound`` if no record matches.
     */
    public static func with(externalId: String, retryPolicy policy: RetryPolicy = .retryWithLimit(maxAttempts: 3)) async throws -> AccessUser {
        let user = try await API.AccessUsers.user.GET
            .params(["external_id": externalId])
            .retryPolicy(policy)
            .response()
            .asType(AccessUser.self)
        return user
    }

    public static func with(userId: String, retryPolicy policy: RetryPolicy = .retryWithLimit(maxAttempts: 3)) async throws -> AccessUser {
        try await API.AccessUsers.user.GET
            .params(["user_id": userId])
            .retryPolicy(policy)
            .response()
            .asType(AccessUser.self)
    }

    //--------------------------------------
    // MARK: - CREATE -
    //--------------------------------------
    /**
     Creates the receiver on Verkada via `POST /access/v1/access_users`.

     The result is the server's view of the new record (with `user_id`
     populated). Throws ``ResourceError/missingExternalID`` if the
     receiver has no ``externalId`` set — Verkada will assign one
     internally, but callers almost always want a stable key they
     supplied themselves.
     */
    @discardableResult
    public func create(retryPolicy policy: RetryPolicy = .retryWithLimit(maxAttempts: 3)) async throws -> AccessUser {
        guard let externalId, !externalId.isEmpty
        else { throw ResourceError.missingExternalID }

        let body = encodableSelf()
        return try await API.AccessUsers.list.POST
            .params(body)
            .retryPolicy(policy)
            .response()
            .asType(AccessUser.self)
    }

    //--------------------------------------
    // MARK: - UPDATE -
    //--------------------------------------
    /**
     Updates the user identified by ``externalId`` on Verkada.

     Verkada treats `PUT /access/v1/access_users/user?external_id=...`
     as a full-record replace; pass the receiver as it should look
     after the update.
     */
    @discardableResult
    public func update(retryPolicy policy: RetryPolicy = .retryWithLimit(maxAttempts: 3)) async throws -> AccessUser {
        guard let externalId, !externalId.isEmpty
        else { throw ResourceError.missingExternalID }

        let body = encodableSelf()
        return try await API.AccessUsers.user.PUT
            .params(["external_id": externalId])
            .params(body)
            .retryPolicy(policy)
            .response()
            .asType(AccessUser.self)
    }

    //--------------------------------------
    // MARK: - DELETE -
    //--------------------------------------
    /**
     Deletes the user identified by `externalId` on Verkada.

     - warning: This is destructive; Verkada does not retain a tombstone.
       Prefer revoking access (``revokeAllAccess()``) for soft "off-boarding".
     */
    public static func delete(externalId: String, retryPolicy policy: RetryPolicy = .retryWithLimit(maxAttempts: 3)) async throws {
        _ = try await API.AccessUsers.user.DELETE
            .params(["external_id": externalId])
            .retryPolicy(policy)
            .response()
    }

    //--------------------------------------
    // MARK: - ACCESS-INFO -
    //--------------------------------------
    /**
     Returns the raw access-info payload for this user (groups, levels,
     credentials). Surfaced as JSON because the schema is broad and
     Verkada hasn't promised stability. Use ``accessGroups()`` for the
     subset most consumers actually care about.
     */
    public func accessInfo(retryPolicy policy: RetryPolicy = .retryWithLimit(maxAttempts: 3)) async throws -> [String: Any] {
        guard let externalId, !externalId.isEmpty
        else { throw ResourceError.missingExternalID }
        let resp = try await API.AccessUsers.accessInfo.GET
            .params(["external_id": externalId])
            .retryPolicy(policy)
            .response()
        return resp.json ?? [:]
    }

    /**
     The IDs of the access groups the user currently belongs to. Returns
     an empty array if the access-info payload omits the field.
     */
    public func accessGroupIds(retryPolicy policy: RetryPolicy = .retryWithLimit(maxAttempts: 3)) async throws -> [String] {
        let info = try await accessInfo(retryPolicy: policy)
        guard let groups = info["access_groups"] as? [[String: Any]]
        else { return [] }
        return groups.compactMap { $0["group_id"] as? String }
    }
}

//--------------------------------------
// MARK: - ENCODING HELPER -
//--------------------------------------
extension AccessUser {
    /// `Codable`-encoded JSON dictionary, with `nil`s dropped — the shape
    /// Verkada accepts on POST/PUT bodies.
    fileprivate func encodableSelf() -> [String: any Sendable] {
        var dict: [String: any Sendable] = [:]
        if let externalId { dict["external_id"]  = externalId }
        if let employeeId { dict["employee_id"]  = employeeId }
        if let firstName  { dict["first_name"]   = firstName  }
        if let middleName { dict["middle_name"]  = middleName }
        if let lastName   { dict["last_name"]    = lastName   }
        if let email      { dict["email"]        = email      }
        if let department { dict["department"]   = department }
        if let active     { dict["active"]       = active     }
        return dict
    }
}
