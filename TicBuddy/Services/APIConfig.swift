// TicBuddy — APIConfig.swift
// Single source of truth for all proxy configuration.
//
// URL reading priority (first non-placeholder wins):
//   1. Xcode scheme env var   — PROXY_BASE_URL (dev/CI debug sessions)
//   2. Info.plist entry        — PROXY_BASE_URL key (baked into app bundle at build time)
//   3. Placeholder fallback    — shows a clear "not configured" error in the UI
//
// HOW TO CONFIGURE:
//   Option A — Xcode scheme (debug only):
//     Edit Scheme → Run → Arguments → Environment Variables
//     PROXY_BASE_URL = https://<your-project>.up.railway.app
//     AUTH_TOKEN     = <your shared secret>
//
//   Option B — Info.plist (works in all build configs, incl. device installs):
//     Open TicBuddy/Info.plist and fill in:
//       PROXY_BASE_URL  →  https://<your-project>.up.railway.app
//       AUTH_TOKEN      →  <your shared secret>
//     (Do not commit real values if this is a public repo.)
//
// tb-mvp2-050: consolidated from 3 scattered service files so there is exactly
// one place to update when the Railway URL changes.

import Foundation

enum APIConfig {

    // MARK: - Proxy Base URL

    /// Base URL of the deployed TicBuddyProxy on Railway (no trailing slash).
    /// Returns the placeholder string if neither source has a real value.
    static let proxyBaseURL: String = {
        // 1. Xcode scheme env var (set via Edit Scheme → Run → Environment Variables)
        if let envURL = ProcessInfo.processInfo.environment["PROXY_BASE_URL"],
           !envURL.isEmpty, !envURL.contains("YOUR_RAILWAY") {
            return envURL
        }
        // 2. Info.plist entry (baked into bundle — works outside Xcode debug sessions)
        if let plistURL = Bundle.main.infoDictionary?["PROXY_BASE_URL"] as? String,
           !plistURL.isEmpty, !plistURL.contains("YOUR_RAILWAY") {
            return plistURL
        }
        // 3. Placeholder — surfaces as a DNS failure; isConfigured == false lets UI warn early
        return "https://YOUR_RAILWAY_URL_HERE"
    }()

    // MARK: - Auth Token

    /// Shared secret sent as `Authorization: Bearer <token>` to the proxy.
    static let authToken: String = {
        if let envToken = ProcessInfo.processInfo.environment["AUTH_TOKEN"],
           !envToken.isEmpty {
            return envToken
        }
        if let plistToken = Bundle.main.infoDictionary?["AUTH_TOKEN"] as? String,
           !plistToken.isEmpty {
            return plistToken
        }
        return "dev-token"
    }()

    // MARK: - Derived Endpoints

    static var tictalkURL: String { proxyBaseURL + "/api/tictalk" }
    static var ttsURL:     String { proxyBaseURL + "/api/tts" }
    static var ragURL:     String { proxyBaseURL + "/api/rag" }

    // MARK: - Diagnostics

    /// True when a real Railway URL has been configured (not the placeholder).
    /// Use this to show an early "proxy not configured" warning rather than letting
    /// network requests fail silently with a confusing DNS error.
    static var isConfigured: Bool {
        !proxyBaseURL.contains("YOUR_RAILWAY")
    }
}
