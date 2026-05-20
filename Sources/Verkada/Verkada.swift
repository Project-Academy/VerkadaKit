//
//  Verkada.swift
//  VerkadaKit
//
//  The Tapioca conformance + configuration entry-point for VerkadaKit.
//  Mirrors the shape of MerakiKit / SlackKit / XeroKit but improves on
//  the bugs identified in their reviews:
//
//   - `postProcess` *throws* on non-2xx instead of silently returning
//   - Errors are typed (`APIError` with `id` / `message` / `statusCode`)
//   - The token cache is single-flight (concurrent callers coalesce onto
//     one `/token` refresh) and refreshed lazily on demand
//   - 429 is honoured with a `Retry-After`-aware retry budget
//   - 401 with a stale token transparently re-mints and retries once
//   - No `print` calls; an opt-in ``logger`` closure receives messages
//   - Base URL is region-configurable
//

import Foundation
@_exported import Tapioca

/**
 The VerkadaKit entry-point.

 Configure before use:
 ```swift
 Verkada.region = .us                       // optional — defaults to .us
 Verkada.keysFetcher = {
     Credentials(apiKey: secrets.verkadaAPIKey)
 }
 Verkada.logger = { print("[Verkada]", $0) } // optional
 ```

 Then call the typed API surfaces:
 ```swift
 let doors  = try await Door.list()
 let user   = try await AccessUser.with(externalId: "abc")
 try await user.grantAccess(to: .staff)
 ```
 */
@MainActor
public struct Verkada: Tapioca {
    public typealias R = Request

    //--------------------------------------
    // MARK: - CONFIGURATION -
    //--------------------------------------
    /**
     Which Verkada region the kit talks to. Defaults to ``Region/us``;
     change to ``Region/eu`` (or supply a ``Region/custom(_:)`` URL) before
     making any requests.
     */
    public static var region: Region = .us

    /**
     The base URL the kit derives every request from. Computed from
     ``region``. Conformance requirement of `Tapioca` — most callers won't
     touch this directly.
     */
    public static var baseURL: URL { region.baseURL }

    /**
     The long-lived `x-api-key` used to mint short-lived bearer tokens.

     Set this directly for one-off scripts, or — preferably — register a
     ``keysFetcher`` so the kit can pull the key from your secrets store
     on first use.
     */
    public static var apiKey: String?

    /**
     A closure that returns the long-lived API key (and optionally
     a starting token, e.g. from a shared keychain). Called on first
     use and again if the API key is ever cleared. Concurrent callers
     coalesce onto a single invocation.
     */
    public static var keysFetcher: (@Sendable () async throws -> Credentials)?

    /**
     The Verkada organisation ID. Required for any endpoint that bakes the
     org into a URL — notably the HLS footage stream. The token-mint and
     core REST endpoints derive the org from the API key automatically, so
     this only needs to be set if you're using footage / streaming.

     Easiest path: copy from Command's Settings → API page, or carry it
     in your secrets store alongside the API key.
     */
    public static var orgId: String?

    //--------------------------------------
    // MARK: - LOGGING -
    //--------------------------------------
    /**
     Optional log sink. `nil` by default — the framework stays silent.
     Set to `{ print("[Verkada]", $0) }` (or a routed logger) to see
     token refreshes, retries, and other diagnostic chatter.
     */
    public static var logger: VerkadaLogger?

    internal static func log(_ message: @autoclosure () -> String) {
        logger?(message())
    }

    //--------------------------------------
    // MARK: - TOKEN CACHE -
    //--------------------------------------
    /**
     The currently-cached short-lived bearer token, or `nil` if we've
     never minted one (or the last one expired). Reading this is cheap;
     ``preProcess(request:)`` consults ``currentToken()`` instead, which
     handles the refresh-and-coalesce dance.
     */
    public internal(set) static var token: Token?

    /// Single in-flight refresh task so parallel requests that all hit an
    /// expired token only mint **one** new token between them.
    internal static var refreshTask: Task<Token, Error>?

    //--------------------------------------
    // MARK: - FOOTAGE TOKEN CACHE -
    //--------------------------------------
    /// The cached JWT used to authenticate HLS stream / thumbnail
    /// requests. Distinct from ``token`` because footage tokens are
    /// returned by a different endpoint and expire on an independent
    /// clock. ``Camera/streamURL(for:resolution:)`` and friends consult
    /// ``currentFootageToken()`` rather than reading this directly.
    public internal(set) static var footageToken: FootageToken?

    /// Single in-flight footage-token refresh task — same coalescing
    /// pattern as ``refreshTask``.
    internal static var footageRefreshTask: Task<FootageToken, Error>?

    //--------------------------------------
    // MARK: - PRE-PROCESS -
    //--------------------------------------
    public static func preProcess(request: Request) async throws -> Request {

        // Some requests must bootstrap from the long-lived `x-api-key`
        // rather than the rotating bearer (POST /token itself, and the
        // footage-token call). They flag themselves via `usesAPIKey` so
        // we don't try to attach a bearer that hasn't been minted yet
        // (and recurse).
        if request.usesAPIKey {
            let key = try await currentAPIKey()
            return request
                .accepts(type: request.accepts)
                .content(type: request.content)
                .setHeader(key: "x-api-key", value: key)
        }

        let bearer = try await currentToken()

        return request
            .accepts(type: request.accepts)
            .content(type: request.content)
            .setHeader(key: "x-verkada-auth", value: bearer.value)
    }

    //--------------------------------------
    // MARK: - POST-PROCESS -
    //--------------------------------------
    public static func postProcess(response: Response, from request: Request) async throws -> Response {

        guard let statusCode = response.statusCode
        else { throw PrestoError.noStatusCode }

        // Success — fall through.
        if (200..<300).contains(statusCode) {
            return response
        }

        // Parse Verkada's standard error envelope (best-effort — not
        // every endpoint guarantees this shape).
        let apiError = APIError(
            id:         response.json?["id"]      as? String,
            message:    response.json?["message"] as? String,
            statusCode: statusCode
        )

        switch statusCode {
        case 401:
            // Stale token → invalidate, retry once with a fresh one.
            if !request.didRefreshTokenOnce {
                log("401 from \(request.urlRequest.url?.path ?? "?"); refreshing token and retrying.")
                token = nil
                refreshTask = nil
                var next = request
                next.didRefreshTokenOnce = true
                return try await Self.response(for: next)
            }
            log("401 after refresh — surfacing as AuthError.unauthorizedAfterRefresh.")
            throw AuthError.unauthorizedAfterRefresh

        case 429:
            // Verkada doesn't always set Retry-After; default to 5s.
            let retryAfter = response.header("Retry-After")
                .flatMap(Int.init) ?? 5
            return try await retry(
                request,
                after: .seconds(retryAfter),
                onExhausted: HTTPError.rateLimited(retryAfter: retryAfter)
            )

        case 500...599:
            return try await retry(
                request,
                after: .seconds(3),
                onExhausted: HTTPError.otherError(statusCode: statusCode)
            )

        default:
            throw apiError
        }
    }

    /**
     Re-fires `request` after `delay`, decrementing its retry budget.
     If the budget is exhausted (`.noRetry` or `.retryWithLimit(<=0)`)
     the supplied `onExhausted` error is thrown instead.
     */
    private static func retry(
        _ request: Request,
        after delay: Duration,
        onExhausted: HTTPError
    ) async throws -> Response {
        switch request.retryPolicy {
        case .noRetry, .retryWithLimit(maxAttempts: ...0):
            log("Retry budget exhausted: \(onExhausted)")
            throw onExhausted

        case .retryWithLimit(maxAttempts: let n):
            log("Retrying in \(delay) (attempts left: \(n - 1))")
            var next = request
            next.retryPolicy = .retryWithLimit(maxAttempts: n - 1)
            try await Task.sleep(for: delay)
            return try await self.response(for: next)

        case .retry:
            log("Retrying in \(delay)")
            try await Task.sleep(for: delay)
            return try await self.response(for: request)
        }
    }
}

//--------------------------------------
// MARK: - CREDENTIALS -
//--------------------------------------
/**
 The minimum shape that ``Verkada/keysFetcher`` must produce. Holds the
 long-lived API key and, optionally, a previously-issued token so an app
 that's already got a valid bearer in its keychain can skip the initial
 `/token` round-trip.
 */
public struct Credentials: Sendable {
    public let apiKey: String
    public let preloadedToken: Token?

    public init(apiKey: String, preloadedToken: Token? = nil) {
        self.apiKey = apiKey
        self.preloadedToken = preloadedToken
    }
}
