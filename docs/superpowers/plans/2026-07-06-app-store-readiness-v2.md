# App Store Readiness v2 — Implementation Plan

Spec: `docs/superpowers/specs/2026-07-06-app-store-readiness-v2-design.md` · Findings (line refs below): `docs/audits/2026-07-06-full-audit.md` · Branch: `feature/app-store-readiness-v2`
Rules: agents fix only assigned findings in assigned files; no builds/commits by agents (orchestrator builds+commits per wave); cross-file needs → report, don't touch.

## Wave 1 — parallel, disjoint files (+ W2 backend concurrent)

### W1-A cloud/service correctness (audit lines 2–53 + 96–151)
Files: `Services/Cloud/*`, `Services/CoreDataManager.swift`, `Services/CoinService.swift`, `Services/AIRecommendationService.swift`, `Services/AuthenticationManager.swift`, `App/ContentView.swift`
- [x] Restore: rollback on catch; fetch-or-create Player by firebaseUID (dedupe); Int16/Int32 → clamping everywhere; set sessionExercise.exercise via exerciseId lookup; pick newest profile doc + filter children by playerId
- [x] Upload: guard empty arrayContainsAny; skip nil-id entities (no UUID minting)
- [x] Sync: surface incremental-sync errors; timer weak self
- [x] CoreDataManager: never auto-delete store on load error (surface persistentStoreError; destroyPersistentStore only for explicit reset); save() → AppLogger + published error + rollback (keep signature)
- [x] AIRecommendationService: endpoint → get_advanced_recommendations (adapt schema per functions/main.py:585); remove dead code line 154
- [x] AuthenticationManager: SIWA presentationContextProvider via AppleSignInDelegate conformance; stop retrying 4xx; async/await warnings (~169)
- [x] CoinService: operate on the passed context consistently
- [x] ContentView: FetchRequest predicate from userUID at init (no unfiltered first render)

### W1-B dashboard/training UX (audit 241–316 subset)
Files: `Views/Dashboard/DashboardView.swift`, `Views/Training/TodaysTrainingView.swift`, `Views/Training/TrainHubView.swift`, `Views/Training/SessionCompleteView.swift`
- [x] Fix quick-action routing (View Progress→Progress, Browse Library→Exercises); rec-card empty/error states + retry; cancel/dedupe onAppear cloud Task; onChange 2-param (134,156)
- [x] TodaysTraining: refresh state post-session; Skip Day confirmation
- [x] TrainHub: empty state instead of infinite Loading
- [x] SessionComplete: wire or remove dead "Generate Another Drill"

### W1-C auth/exercises/settings UX (audit 241–316 subset)
Files: `Views/Auth/AuthenticationView.swift`, `Views/Auth/UnifiedOnboardingView.swift`, `Views/Auth/Onboarding/OnboardingPaywallView.swift`, `Views/Exercises/{CustomDrillGeneratorView,ExerciseLibraryView,ExerciseDetailView,QuickDrillSheet}.swift`, `Views/Settings/SettingsView.swift`, `App/TechnIQApp.swift`
- [x] Auth: remove/wire dead gear buttons; forgot-password feedback (success/error)
- [x] Onboarding: skip-step target; Stadium Night tokens for gray fills; cancel task/timer on disappear; unreachable-catch warning; paywall legal-link domain consistency + hide hardcoded price fallback when product missing
- [x] Drill gen: visible error + retry; fix static pulse animation; .accentColor→.tint
- [x] Library: surface YouTube import errors; DetailView: stop YouTubeWebView reload on every update; QuickDrillSheet: cancel generation Task on dismiss
- [x] Appearance: wire preferredColorScheme if DesignSystem adapts, else remove picker (+ TechnIQApp.swift:64)

### W1-D mechanical modernization (audit 318–366 subset + build warnings)
Files: `Utilities/HapticManager.swift`, `Views/Training/{WeekEditorView,TrainingPlansListView,SessionEditorView,PlanEditorView,DayEditorView}.swift`, `Views/Analytics/SkillTrendChartView.swift`, `Services/{AvatarService,CustomDrillService,InsightsEngine,WeaknessAnalysisService}.swift`, `Services/YouTubeService.swift` (warning lines only), `Components/CoinDisplayView.swift`
- [x] onChange → 2-param at all remaining sites; UIScreen.main → GeometryReader/window; unused vars; unreachable catch/try warnings
- [x] Swift-6 conformance warnings: InsightsEngine:28, WeaknessAnalysisService:7 (protocol isolation)
- [x] InsightsEngine same-day streak bug (:170)

### W1-E project files + tooling (audit 368–501)
Files: `.swiftlint.yml`(new), `.github/workflows/ci.yml`(new), `.gitignore`, `TechnIQ/Info.plist`, `project.pbxproj`, shared scheme(new), `CLAUDE.md`, `APP_STORE_DEPLOYMENT_CHECKLIST.md`, dead view files
- [x] SwiftLint config (calibrated YAML from audit ~line 419); CI: build+test+lint on PR
- [x] Info.plist: +ITSAppUsesNonExemptEncryption=false; remove SceneDelegate/UISceneConfigurations block
- [x] pbxproj: TARGETED_DEVICE_FAMILY=1
- [x] Delete 5 unreferenced view files (re-verify zero refs first) + pbxproj refs
- [x] Commit shared scheme for CI; .gitignore += .firebase/ .superpowers/ *.backup
- [x] CLAUDE.md: real service table (Cloud/ refactor, YouTubeService, AIRecommendationService, WeaknessAnalysisService), build destination 'platform=iOS Simulator,name=iPhone 15 Pro', 8 endpoints; fix lowercase claude.md tracking; rewrite APP_STORE_DEPLOYMENT_CHECKLIST.md from audit

### W2 backend (audit 153–198) — concurrent with W1
Files: `functions/main.py`, `firestore.rules`, `firestore.indexes.json`, `functions/requirements.txt`
- [x] IDOR: token uid must equal body user_id (or ignore body) — all endpoints; strip ALLOW_UNAUTHENTICATED
- [x] Rate limiting: per-uid Firestore daily counters (LLM 10/day, YouTube 50/day, transactional)
- [x] Payload caps; sanitized error responses; CORS tighten
- [x] delete_account: cascade all user data incl. trainingSessions/exercises subcollections
- [x] get_user_training_history: right collection + composite index
- [x] rules: communityPosts impersonation/like-tampering; trainingSessions/exercises create (resource.data on create bug)
- [x] Pin requirements.txt; rebuild venv; full pytest (endpoint tests must collect); NO deploy

**Gate 1:** build green + swiftlint runs + pytest green → commit waves separately (`fix(cloud)…`, `fix(ux)…`, `chore(tooling)…`, `fix(functions)…`)

## Wave 3 — SDK bumps (sequential)
- [x] firebase-ios-sdk → 11.x latest, GoogleSignIn → 8.x; resolve, fix API fallout, build until green; run unit tests on sim (iPhone 15 Pro); verify GoogleService-Info + URL schemes intact

## Wave 4 — structural
- [x] Sync architecture: per-entity sync on save (matches/plans/drills/avatar/stats/goals), tombstone deletions + restore skip, uniqueness constraints (additive model change + merge policy), TrainingSession.updatedAt + persisted lastSyncDate, UID-filtered sync fetches, missing fields (xpEarned, weaknessProfileJSON, drill-schema fields) + recommendationFeedback restore, conflict-resolution wiring for profile doc
- [x] YouTubeService @MainActor + call-site fixes; fire-and-forget → structured async; DashboardView off-main Core Data
- [x] NavigationView → NavigationStack (41 files, mechanical, screenful-at-a-time)
- [x] Dynamic Type: DesignSystem fonts → relativeTo:; spot-check extremes
- [x] A11y sweep: labels on icon-only buttons, decorative images hidden, rating tap targets ≥44pt
- [x] YOUTUBE_API_KEY via git-ignored Config.xcconfig + template + doc
**Gate 2:** build + full unit tests green → commits

## Wave 5 — assets + polish
- [x] App icon 1024px (generate, no alpha) + Contents.json filename
- [x] PrivacyInfo.xcprivacy: +Fitness, OtherUserContent, UsageData; PRIVACY_POLICY.md: all 4 auth methods, UGC, deletion path, new date
- [x] Scripted .foregroundColor→.foregroundStyle, .cornerRadius→clipShape sweep (isolated commit)
- [x] docs/appstore/: listing copy (name/subtitle/description/keywords), screenshot shot-list, review notes w/ demo-account placeholder
**Gate 3:** final build + tests + lint → final report + unresolved questions

## Deferred (post-1.0, recorded)
@Observable migration; print→AppLogger sweep; YouTube backend proxy; offline sync queue; iPad adaptive UI; localization; incremental-sync redesign beyond updatedAt; certificate pinning.
