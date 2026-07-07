# TechnIQ Development Guidelines

## About TechnIQ
AI-powered soccer training app for iOS. Personalized programs, smart drills, progress analytics.

**Tech Stack:** SwiftUI, Core Data, Firebase (Auth, Firestore, Functions), Google Sign-In, Sign in with Apple, StoreKit, Anthropic (via Functions), YouTube Data API v3
**Targets:** iOS 17.0+, iPhone (v1.0 is iPhone-only; `TARGETED_DEVICE_FAMILY = 1`), arm64

---

## Quick Commands
All xcodebuild invocations (build/test/archive) MUST append `SWIFT_ENABLE_EXPLICIT_MODULES=NO CLANG_ENABLE_EXPLICIT_MODULES=NO` — Xcode 26's explicit modules can't precompile FirebaseFirestoreInternal, and project-level settings don't reach SPM targets. GUI Product>Archive will fail; archive from CLI.
- **Build:** `xcodebuild -scheme TechnIQ -destination 'platform=iOS Simulator,name=iPhone 15 Pro' SWIFT_ENABLE_EXPLICIT_MODULES=NO CLANG_ENABLE_EXPLICIT_MODULES=NO build`
- **Test (unit):** `xcodebuild -scheme TechnIQ -destination 'platform=iOS Simulator,name=iPhone 15 Pro' -only-testing:TechnIQTests SWIFT_ENABLE_EXPLICIT_MODULES=NO CLANG_ENABLE_EXPLICIT_MODULES=NO test`
- **Lint:** `swiftlint` (config `.swiftlint.yml`; ~140 warnings / 0 errors today, not yet `--strict`)
- **CI:** `.github/workflows/ci.yml` — SwiftLint + build + unit tests on PR / push to main
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
├── Components/    (DesignSystem, ModernComponents, CoachMarkOverlay, etc.)
└── Utilities/     (AppLogger, HapticManager, NetworkManager)
```

## Key Files
| File | Purpose |
|------|---------|
| `App/TechnIQApp.swift` | App entry, Firebase/Google Sign-In init |
| `App/ContentView.swift` | Root nav, auth routing, cloud restore |
| `Components/DesignSystem.swift` | Design tokens (colors, typography, spacing) |
| `Components/ModernComponents.swift` | Reusable UI (ModernCard, ModernButton, etc.) |
| `Services/CoreDataManager.swift` | Core Data stack, exercise CRUD |
| `Services/YouTubeService.swift` | YouTube video data, caching, smart recommendations |
| `Services/CoreDataFetchRequests.swift` | Dynamic description generation helpers |
| `Views/Exercises/TemplateExerciseLibrary.swift` | 45+ exercise templates with fuzzy matching |
| `Models/TrainingPlanModels.swift` | UI models, SessionType enum (incl. warmup/cooldown) |

## Development Workflow

1. **Plan first** — read relevant files, create plan in `tasks/todo.md`, wait for approval
2. **Implement** — one task at a time, build after each change, minimal targeted changes
3. **Code quality** — see `.claude/rules/` for Swift, Core Data, Firebase rules; run `swiftlint`
4. **Build** — `/build` to build and check errors
5. **Git** — `/commit` to commit & push. Stage specific files only.

## View Structure
| Area | Key Views |
|------|-----------|
| Auth | AuthenticationView, UnifiedOnboardingView, EnhancedOnboardingView |
| Dashboard | DashboardView, TrainHubView, PlayerProgressView |
| Training Plans | AITrainingPlanGeneratorView, TrainingPlansListView, TrainingPlanDetailView, PlanEditorView, DayEditorView |
| Sessions | TodaysTrainingView, ActiveTrainingView, NewSessionView, SessionHistoryView, SessionCalendarView |
| Exercises | ExerciseLibraryView, ExerciseDetailView, CustomDrillGeneratorView, DrillDiagramView, QuickDrillSheet |
| Matches | MatchLogView, MatchHistoryView, SeasonManagementView |
| Avatar | AvatarCustomizationView, ProgrammaticAvatarView, ShopView |
| Analytics | SkillTrendChartView, CalendarHeatMapView, InsightsEngine |
| Settings | SettingsView, EditProfileView, SharePlanView |

## Deferred / Outstanding
- App icon (1024px asset missing — archive/upload blocker)
- SDK privacy-manifest bump (firebase-ios-sdk 10.18 → 10.24+/11.x, GoogleSignIn 7.0 → 7.1+) required before App Store upload (ITMS-91053/91061)
- API key rotation (keys in functions/.env.yaml need revoking)
- Accessibility labels (near-zero currently)
- Localization (English only)
- iPad-adaptive layout (device family is iPhone-only for v1.0)
- Incremental sync (currently full-sync on each cycle)

Recently completed: Sign in with Apple (AuthenticationManager), in-app account deletion (Settings → `delete_account` function), SwiftLint config + CI, dead-view cleanup.
