//
//  API+Footage.swift
//  VerkadaKit
//
//  HLS live / recent-recorded streaming + thumbnails. Both surfaces share
//  the same short-lived JWT, minted via `GET /cameras/v1/footage/token`
//  (authed with the long-lived `x-api-key`). The JWT is then carried as a
//  `?jwt=…` query parameter on the stream and thumbnail URLs — not as a
//  header — which is why the stream URL builder is async (it needs the
//  token before it can hand back a playable URL).
//
//  Historical footage windows are capped at 3,600 seconds per manifest;
//  longer playback requires stitching successive requests at the call
//  site.
//

import Foundation
import Tapioca

//--------------------------------------
// MARK: - ENDPOINTS -
//--------------------------------------
extension API {
    internal enum Footage: Endpoints {
        typealias API = Verkada
        static var base: URL { Verkada.baseURL.appending(path: "cameras/v1/footage") }

        case token
        case thumbnail
        case thumbnailLatest
        case thumbnailLink

        var path: URL {
            switch self {
            case .token:           Self.base.appending(path: "token")
            case .thumbnail:       Self.base.appending(path: "thumbnails")
            case .thumbnailLatest: Self.base.appending(path: "thumbnails/latest")
            case .thumbnailLink:   Self.base.appending(path: "thumbnails/link")
            }
        }
    }
}

//--------------------------------------
// MARK: - DECODERS -
//--------------------------------------
private struct FootageTokenResponse: Decodable {
    let jwt: String
    let expiresInSeconds: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case jwt
        case expiresInSeconds = "expires_in"
    }
}

private struct ThumbnailLinkResponse: Decodable {
    let url: String
}

//--------------------------------------
// MARK: - VERKADA: FOOTAGE-TOKEN OPS -
//--------------------------------------
extension Verkada {

    /**
     The cached footage JWT, refreshing it transparently if missing or
     expired. Concurrent callers coalesce onto a single round-trip.
     */
    internal static func currentFootageToken() async throws -> String {
        if let footageToken { return footageToken } // @Expires returns nil on expiry
        return try await refreshFootageToken()
    }

    /**
     Mints a fresh footage JWT via `GET /cameras/v1/footage/token`. The
     endpoint authenticates with the long-lived `x-api-key`, not the
     rotating bearer.
     */
    @discardableResult
    internal static func refreshFootageToken() async throws -> String {
        if let existing = footageRefreshTask { return try await existing.value }

        let task = Task<String, Error> {
            defer { footageRefreshTask = nil }

            // Make sure the API key itself is loaded — without it the
            // request can't authenticate.
            _ = try await currentAPIKey()

            let resp = try await API.Footage.token.GET
                .markedAsAPIKeyAuthed()
                .retryPolicy(.retryWithLimit(maxAttempts: 1))
                .response()
                .asType(FootageTokenResponse.self)

            let ttl = Int(resp.expiresInSeconds ?? 1800)
            storeFootageToken(resp.jwt, ttl: ttl)
            log("Footage token refreshed (expires in \(ttl)s)")
            return resp.jwt
        }
        footageRefreshTask = task
        return try await task.value
    }
}

//--------------------------------------
// MARK: - CAMERA: STREAMING -
//--------------------------------------
extension Camera {

    /**
     Which footage window the stream URL should play.

      - ``live``: zero-latency live stream (`start_time=0&end_time=0`).
      - ``recorded(from:to:)``: historical playback. The window is
        capped at 3,600 seconds per manifest — longer playback requires
        re-fetching with the next window.
     */
    public enum FootageWindow: Sendable {
        case live
        case recorded(from: Date, to: Date)

        internal var timeParams: (start: Int, end: Int) {
            switch self {
            case .live:
                return (0, 0)
            case .recorded(let from, let to):
                return (Int(from.timeIntervalSince1970), Int(to.timeIntervalSince1970))
            }
        }
    }

    /**
     The resolution to request from the HLS endpoint. Mobile and small
     grid previews should use ``low``; full-screen / single-camera views
     should use ``high``.
     */
    public enum FootageResolution: String, Sendable {
        case low  = "low_res"
        case high = "high_res"
    }

    /**
     Which video codec the HLS manifest should be encoded with.

     Verkada serves HEVC by default, but AVPlayer's HLS pipeline is
     inconsistent about playing HEVC in `.m3u8` manifests (manifests
     itself the same way internally as `HLS-FASB` err=-15514 or
     `FigStreamPlayer` err=-12862). Default ``h264`` keeps AVKit happy
     across iOS / macOS / tvOS without callers having to know.
     */
    public enum FootageCodec: String, Sendable {
        case h264 = "h264"
        case hevc = "hevc"
    }

    /**
     Returns an HLS manifest URL suitable for `AVPlayer` / `VideoPlayer`.

     The URL embeds a short-lived JWT (30 min); cache and reuse the
     returned URL across that window, then call this again. Throws
     ``ConfigError/orgIdNotSet`` if ``Verkada/orgId`` has not been set.

     - Parameters:
       - window: ``live`` (default) or a ``recorded(from:to:)`` window
         no longer than 3,600 seconds.
       - resolution: ``high`` (default) or ``low``.
       - codec: ``h264`` (default) or ``hevc``. Default is h264 because
         AVPlayer's HLS pipeline doesn't reliably play Verkada's HEVC
         manifests on every macOS/iOS/tvOS version (you'll see
         `HLS-FASB` / `FigStreamPlayer` errors). Switch to ``hevc`` only
         if you've confirmed your playback target handles it.
     */
    @MainActor
    public func streamURL(
        for window: FootageWindow = .live,
        resolution: FootageResolution = .high,
        codec: FootageCodec = .h264
    ) async throws -> URL {
        guard let orgId = Verkada.orgId, !orgId.isEmpty
        else { throw ConfigError.orgIdNotSet }

        let jwt = try await Verkada.currentFootageToken()
        let times = window.timeParams

        let path = Verkada.baseURL
            .appending(path: "stream/cameras/v1/footage/stream/stream.m3u8")

        var components = URLComponents(url: path, resolvingAgainstBaseURL: false)!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "org_id",     value: orgId),
            URLQueryItem(name: "camera_id",  value: id),
            URLQueryItem(name: "jwt",        value: jwt),
            URLQueryItem(name: "start_time", value: String(times.start)),
            URLQueryItem(name: "end_time",   value: String(times.end)),
            URLQueryItem(name: "resolution", value: resolution.rawValue),
            URLQueryItem(name: "type",       value: "stream"),
        ]
        // `codec=h264` is honoured by Verkada *only* for `low_res`;
        // they ignore it for `high_res` and serve HEVC anyway. The
        // documented way to force H.264 across the board is the
        // `transcode=true` parameter — request that whenever the caller
        // asks for ``h264``.
        switch codec {
        case .h264:
            items.append(URLQueryItem(name: "codec",     value: "h264"))
            items.append(URLQueryItem(name: "transcode", value: "true"))
        case .hevc:
            items.append(URLQueryItem(name: "codec",     value: "hevc"))
        }
        components.queryItems = items

        guard let url = components.url
        else { throw PrestoError.urlConstructionFailure }
        return url
    }
}

//--------------------------------------
// MARK: - CAMERA: THUMBNAILS -
//--------------------------------------
extension Camera {

    /**
     Thumbnail resolution. Verkada's docs spell these with a dash
     (`low-res` / `hi-res`) rather than the underscore used elsewhere —
     don't be tempted to "normalise" the rawValue.
     */
    public enum ThumbnailResolution: String, Sendable {
        case low  = "low-res"
        case high = "hi-res"
    }

    /**
     Returns thumbnail image bytes for this camera at a specific moment
     (or "now", if `time` is nil — Verkada interprets the absent
     timestamp as the current frame).

     The result is raw image data (JPEG); decode with `UIImage(data:)` /
     `NSImage(data:)` / your image library of choice.

     - Parameters:
       - time: The instant to grab a frame for. `nil` means most-recent
         available; prefer ``latestThumbnail(resolution:)`` for that case
         — it routes to the optimised endpoint.
       - resolution: ``high`` (default) or ``low``.
     */
    public func thumbnail(
        at time: Date? = nil,
        resolution: ThumbnailResolution = .high,
        retryPolicy policy: RetryPolicy = .retryWithLimit(maxAttempts: 3)
    ) async throws -> Data {
        var params: [String: any Sendable] = [
            "camera_id":  id,
            "resolution": resolution.rawValue
        ]
        if let time { params["timestamp"] = Int(time.timeIntervalSince1970) }

        return try await API.Footage.thumbnail.GET
            .params(params)
            .retryPolicy(policy)
            .response()
            .data
    }

    /**
     Returns the most-recent thumbnail bytes for this camera. Faster than
     ``thumbnail(at:resolution:)`` because Verkada doesn't have to seek.
     */
    public func latestThumbnail(
        resolution: ThumbnailResolution = .high,
        retryPolicy policy: RetryPolicy = .retryWithLimit(maxAttempts: 3)
    ) async throws -> Data {
        try await API.Footage.thumbnailLatest.GET
            .params([
                "camera_id":  id,
                "resolution": resolution.rawValue
            ])
            .retryPolicy(policy)
            .response()
            .data
    }

    /**
     Returns a Verkada-hosted, shareable URL for a thumbnail — suitable
     for embedding outside your app (Slack messages, email, generated
     PDFs) where you can't carry the API auth headers.

     - Parameters:
       - time: The frame to capture. `nil` means most-recent.
       - resolution: ``high`` (default) or ``low``.
       - ttl: How long the link should remain valid, in seconds. Default
         86,400 (24h); maximum is whatever Verkada currently enforces
         server-side.
     */
    public func shareableThumbnailLink(
        at time: Date? = nil,
        resolution: ThumbnailResolution = .high,
        expiringIn ttl: TimeInterval = 86_400,
        retryPolicy policy: RetryPolicy = .retryWithLimit(maxAttempts: 3)
    ) async throws -> URL {
        var params: [String: any Sendable] = [
            "camera_id":  id,
            "resolution": resolution.rawValue,
            "expiry":     Int(ttl)
        ]
        if let time { params["timestamp"] = Int(time.timeIntervalSince1970) }

        let resp = try await API.Footage.thumbnailLink.GET
            .params(params)
            .retryPolicy(policy)
            .response()
            .asType(ThumbnailLinkResponse.self)

        guard let url = URL(string: resp.url)
        else { throw PrestoError.invalidURL }
        return url
    }
}
