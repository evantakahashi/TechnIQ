# Live Tracker — App Store Readiness v2 (2026-07-06)

Supersedes the stale 2025 checklist (verified: most of it was already fixed; see docs/audits/2026-07-06-full-audit.md).
Plan: docs/superpowers/plans/2026-07-06-app-store-readiness-v2.md · Spec: docs/superpowers/specs/2026-07-06-app-store-readiness-v2-design.md

## Status
- [x] 8-domain audit (121 findings, verified)
- [x] Spec + plan
- [ ] Wave 1: parallel fix agents (A cloud/services, B dash/training UX, C auth/exercises UX, D modernization, E tooling) + W2 backend — IN FLIGHT
- [ ] Gate 1: build + lint + pytest, commit
- [ ] Wave 3: Firebase/GoogleSignIn SDK bump (submission blocker)
- [ ] Wave 4: sync architecture, NavigationStack, Dynamic Type, a11y
- [ ] Wave 5: app icon, privacy manifest/policy, style sweep, ASC metadata docs
- [ ] Final: full verify + report

## User actions still required (cannot be automated)
- Rotate functions/.env.yaml API keys; then `firebase deploy --only functions` (backend fixes won't be live until deployed)
- Apple Developer: confirm SIWA capability on the App ID; physical-device test (SIWA, Google SSO, purchases)
- App Store Connect: create app record, StoreKit products for paywall, upload screenshots, nutrition labels, demo account
- Host privacy policy (need URL)
- Decide: bundle ID keep/change (permanent after first upload); icon branding

## Unresolved questions
See spec §Unresolved (bundle ID, policy hosting, paywall for v1, key rotation, icon branding, quota defaults).
