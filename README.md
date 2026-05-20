# VerkadaKit

Swift package that wraps Verkada's REST API in the same Tapioca-based style
as MerakiKit, SlackKit, and XeroKit.

### Installation

```
https://github.com/Project-Academy/VerkadaKit
```

Requires iOS 17.6+, macOS 13+, or tvOS 18+.

### Usage

```swift
import Verkada

Verkada.region = .us            // or .eu, .custom(URL)
Verkada.orgId  = secrets.verkadaOrgId   // required only for streaming
Verkada.keysFetcher = {
    Credentials(apiKey: secrets.verkadaAPIKey)
}
Verkada.logger = { print("[Verkada]", $0) }   // optional

// Access
let doors  = try await Door.list()
let user   = try await AccessUser.with(externalId: "abc")
try await Door(id: "DOOR-ID").adminUnlock()
try await Door(id: "DOOR-ID").unlock(for: user)

// Cameras: live + recorded HLS
let camera = Camera(id: "CAMERA-ID")
let liveURL = try await camera.streamURL(for: .live)
let recentURL = try await camera.streamURL(
    for: .recorded(from: Date().addingTimeInterval(-600), to: Date()),
    resolution: .high
)
// → hand `liveURL` to AVPlayer / VideoPlayer

// Cameras: thumbnails
let jpeg     = try await camera.latestThumbnail()                    // Data
let atMoment = try await camera.thumbnail(at: someDate)
let shareURL = try await camera.shareableThumbnailLink(expiringIn: 3600)
```

### Improvements over the older Kits

- `postProcess` *throws* on non-2xx instead of silently returning.
- Typed errors (`APIError` carries `id` / `message` / `statusCode`, with
  pattern-matchable `KnownCode` cases for the common Verkada error IDs).
- Single-flight token cache — concurrent callers coalesce onto one
  `POST /token` refresh; tokens are reused while valid.
- 401 with a stale token transparently re-mints once, then surfaces
  `AuthError.unauthorizedAfterRefresh` rather than looping.
- 429 honours `Retry-After` with a per-request retry budget
  (`.retryWithLimit(maxAttempts: 3)` by default).
- Built-in cursor pagination via `Verkada.paginated(from:envelope:)` and
  per-resource `.list()` helpers.
- Region-configurable base URL (`.us`, `.eu`, `.custom(URL)`).
- No `print` calls — opt in via the `Verkada.logger` closure.

### Surfaces covered

| Surface         | Endpoints |
| --------------- | --------- |
| Token           | `POST /token` (automatic) |
| Access Users    | `GET/POST/PUT/DELETE /access/v1/access_users` |
| Access Groups   | `GET /access/v1/access_groups`, `PUT/DELETE /access/v1/access_groups/group/user` |
| Doors           | `GET /access/v1/doors`, `POST /access/v1/door/admin_unlock`, `POST /access/v1/door/user_unlock` |
| Cameras         | `GET /cameras/v1/devices` |
| Footage         | `GET /cameras/v1/footage/token`, HLS stream URL builder (live + recorded ≤ 3600s) |
| Thumbnails      | `GET /cameras/v1/footage/thumbnails`, `…/latest`, `…/link` |
| Audit Log       | `GET /core/v1/audit_log` |

Adding more surfaces is a copy-of-the-pattern exercise: declare an
`Endpoints` enum under `API`, a `PageEnvelopeKey` if the response is
paginated, and a `.list()` / `.create()` / etc. method on the model type.
