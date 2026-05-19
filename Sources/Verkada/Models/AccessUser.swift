//
//  AccessUser.swift
//  VerkadaKit
//

import Foundation

/**
 A user record in Verkada Access. Modelled after the
 `/access/v1/access_users` resource shape, which gives every user a
 Verkada-assigned `user_id` plus an optional `external_id` you can
 supply at create-time (typically your own DB's primary key).
 */
public struct AccessUser: Codable, Sendable, Hashable, Identifiable {

    //--------------------------------------
    // MARK: - IDS -
    //--------------------------------------
    /// Verkada-assigned UUID. Stable for the life of the record.
    public var userId: String?
    /// Your application's primary key for this user, supplied at create
    /// time. Often more useful than `userId` because you can supply it
    /// without an extra GET round-trip.
    public var externalId: String?
    /// Optional HR system identifier. Free-form; Verkada stores but does
    /// not interpret it.
    public var employeeId: String?

    public var id: String { userId ?? externalId ?? UUID().uuidString }

    //--------------------------------------
    // MARK: - PROFILE -
    //--------------------------------------
    public var firstName:  String?
    public var middleName: String?
    public var lastName:   String?
    public var email:      String?
    /// The user's department (Verkada uses this label to mean the access
    /// cohort, e.g. `Staff` / `Students`). Maps to ``AccessGroup`` for
    /// type-safe lookup.
    public var department: String?
    public var active:     Bool?

    public init(
        userId:     String? = nil,
        externalId: String? = nil,
        employeeId: String? = nil,
        firstName:  String? = nil,
        middleName: String? = nil,
        lastName:   String? = nil,
        email:      String? = nil,
        department: String? = nil,
        active:     Bool?   = nil
    ) {
        self.userId     = userId
        self.externalId = externalId
        self.employeeId = employeeId
        self.firstName  = firstName
        self.middleName = middleName
        self.lastName   = lastName
        self.email      = email
        self.department = department
        self.active     = active
    }

    enum CodingKeys: String, CodingKey {
        case userId     = "user_id"
        case externalId = "external_id"
        case employeeId = "employee_id"
        case firstName  = "first_name"
        case middleName = "middle_name"
        case lastName   = "last_name"
        case email
        case department
        case active
    }
}
