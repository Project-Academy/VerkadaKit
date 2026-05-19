//
//  Response+Helpers.swift
//  VerkadaKit
//

import Foundation

extension Response {
    /**
     Case-insensitive lookup of a header value by name. Returns `nil` when
     there's no HTTP response or no matching header.
     */
    public func header(_ name: String) -> String? {
        guard let headers else { return nil }
        for (key, value) in headers {
            if let key = key as? String,
               key.caseInsensitiveCompare(name) == .orderedSame {
                return value as? String
            }
        }
        return nil
    }
}
