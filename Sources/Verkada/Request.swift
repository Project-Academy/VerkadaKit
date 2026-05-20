//
//  Request.swift
//  VerkadaKit
//
//  Verkada's request type. Wraps `DefaultRequest<Verkada>` from Tapioca
//  in a thin struct so we can carry three pieces of request-scoped state
//  the default doesn't track:
//
//   1. `retryPolicy` — how aggressively `postProcess` may re-fire on
//      transient failures (429 / 5xx).
//   2. `didRefreshTokenOnce` — set by `postProcess` after a 401 forces a
//      token re-mint, so the retry is a one-shot rather than a loop.
//   3. `usesAPIKey` — set on requests that must authenticate with the
//      long-lived `x-api-key` instead of the rotating bearer (currently
//      `POST /token` and `GET /cameras/v1/footage/token`).
//
//  All Verkada-specific chainable modifiers live as constrained
//  extensions further down.
//

import Foundation
import Tapioca

public struct Request: APIRequest {
    public typealias API = Verkada

    //--------------------------------------
    // MARK: - VARIABLES -
    //--------------------------------------
    public var urlRequest: URLRequest
    public var httpMethod: HTTPMethod
    public let baseURL: URL

    //--------------------------------------
    // MARK: - STATE -
    //--------------------------------------
    public var headers: [String: String] = [:]
    public var accepts: ContentType = .JSON
    public var content: ContentType = .JSON

    public var params: [String: (any Sendable)] = [:]
    public var paramTransformer: (@Sendable ([String: Any]) throws -> Data) = { params in
        try JSONSerialization.data(withJSONObject: params, options: .prettyPrinted)
    }

    /// How retries are handled when ``Verkada/postProcess(response:from:)``
    /// sees a transient failure. Defaults to a 3-attempt budget — enough to
    /// outlast Verkada's 5-second rate-limit cooldown without spinning forever.
    public var retryPolicy: RetryPolicy = .retryWithLimit(maxAttempts: 3)

    /// Set by `postProcess` after a 401 triggers a token refresh, so the
    /// follow-up retry knows not to refresh again if it *also* 401s.
    public var didRefreshTokenOnce: Bool = false

    /// Set on requests that must authenticate with the long-lived
    /// `x-api-key` rather than the rotating bearer — the token-mint call
    /// itself and the footage-token call both have to bootstrap from the
    /// API key. Tells ``Verkada/preProcess(request:)`` to take that path.
    public var usesAPIKey: Bool = false

    //--------------------------------------
    // MARK: - INITIALISERS -
    //--------------------------------------
    public init(url: URL, _ method: HTTPMethod? = nil) {
        baseURL = url
        urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = (method ?? .GET).rawValue
        httpMethod = method ?? .GET
    }

    //--------------------------------------
    // MARK: - MODIFIERS -
    //--------------------------------------
    public func retryPolicy(_ policy: RetryPolicy) -> Self {
        var r = self
        r.retryPolicy = policy
        return r
    }

    /// Convenience: replace the default param-to-body transformer.
    public func paramTransformer(_ transform: @escaping (@Sendable ([String: Any]) throws -> Data)) -> Self {
        var r = self
        r.paramTransformer = transform
        return r
    }

    //--------------------------------------
    // MARK: - INTERNAL -
    //--------------------------------------
    /// Marks this request as one that authenticates with `x-api-key`
    /// rather than the bearer token (token mint, footage token). Internal
    /// to the kit.
    internal func markedAsAPIKeyAuthed() -> Self {
        var r = self
        r.usesAPIKey = true
        return r
    }
}
