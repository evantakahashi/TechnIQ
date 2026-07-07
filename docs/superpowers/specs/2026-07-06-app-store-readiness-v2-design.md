# App Store Readiness v2 — Design

**Date:** 2026-07-06 · **Mode:** autonomous (user mandate: loop until App Store-ready w/ excellent UX; no blocking questions — assumptions recorded)
**Input:** 8-domain parallel audit, 121 findings (4 blocker, 31 high), high-sev bug claims adversarially verified (14 real / 1 refuted). Full findings: `docs/audits/2026-07-06-full-audit.md`.

## Current state (verified, not per stale docs)
- Build SUCCEEDS on Xcode 26.4. 125 unit tests exist (not in CI). SwiftLint absent (now installed, no config).
- **Already done, docs wrong:** Sign in with Apple fully implemented (Guideline 4.8 OK), in-app account deletion end-to-end (5.1.1(v) OK), all 8 function endpoints require auth by default, /users subcollection rules exist, most tasks/todo.md crashers fixed.
- **True submission blockers:** (1) app icon missing; (2) firebase-ios-sdk 10.18.0 + GoogleSignIn 7.0.0 predate Apple's May-2024 SDK privacy-manifest mandate → ITMS-91053/91061 auto-reject; (3) ITSAppUsesNonExemptEncryption undeclared; (4) YOUTUBE_API_KEY build setting undefined → YouTube dead in archive builds.
- **Worst data-integrity gaps:** most entities sync to cloud exactly once (onboarding) → device-switch data loss; store deleted on any Core Data load error; deletions never propagate (resurrection); no uniqueness constraints; cross-account leak on shared device; restore drops exercise links.
- **Backend:** IDOR (uid vs body user_id), ALLOW_UNAUTHENTICATED bypass flag, no rate limiting, raw exception leaks, community rules allow impersonation, delete_account leaves training data.
- **UX:** 2 dashboard quick-actions route to wrong tabs; dead Appearance picker (app hardcodes dark); silent failures (drill gen, forgot password, YouTube import); infinite spinners w/o empty/error states; no Dynamic Type; near-zero a11y labels; iPad enabled but zero adaptive UI.

## Approaches considered
- **A (chosen): risk-ordered waves, parallel agents inside each wave, disjoint file sets, build gate between waves.** Safe merges, incremental verification.
- B: everything parallel by domain in worktrees — rejected: SDK bump + 41-file nav migration + style sweeps collide; merge hell, no incremental build gate.
- C: minimum-submission-path only — rejected: fails "fully complete, excellent UX" mandate.

## Decisions (w/ rationale)
1. **iPhone-only v1** (TARGETED_DEVICE_FAMILY=1): zero iPad-adaptive UI today; compat mode still runs on iPad; avoids iPad screenshots/review risk. iPad = post-1.0.
2. **SDK bump to current Firebase 11.x + GoogleSignIn 8.x** in dedicated wave w/ build/fix loop (privacy-manifest mandate; auth/Firestore/Functions retest).
3. **Sync architecture fix** (per-entity sync triggers + tombstone deletions + uniqueness constraints + updatedAt + UID-filtered fetches + restore playerId filtering + missing fields): additive lightweight migration only.
4. Appearance control: wire if DesignSystem tokens adapt cleanly, else remove picker + commit to dark (Stadium Night is dark-designed). Agent decides on token inspection.
5. YouTube key: git-ignored xcconfig now; proxying via existing get_youtube_recommendations function = post-1.0 (2,945-line YouTubeService refactor too risky this pass).
6. NavigationView→NavigationStack across 41 files: yes (modernization + kills iPad-split weirdness). onChange/UIScreen.main/accentColor: yes. `.foregroundColor`(1389)/`.cornerRadius`(213): scripted sweep, isolated commit, last. @Observable migration (19 services) + print→AppLogger (283): DEFERRED post-1.0 (risk/size vs ship value).
7. App icon: generate 1024px programmatically (soccer + tech, Stadium Night palette), no alpha; replaceable asset, flagged for user/brother branding pass.
8. Keep bundle ID `evan.TechnIQ` (change = Firebase re-registration; user call, see questions).
9. Backend: fix IDOR/bypass/rate-limit/error-sanitization/delete-cascade/rules; pin requirements; rebuild venv; run pytest. **No deploys** (user action).
10. No pushes to origin; local commits per wave on `feature/app-store-readiness-v2`.

## Waves
1. **W1 (parallel, disjoint):** A cloud/service correctness S-fixes · B dashboard/training UX · C auth/exercises/settings UX · D mechanical modernization + Swift-6 warnings · E project files (lint config, CI, Info.plist, scheme, dead files, docs). **W2 backend** runs concurrently (functions/ + rules only).
2. **W3:** SDK bumps + fallout (sequential, risky).
3. **W4:** sync architecture + NavigationStack migration + Dynamic Type + a11y sweep.
4. **W5:** icon + style sweep + privacy manifest/policy + ASC metadata prep.
5. **Final:** full build + tests + lint, docs refresh, report.
Gate after each wave: `xcodebuild build` green (+ unit tests from W3 on).

## Assumptions (user away)
Local commits OK (repo's PR workflow); no push/deploy/ASC actions; icon is replaceable placeholder-quality-but-shippable; key rotation + physical-device testing + demo account remain user actions.

## Unresolved questions
1. Keep bundle ID `evan.TechnIQ` or switch to reverse-DNS before first upload (permanent after)?
2. Host PRIVACY_POLICY.md where (GitHub Pages?) — need URL for ASC.
3. Paywall live in onboarding — intended for v1.0 review, and are StoreKit products configured in ASC?
4. Rotate functions/.env.yaml keys now (old ones still live)?
5. Icon: use generated one or provide brand assets?
6. Anonymous-auth users + rate limits: acceptable quota defaults (10 drill-gens/day)?
