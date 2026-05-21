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

 Note that Verkada's two main user endpoints emit different name
 shapes for the same record:

 - **`GET /access/v1/access_users`** (list) returns the user's name
   as a single `full_name` string.
 - **`PUT /core/v1/user`** (update) accepts the parts separately as
   `first_name` / `middle_name` / `last_name`.

 The model decodes whichever fields are present and exposes
 ``displayName`` as the right thing to render regardless of which
 endpoint produced the record.
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
    // MARK: - NAME -
    //--------------------------------------
    /// What the list endpoint actually returns. Use ``displayName``
    /// rather than reading these directly — it handles the
    /// list-vs-update endpoint shape difference for you.
    public var fullName:   String?
    public var firstName:  String?
    public var middleName: String?
    public var lastName:   String?

    //--------------------------------------
    // MARK: - PROFILE -
    //--------------------------------------
    public var email:           String?
    /// The user's department (Verkada uses this label to mean the access
    /// cohort, e.g. `Staff` / `Students`).
    public var department:      String?
    public var departmentId:    String?
    public var employeeTitle:   String?
    public var companyName:     String?
    public var hasProfilePhoto: Bool?
    public var isVisitor:       Bool?
    public var active:          Bool?

    public init(
        userId:           String? = nil,
        externalId:       String? = nil,
        employeeId:       String? = nil,
        fullName:         String? = nil,
        firstName:        String? = nil,
        middleName:       String? = nil,
        lastName:         String? = nil,
        email:            String? = nil,
        department:       String? = nil,
        departmentId:     String? = nil,
        employeeTitle:    String? = nil,
        companyName:      String? = nil,
        hasProfilePhoto:  Bool?   = nil,
        isVisitor:        Bool?   = nil,
        active:           Bool?   = nil
    ) {
        self.userId          = userId
        self.externalId      = externalId
        self.employeeId      = employeeId
        self.fullName        = fullName
        self.firstName       = firstName
        self.middleName      = middleName
        self.lastName        = lastName
        self.email           = email
        self.department      = department
        self.departmentId    = departmentId
        self.employeeTitle   = employeeTitle
        self.companyName     = companyName
        self.hasProfilePhoto = hasProfilePhoto
        self.isVisitor       = isVisitor
        self.active          = active
    }

    //--------------------------------------
    // MARK: - DISPLAY -
    //--------------------------------------
    /// The best human-readable name to render for this user. Prefers
    /// `fullName` (what the list endpoint returns); falls back to
    /// combining `firstName` + `lastName` (what update bodies use).
    ///
    /// Verkada's `full_name` is built as `first + " " + middle + " "
    /// + last`, so users with an empty middle name come back as
    /// `"First  Last"` with a doubled space. We collapse runs of
    /// whitespace so the rendered name is always cleanly spaced.
    public var displayName: String? {
        let clean = { (s: String?) -> String? in
            guard let s else { return nil }
            let parts = s.split(whereSeparator: { $0.isWhitespace })
            return parts.isEmpty ? nil : parts.joined(separator: " ")
        }
        if let full = clean(fullName) { return full }
        let combined = [firstName, lastName]
            .compactMap(clean)
            .joined(separator: " ")
        return combined.isEmpty ? nil : combined
    }

    enum CodingKeys: String, CodingKey {
        case userId          = "user_id"
        case externalId      = "external_id"
        case employeeId      = "employee_id"
        case fullName        = "full_name"
        case firstName       = "first_name"
        case middleName      = "middle_name"
        case lastName        = "last_name"
        case email
        case department
        case departmentId    = "department_id"
        case employeeTitle   = "employee_title"
        case companyName     = "company_name"
        case hasProfilePhoto = "has_profile_photo"
        case isVisitor       = "is_visitor"
        case active
    }
}
