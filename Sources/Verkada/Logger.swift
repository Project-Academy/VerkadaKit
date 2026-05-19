//
//  Logger.swift
//  VerkadaKit
//

import Foundation

/**
 An opt-in logging hook for VerkadaKit.

 Set ``Verkada/logger`` to a closure of your choice (`{ print($0) }` is fine
 for ad-hoc debugging; route to OSLog or a third-party logger in production)
 to receive a one-line message every time the kit refreshes a token, retries
 a request, or otherwise wants to make itself heard. Default is `nil` — the
 framework stays silent.
 */
public typealias VerkadaLogger = @Sendable (_ message: String) -> Void
