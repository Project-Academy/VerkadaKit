//
//  API+Audit.swift
//  VerkadaKit
//
//  `/core/v1/audit_log` — paginated, time-windowed admin action log.
//

import Foundation
import Tapioca

extension API {
    internal enum Audit: Endpoints {
        typealias API = Verkada
        static var base: URL { Verkada.baseURL.appending(path: "core/v1") }

        case log

        var path: URL {
            switch self {
            case .log: Self.base.appending(path: "audit_log")
            }
        }
    }
}

internal enum AuditKey: PageEnvelopeKey {
    static let itemsKey = "audit_logs"
}
internal typealias AuditPage = PageEnvelope<[AuditLogEvent], AuditKey>

//--------------------------------------
// MARK: - PUBLIC API -
//--------------------------------------
extension AuditLogEvent {

    /**
     Fetches audit-log events between two timestamps, auto-paging.

     Verkada caps a single response window at 30 days; supply narrower
     ranges if you're filtering for a specific session. Pass `nil` for
     either bound to leave it open-ended (subject to Verkada's
     organisation-wide retention).
     */
    @MainActor
    public static func list(
        from start: Date? = nil,
        to end: Date? = nil,
        retryPolicy policy: RetryPolicy = .retryWithLimit(maxAttempts: 3)
    ) async throws -> [AuditLogEvent] {
        var params: [String: any Sendable] = [:]
        if let start { params["start_time"] = Int(start.timeIntervalSince1970) }
        if let end   { params["end_time"]   = Int(end.timeIntervalSince1970)   }

        return try await Verkada.paginated(
            from:        API.Audit.log.GET.params(params),
            envelope:    AuditPage.self,
            retryPolicy: policy
        )
    }
}
