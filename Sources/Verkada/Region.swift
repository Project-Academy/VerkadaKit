//
//  Region.swift
//  VerkadaKit
//

import Foundation

/**
 The Verkada service region whose API host should be used.

 Verkada hosts each organisation's data in exactly one region; pick the one
 that matches the organisation that owns the API key. Defaults to ``us``.

 - SeeAlso: <https://apidocs.verkada.com/reference/service-regions>
 */
public enum Region: Sendable, Hashable {
    /// `https://api.verkada.com` (US — the default).
    case us
    /// `https://api.eu.verkada.com` (European Union).
    case eu
    /// Any other host (preview environments, on-prem, etc.). The URL is used
    /// as-is — no path is appended beyond what individual endpoints add.
    case custom(URL)

    public var baseURL: URL {
        switch self {
        case .us:            URL(string: "https://api.verkada.com")!
        case .eu:            URL(string: "https://api.eu.verkada.com")!
        case .custom(let u): u
        }
    }
}
