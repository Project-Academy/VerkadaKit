//
//  PageEnvelope.swift
//  VerkadaKit
//
//  Generic decoder for Verkada's cursor-paginated list responses. Each
//  product family wraps its list under its own JSON key (`access_members`,
//  `doors`, `cameras`, …) — not a generic `items`. To keep the call site
//  honest, each endpoint declares a tiny ``PageEnvelopeKey`` carrier and
//  aliases its response type as `PageEnvelope<Item, Key>`.
//
//  Single-resource GETs (e.g. one Door by id) skip the envelope entirely
//  and decode straight into the model.
//

import Foundation

/**
 Phantom-type key carrier — threads the JSON key under which a paginated
 endpoint nests its array of items through ``PageEnvelope``'s generic
 parameter list. Conformers are usually one-line empty enums:
 ```swift
 internal enum AccessUsersKey: PageEnvelopeKey {
     static let itemsKey = "access_members"
 }
 ```
 */
public protocol PageEnvelopeKey {
    /// The JSON key under which this endpoint nests its array (e.g.
    /// `"access_members"`, `"doors"`, `"cameras"`).
    static var itemsKey: String { get }
}

/**
 The standard envelope Verkada uses for cursor-paginated list responses:
 ```json
 { "page_size": 100, "next_page_token": "abc…", "access_members": [ … ] }
 ```

 The items array is decoded into `Resource` via the JSON key supplied by
 `Key.itemsKey`. ``Pagination`` walks `nextPageToken` until it's empty.
 */
public struct PageEnvelope<Resource: Decodable & Sendable, Key: PageEnvelopeKey>: Decodable, Sendable {

    public let pageSize:      Int?
    public let nextPageToken: String?
    public let items:         Resource

    private enum EnvelopeKey: String, CodingKey {
        case pageSize       = "page_size"
        case nextPageToken  = "next_page_token"
    }

    public init(from decoder: Decoder) throws {
        let env = try decoder.container(keyedBy: EnvelopeKey.self)
        self.pageSize      = try env.decodeIfPresent(Int.self,    forKey: .pageSize)
        self.nextPageToken = try env.decodeIfPresent(String.self, forKey: .nextPageToken)

        let res = try decoder.container(keyedBy: DynamicKey.self)
        self.items = try res.decode(Resource.self, forKey: DynamicKey(Key.itemsKey))
    }

    /// `true` if there's another page of results to fetch.
    public var hasMore: Bool {
        guard let next = nextPageToken else { return false }
        return !next.isEmpty
    }
}

//--------------------------------------
// MARK: - DYNAMIC KEY -
//--------------------------------------
/// A `CodingKey` whose `stringValue` is determined at runtime — lets us
/// look up the resource by `Key.itemsKey` regardless of generic instantiation.
private struct DynamicKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init(_ s: String) { stringValue = s }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}
