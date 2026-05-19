//
//  RetryPolicy.swift
//  VerkadaKit
//

/**
 Controls how aggressively a request is re-fired when ``Verkada/postProcess(response:from:)``
 decides a transient failure (429 rate limit, 5xx, 401 with stale token) warrants a retry.

 The default for every request is ``retryWithLimit`` with a budget that prevents
 runaway loops if Verkada is in a sustained bad state.
 */
public enum RetryPolicy: Sendable {
    /// Retry indefinitely. Use only for endpoints whose failure mode is genuinely transient.
    case retry
    /// Retry up to `maxAttempts` more times before giving up.
    case retryWithLimit(maxAttempts: Int)
    /// Never retry — surface the first error to the caller.
    case noRetry
}
