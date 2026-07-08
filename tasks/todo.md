# App Store Readiness v2 — FINAL STATUS (2026-07-08)

Branch: `feature/app-store-readiness-v2` (11 commits, local only — NOT pushed). Full audit: `docs/audits/2026-07-06-full-audit.md` (121 findings) · Spec: `docs/superpowers/specs/2026-07-06-app-store-readiness-v2-design.md` · ASC package: `docs/appstore/app-store-listing.md`

## Done (all verified by build; suite green at every gate that ran)
- [x] 8-domain audit, 121 findings, high-sev claims adversarially verified
- [x] Cloud/data-integrity fixes: restore rollback+dedupe, clamped narrowing, store never auto-deleted, exercise links restored, arrayContainsAny guard, real recs endpoint (was 404ing silently)
- [x] Sync architecture: ALL entities sync continuously (was: once at onboarding), updatedAt watermarks + persisted lastSync, uid-scoped fetches (cross-account leak closed), deletion tombstones (no resurrection), field parity + playerId stamping, conflict merge live, uniqueness constraints, round-trip tests
- [x] Backend: IDOR fixed, bypass flag emulator-only, per-uid daily quotas, sanitized errors, full delete_account cascade, payload caps, sharedDrills+leaderboard rules (both features were default-denied!), deps pinned, 181 tests green
- [x] UX: keep-alive tabs (state survives switching), wrong-tab routing fixed, error/empty/loading states, real paywall prices only, dead controls removed, skip-day confirm, forgot-password feedback, keyboard-safe tab content, pull-to-refresh
- [x] Modernization: Firebase 11.15 + GoogleSignIn 8.0 (privacy-manifest mandate), 14 unused SDK products pruned, NavigationView×46→NavigationStack (zero left), onChange 2-param, Dynamic Type font mapping, @MainActor on YouTubeService (crash risk), Swift-6 warnings cleared
- [x] A11y: shared A11yModifier; labels/hidden/44pt targets across all view dirs (from ~zero)
- [x] Tooling: SwiftLint (139 warn/0 err), CI workflow, shared scheme, 4 dead views deleted, docs/CLAUDE.md refreshed
- [x] App Store: icon generated (stadium-night kickoff circle), ITSAppUsesNonExemptEncryption, SceneDelegate ghost removed, iPhone-only v1, privacy manifest+policy updated, **unsigned Release ARCHIVE SUCCEEDED** (34 SDK privacy manifests aboard)

## Known constraint (documented in CLAUDE.md + checklist)
Every xcodebuild (build/test/archive) needs `SWIFT_ENABLE_EXPLICIT_MODULES=NO CLANG_ENABLE_EXPLICIT_MODULES=NO` — Xcode 26 vs FirebaseFirestoreInternal. GUI Archive fails; archive via CLI.

## Final verification (2026-07-07 23:52)
Full unit suite: **128/128 pass** (125 prior + 3 new CloudSyncRoundTripTests) · build green · unsigned Release archive SUCCEEDED · SwiftLint 139 warn/0 err · backend 181/181.

## User actions required (cannot be automated)
- [ ] Review branch → PR/merge (nothing pushed)
- [ ] Rotate keys in functions/.env.yaml, then `cd functions && firebase deploy --only functions` AND `firebase deploy --only firestore` (backend fixes + rules not live until deployed; validate rules in emulator first if possible)
- [ ] Put real YouTube key in `Config/Secrets.xcconfig` before archiving (empty = YouTube features hidden)
- [ ] GitHub repo secret `GOOGLE_SERVICE_INFO_PLIST_B64` (base64 of GoogleService-Info.plist) for CI
- [ ] Host updated PRIVACY_POLICY.md; regenerate hosting/ HTML from it (hosted copy predates 2026-07-07 edits)
- [ ] ASC: app record, StoreKit product (com.techniq.pro.monthly), screenshots (6.9"), nutrition labels per listing doc, demo account
- [ ] Physical-device test: SIWA, Google sign-in, purchase, sync between two devices
- [ ] Watch first TestFlight build for Core Data migration failures on old beta stores (uniqueness constraints; safe on fresh installs)

## Deferred post-1.0 (recorded in spec)
@Observable migration · print→AppLogger sweep (283) · YouTube backend proxy (key off-device) · offline sync queue · iPad layout · localization · .foregroundColor/.cornerRadius style sweep (1,600 sites, cosmetic) · get_user_training_history legacy collection

## Unresolved questions
1. Bundle ID: keep `evan.TechnIQ`? (permanent at first upload)
2. Privacy policy hosting URL?
3. Paywall in v1 review — StoreKit products configured?
4. Generated icon OK or brand assets coming?
5. Rate limits (LLM 10/day, light 50/day) OK?
6. Drop Player(firebaseUID) uniqueness constraint to de-risk old beta stores, or keep?
