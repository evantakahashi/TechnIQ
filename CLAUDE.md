# TechnIQ Development Guidelines

## About TechnIQ
AI-powered soccer training app for iOS. Personalized programs, smart drills, progress analytics.

**Tech Stack:** SwiftUI, Core Data, Firebase (Auth, Firestore, Functions), Google Sign-In, Sign in with Apple, StoreKit, Anthropic (via Functions), YouTube Data API v3
**Targets:** iOS 17.0+, iPhone (v1.0 is iPhone-only; `TARGETED_DEVICE_FAMILY = 1`), arm64

---

## Quick Commands
All xcodebuild invocations (build/test/archive) MUST append `SWIFT_ENABLE_EXPLICIT_MODULES=NO CLANG_ENABLE_EXPLICIT_MODULES=NO` — Xcode 26's explicit modules can't precompile FirebaseFirestoreInternal, and project-level settings don't reach SPM targets. GUI Product>Archive will fail; archive from CLI.
- **Build:** `xcodebuild -scheme TechnIQ -destination 'platform=iOS Simulator,name=iPhone 17' SWIFT_ENABLE_EXPLICIT_MODULES=NO CLANG_ENABLE_EXPLICIT_MODULES=NO build`
- **Test (unit):** `xcodebuild -scheme TechnIQ -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TechnIQTests SWIFT_ENABLE_EXPLICIT_MODULES=NO CLANG_ENABLE_EXPLICIT_MODULES=NO test`
- **Lint:** `swiftlint` (config `.swiftlint.yml`; ~140 warnings / 0 errors today, not yet `--strict`)
- **CI:** `.github/workflows/ci.yml` — SwiftLint, build + unit tests, Touchline UI tests on PR / push to main. Needs repo secret `GOOGLE_SERVICE_INFO_PLIST_B64` (base64 of the gitignored plist); `Config/Secrets.xcconfig` is generated on the runner (optional `YOUTUBE_API_KEY` secret).
- **Deploy functions:** `cd functions && firebase deploy --only functions`
- **Commit:** `/commit`
- **Build skill:** `/build`
- **Deploy skill:** `/deploy`

## SourceKit False Positives
Core Data types (Player, Exercise, etc.) and Firebase modules show "Cannot find in scope" in IDE but build fine. Ignore these.

---

## Architecture

### Core Data Entities (17)
```
Player (root)
├── exercises [Exercise]
├── sessions [TrainingSession] → exercises [SessionExercise]
├── trainingPlans [TrainingPlan] → weeks [PlanWeek] → days [PlanDay] → sessions [PlanSession]
├── avatarConfiguration [AvatarConfiguration]
├── ownedAvatarItems [OwnedAvatarItem]
├── stats [PlayerStats], playerProfile [PlayerProfile], playerGoals [PlayerGoal]
├── matches [Match] → season [Season]
├── recommendationFeedback [RecommendationFeedback]
└── seasons [Season]

Independent: CloudSyncStatus, MLRecommendation
```

### Services (`TechnIQ/Services/`, primary singletons via `.shared`)
| Service | @MainActor | Responsibility |
|---------|------------|----------------|
| CoreDataManager | No | Core Data stack, persistent store, migrations |
| AuthenticationManager | No | Firebase Auth (email, Google, Apple, anonymous) |
| YouTubeService | No | YouTube Data API v3, video data, caching, smart recommendations, rate limiting |
| CloudService | Yes | Firestore sync (bi-directional Core Data ↔ Firestore), cloud restore, network monitoring — split across `Cloud/CloudService.swift` + `+Upload`/`+Restore`/`+Sync` |
| AIRecommendationService | Yes | AI/ML drill & video recommendations (`get_advanced_recommendations`) |
| AICoachService | Yes | Daily AI coaching + plan adaptation via Functions |
| CustomDrillService | Yes | AI drill generation via Firebase Functions |
| TrainingPlanService | Yes | Plan CRUD, AI generation, completion-based progression |
| WeaknessAnalysisService | Yes | Skill-gap / weakness analysis feeding recommendations |
| CommunityService | Yes | Community posts/UGC, comments, report & block |
| SubscriptionManager | Yes | StoreKit subscriptions, paywall, purchase/restore |
| XPService | Yes | XP calc, level system (1-50), 10-tier career path |
| CoinService | Yes | Coin economy, earning events, transactions |
| AchievementService | Yes | 30 achievements, unlock checking, XP rewards |
| AvatarService | Yes | Avatar configuration, item inventory |
| MatchService | Yes | Match CRUD, season management |
| ActiveSessionManager | Yes | Live training session state machine |
| InsightsEngine | Yes | Analytics calculations, trend analysis |

Supporting: `ServiceError.swift` (shared error enum), `CoreDataFetchRequests.swift` (dynamic description helpers), `Protocols/` (per-service protocols for DI/testing). `AppLogger` lives in `Utilities/`.

### Firebase Functions (functions/main.py)
7 HTTPS endpoints: `get_youtube_recommendations`, `generate_custom_drill`, `get_advanced_recommendations`, `generate_training_plan`, `get_daily_coaching`, `get_plan_adaptation`, `delete_account`
All require Firebase Auth in production.

### Drill-gen pipeline (functions/, opus-4-8, prompt-cached)
`generate_drill` (drill_generator.py): routing (archetype_picker + skill overrides, partner escalation) → open-verb DSL (dsl_parser: any soccer verb, 8 closed semantic classes, inline `verb X = class` declarations) → deterministic repairs (drill_post_processor: carrier-run fix, collect/handover/run-back INJECTION, or-drop, cone hygiene, marker overshoot/stop-short, sync/reset tagging, crop, baked coords) → ~28 validators (drill_validator) + quality gate (drill_quality, blocking required_styles) → ≤5 retries w/ error feedback. Animation: model-AUTHORED phase timeline (drill_animator, referee = eval/anim_lint 8 artifact classes + fidelity check; compiled fallback via drill_timeline + drill_director). Exemplars.json = few-shot corpus incl. user-rated goldens (frozen; gate deploys via eval/golden/labels.json). eval/evan_voice.md = the judging calibration corpus. Web player engine lives in the review-page template + embedded in-app (DrillWebAnimationView in DrillDiagramView.swift, WKWebView; wire-in deferred until Touchline). Exercise.animationJSON persists films.

---

## Folder Structure
```
TechnIQ/
├── App/           (TechnIQApp, ContentView)
├── Models/        (CoreData classes/properties, value types, config)
├── Services/      (service singletons; Cloud/ and Protocols/ subdirs)
├── Views/
│   ├── Auth/      Dashboard/ Training/ Exercises/ Matches/
│   ├── Avatar/    Analytics/ Community/ Settings/
├── Components/    (DesignSystem, ModernComponents [legacy wrappers], CoachMarkOverlay; Touchline/ = TQ* design-system components)
└── Utilities/     (AppLogger, HapticManager, NetworkManager)
```

## Key Files
| File | Purpose |
|------|---------|
| `App/TechnIQApp.swift` | App entry, Firebase/Google Sign-In init |
| `App/ContentView.swift` | Root nav, auth routing, cloud restore |
| `Components/DesignSystem.swift` | Touchline tokens (surfaces/pitch/grass/cone, condensed display type, radii, spacing, tab symbols) |
| `Components/Touchline/TQ*.swift` | Touchline components — screens are composed only from these (see table below) |
| `Components/ModernComponents.swift` | Legacy layer: ModernButton/ModernSegmentControl wrap TQButton/TQSegment; flat ModernCard/ModernTextField/StatCard kept for out-of-scope screens |
| `App/TQDemoSeed.swift` | DEBUG demo fixture + `-TQScreen` hosts for screenshot/UI-test runs |
| `scripts/add_to_pbxproj.py` | Registers new Swift files in project.pbxproj (not a synchronized folder): `<group> <file>`, `--tests`, `--uitests`, `--remove` |
| `Services/CoreDataManager.swift` | Core Data stack, exercise CRUD |
| `Services/YouTubeService.swift` | YouTube video data, caching, smart recommendations |
| `Services/CoreDataFetchRequests.swift` | Dynamic description generation helpers |
| `Views/Exercises/TemplateExerciseLibrary.swift` | 45+ exercise templates with fuzzy matching |
| `Models/TrainingPlanModels.swift` | UI models, SessionType enum (incl. warmup/cooldown) |

## Touchline Design System (Components/Touchline/)
Every in-scope screen is built only from these; add a variant to a TQ component rather than styling ad hoc. One pitch-green surface and one grass button per screen; no shadows or gradients (the sign-in header fade is the one exception).
| Component | Use |
|-----------|-----|
| TQPitchMarkings / TQPitchCard / TQHeroCard | Chalk-line pitch surfaces (hero, strip, pinned, card, fullscreen) |
| TQButton (+TQIconButton, TQTextLink, TQPressStyle) | primary grass / inverse chalk / raised / ghost / destructive; sizes regular, compact, auth |
| TQRow, TQRowList, TQIndexRow, TQStepRow, TQOptionRow | Flat rows with tile/index leading, meta/badge/chevron/heart/saves trailing; onboarding option rows |
| TQText (TQEyebrow, TQDisplayTitle, TQFigureRow, TQMeta, TQBody, TQGroupHeader, TQSectionHeader, TQFooterLine) | Condensed display type; `TQDisplayTitle` with `\n` stacks lines tight |
| TQControls (TQSegment, TQChip, TQChipRow, TQBadge, TQTile, TQStepper, TQProgressBar) | Segments, chips, level/count/status badges, 42 pt tiles |
| TQStatRail, TQWeekStrip, TQScheduleGrid, TQLevelBar, TQClock | Figures rail, week/plan grids, animated level bar, session clock |
| TQHeaders (TQScreenTitle, TQNavBar, TQBackButton, TQIconAction, TQScreen, TQAvatarCircle) | Screen chrome (native nav bars are hidden) |
| TQSearchField, TQFormField, TQBanner, TQSkeleton, TQTabBar, TQDiagram, TQAppMark | Inputs, banners, loading, tab bar, drill diagram surface, app mark |
| TQGallery (DEBUG) | `-TQGallery [-TQGalleryPage n] [-TQGallerySnapshot]` renders every component for eyeballing |

**Debug launch arguments (DEBUG builds):** `-TQLocalUser` (signed-in with a fixed local UID, no Firebase auth), `-TQSeedDemo` (creates the player if needed; kit #9, streak, XP, 8-week plan, sessions, match, community drills), `-TQTab n`, `-TQHomeState offline|loading|empty`, `-TQRoute planDetail|matchHistory|coachDrills` (Home) or `drill` (Train), `-TQDrillPhase generating|failed`, `-TQScreen signIn|onboarding`.
**UI tests:** `TechnIQUITests/TouchlineHomeUITests.swift`, `TouchlineScreensUITests.swift`, `TechnIQUITests.swift` launch with `-TQLocalUser -TQSeedDemo` so they run on a fresh simulator (screenshots land in the runner's tmp `touchlineshots/`). `WalkthroughUITests` needs a real login and is not run in CI.
**Pure logic for tests:** `Models/SharedDrillRanking.swift` (drill of the week, chips), `Models/OnboardingMapping.swift` (answers → plan inputs, age/kit validation), `Views/Dashboard/HomeWeekModel.swift`, `Models/DrillContent.swift`.

## Development Workflow

1. **Plan first** — read relevant files, create plan in `tasks/todo.md`, wait for approval
2. **Implement** — one task at a time, build after each change, minimal targeted changes
3. **Code quality** — see `.claude/rules/` for Swift, Core Data, Firebase rules; run `swiftlint`
4. **Build** — `/build` to build and check errors
5. **Git** — `/commit` to commit & push. Stage specific files only.

## View Structure
| Area | Key Views |
|------|-----------|
| Auth | AuthenticationView (SignInLandingView + EmailAuthView), UnifiedOnboardingView (5 decision steps → plan gen → OnboardingPaywallView) |
| Dashboard | DashboardView (Home; HomeWeekModel), CoachDrillsView, TrainHubView, PlayerProgressView |
| Training Plans | AITrainingPlanGeneratorView, TrainingPlansListView, TrainingPlanDetailView, PlanEditorView, DayEditorView |
| Sessions | ActiveTrainingView (full-screen pitch + TQDrillSheet), SessionCompleteView, TodaysTrainingView, NewSessionView, SessionHistoryView, SessionCalendarView |
| Exercises | ExerciseLibraryView (Train tab), ExerciseDetailView, CustomDrillGeneratorView, DrillDiagramView (+TQDiagram), QuickDrillSheet, SharedDrillDetailView |
| Matches | MatchLogView, MatchHistoryView, SeasonManagementView |
| Avatar | AvatarCustomizationView, ProgrammaticAvatarView, ShopView |
| Analytics | SkillTrendChartView, CalendarHeatMapView, InsightsEngine |
| Community | CommunityView (Feed / Drills / Leaderboard), DrillMarketplaceView (drill of the week) |
| Settings | EnhancedProfileView (You tab), SettingsView, EditProfileView, SharePlanView |

## Deferred / Outstanding
- API key rotation (keys in functions/.env.yaml need revoking) — USER ACTION
- Push/PR feature/app-store-readiness-v2 branch (local only) — USER ACTION
- Localization (English only)
- iPad-adaptive layout (device family is iPhone-only for v1.0)
- Incremental sync (currently full-sync on each cycle)
- Drill-gen spatial-sanity validator (positional-drill geometry variance; next milestone w/ drill animation)

Recently completed: App icon (1024px, compliant), SDK privacy bump (firebase 11.15.0, GoogleSignIn 8.0.0), VoiceOver a11y pass (15 views), drill-gen quality push (shot targets, skill tags, duration, synthesized instructions, geometry prompt rules), Sign in with Apple, in-app account deletion, SwiftLint + CI.
