//
//  Pagination.swift
//  VerkadaKit
//
//  Generic page-accumulator for Verkada's cursor-based list endpoints.
//  Calls the supplied request once per page, threading `page_token`
//  through until the server returns no `next_page_token`.
//
//  Most callers reach for `Door.list()` / `AccessUser.list()` etc. — those
//  call into here under the hood. Reach for `Verkada.paginated(...)`
//  directly if you need a list endpoint we haven't wrapped yet.
//

import Foundation

extension Verkada {
    /**
     Auto-pages a list endpoint until the server returns no more results,
     and returns the concatenation. Each page is fetched serially because
     Verkada's pagination is cursor-based (the next request depends on the
     previous response's `next_page_token`).

     - Parameters:
       - request: A `.GET` request for the list endpoint, **without** a
         `page_token` already set. Add any filters (date ranges, ids,
         etc.) before passing in.
       - envelope: The ``PageEnvelope`` type alias for this endpoint (e.g.
         `AccessUsersPage.self`).
       - pageSize: The per-page size sent to the server. Default is 200
         (Verkada's documented maximum, which minimises round-trips).
       - retryPolicy: Retry policy applied to every page request.
     - Returns: Every item across every page, flattened in server order.
     */
    public static func paginated<Item: Decodable & Sendable, Key: PageEnvelopeKey>(
        from request: Request,
        envelope: PageEnvelope<[Item], Key>.Type,
        pageSize: Int = 200,
        retryPolicy: RetryPolicy = .retryWithLimit(maxAttempts: 3)
    ) async throws -> [Item] {
        try await fetchPage(
            from:        request.params(["page_size": pageSize]),
            envelope:    envelope,
            pageToken:   nil,
            accumulated: [],
            retryPolicy: retryPolicy
        )
    }

    private static func fetchPage<Item: Decodable & Sendable, Key: PageEnvelopeKey>(
        from request: Request,
        envelope: PageEnvelope<[Item], Key>.Type,
        pageToken: String?,
        accumulated: [Item],
        retryPolicy: RetryPolicy
    ) async throws -> [Item] {
        var paged = request.retryPolicy(retryPolicy)
        if let pageToken { paged = paged.params(["page_token": pageToken]) }

        let envelope = try await paged.response()
            .asType(envelope)

        let combined = accumulated + envelope.items
        guard envelope.hasMore, let next = envelope.nextPageToken
        else { return combined }

        return try await fetchPage(
            from:        request,
            envelope:    PageEnvelope<[Item], Key>.self,
            pageToken:   next,
            accumulated: combined,
            retryPolicy: retryPolicy
        )
    }
}
