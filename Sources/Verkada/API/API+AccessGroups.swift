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
        case single
        case membership

        var path: URL {
            switch self {
            case .list:       Self.base.appending(path: "access_groups")
            case .single:     Self.base.appending(path: "access_groups/group")
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

    /**
     Fetches a single access group with its `userIds` populated.
     The list endpoint only returns `group_id` and `name`; this is
     the only path to get the member list.

     Docs: https://apidocs.verkada.com/reference/getaccessgroupviewv1
     */
    @MainActor
    public static func fetch(id: String, retryPolicy policy: RetryPolicy = .retryWithLimit(maxAttempts: 3)) async throws -> AccessGroup {
        var components = URLComponents(
            url: API.AccessGroups.single.path,
            resolvingAgainstBaseURL: false
        )
        guard components != nil else { throw PrestoError.urlConstructionFailure }
        components?.queryItems = [URLQueryItem(name: "group_id", value: id)]
        guard let url = components?.url else { throw PrestoError.urlConstructionFailure }

        return try await Request(url: url, .GET)
            .retryPolicy(policy)
            .response()
            .asType(AccessGroup.self)
    }

    //--------------------------------------
    // MARK: - MEMBERSHIP -
    //--------------------------------------
    /**
     Adds the user to this group.

     Verkada wants `group_id` in the query string and the user
     identifier (`user_id` *or* `external_id`, not both) in the
     body. We prefer `user_id` because every Verkada user has one;
     `external_id` may be missing on unlinked users.

     Docs: https://apidocs.verkada.com/reference/putaccessgroupuserviewv1
     */
    @MainActor
    @discardableResult
    public func add(_ user: AccessUser, retryPolicy policy: RetryPolicy = .retryWithLimit(maxAttempts: 3)) async throws -> Bool {
        let url = try membershipURL(identifyingUser: user, inQuery: false)
        var body: [String: any Sendable] = [:]
        if let userId = user.userId, !userId.isEmpty {
            body["user_id"] = userId
        } else if let externalId = user.externalId, !externalId.isEmpty {
            body["external_id"] = externalId
        } else {
            throw ResourceError.notFound
        }
        let resp = try await Request(url: url, .PUT)
            .params(body)
            .retryPolicy(policy)
            .response()

        guard let json = resp.json,
              let adds = json["successful_adds"] as? [Any]
        else { return false }
        return !adds.isEmpty
    }

    /**
     Removes the user from this group. All identifiers go in the
     query string for DELETE (Verkada's spec — no body).

     Docs: https://apidocs.verkada.com/reference/deleteaccessgroupuserviewv1
     */
    @MainActor
    @discardableResult
    public func remove(_ user: AccessUser, retryPolicy policy: RetryPolicy = .retryWithLimit(maxAttempts: 3)) async throws -> Bool {
        let url = try membershipURL(identifyingUser: user, inQuery: true)
        let resp = try await Request(url: url, .DELETE)
            .retryPolicy(policy)
            .response()
        return (resp.json ?? [:]).isEmpty
    }

    /// Builds `…/access_groups/group/user?group_id=<g>` and, when
    /// `inQuery == true`, appends `&user_id=<u>` *or*
    /// `&external_id=<e>` (DELETE path). When `inQuery == false`,
    /// callers put the identifier in the body instead (PUT path).
    @MainActor
    private func membershipURL(identifyingUser user: AccessUser, inQuery includeIdentifier: Bool) throws -> URL {
        var components = URLComponents(
            url: API.AccessGroups.membership.path,
            resolvingAgainstBaseURL: false
        )
        guard components != nil else { throw PrestoError.urlConstructionFailure }
        var items = [URLQueryItem(name: "group_id", value: id)]
        if includeIdentifier {
            if let userId = user.userId, !userId.isEmpty {
                items.append(URLQueryItem(name: "user_id", value: userId))
            } else if let externalId = user.externalId, !externalId.isEmpty {
                items.append(URLQueryItem(name: "external_id", value: externalId))
            } else {
                throw ResourceError.notFound
            }
        }
        components?.queryItems = items
        guard let url = components?.url else { throw PrestoError.urlConstructionFailure }
        return url
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
