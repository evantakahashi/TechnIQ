# TechnIQ Development Guidelines

## About TechnIQ
AI-powered soccer training app for iOS. Personalized programs, smart drills, progress analytics.

**Tech Stack:** SwiftUI, Core Data, Firebase (Auth, Firestore, Functions), Google Sign-In, Vertex AI, YouTube Data API v3
**Targets:** iOS 17.0+, iPhone & iPad, arm64

---

## Quick Commands
- **Build:** `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build`
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

### Services (all singletons via `.shared`)
| Service | @MainActor | Responsibility |
|---------|------------|----------------|
| CoreDataManager | No | Core Data stack, persistent store, migrations |
| AuthenticationManager | No | Firebase Auth (email, Google, anonymous) |
| CloudMLService | Yes | ML recommendations, YouTube recs via Firebase Functions |
| CloudDataService | Yes | Firestore sync, network monitoring (NWPathMonitor) |
| CloudSyncManager | Yes | Bi-directional Core Data ↔ Firestore, 5-min auto-sync |
| CloudRestoreService | Yes | Cloud data restoration on startup |
| TrainingPlanService | No | Plan CRUD, AI generation, completion-based progression |
| CustomDrillService | Yes | AI drill generation via Firebase Functions |
| YouTubeAPIService | No | YouTube Data API v3, rate limited (100 req/100s) |
| XPService | No | XP calc, level system (1-50), 10-tier career path |
| CoinService | No | Coin economy, earning events, transactions |
| AchievementService | No | 30 achievements, unlock checking, XP rewards |
| AvatarService | No | Avatar configuration, item inventory |
| MatchService | No | Match CRUD, season management |
| ActiveSessionManager | No | Live training session state machine |
| InsightsEngine | No | Analytics calculations, trend analysis |
| AppLogger | No | OSLog-based logging with 6 categories |

### Firebase Functions (functions/main.py)
4 endpoints: `get_youtube_recommendations`, `generate_custom_drill`, `get_advanced_recommendations`, `generate_training_plan`
All require Firebase Auth in production.

---

## Key Files
| File | Purpose |
|------|---------|
| `TechnIQApp.swift` | App entry, Firebase/Google Sign-In init |
| `ContentView.swift` | Root nav, auth routing, cloud restore |
| `DesignSystem.swift` | Design tokens (colors, typography, spacing) |
| `ModernComponents.swift` | Reusable UI (ModernCard, ModernButton, etc.) |
| `CoreDataManager.swift` | Core Data stack, `persistentStoreError` for graceful failure |
| `TemplateExerciseLibrary.swift` | 45+ exercise templates with fuzzy matching |
| `TrainingPlanModels.swift` | UI models, SessionType enum (incl. warmup/cooldown) |

## Development Workflow

1. **Plan first** — read relevant files, create plan in `tasks/todo.md`, wait for approval
2. **Implement** — one task at a time, build after each change, minimal targeted changes
3. **Code quality** — see `.claude/rules/` for Swift, Core Data, Firebase rules
4. **Build** — `/build` to build and check errors
5. **Git** — `/commit` to commit & push. Stage specific files only.

## View Structure (55 views)
| Area | Key Views |
|------|-----------|
| Auth | AuthenticationView, EnhancedOnboardingView |
| Dashboard | DashboardView, TrainHubView, PlayerProgressView |
| Training Plans | AITrainingPlanGeneratorView, ActivePlanView, TrainingPlansListView, TrainingPlanDetailView, PlanEditorView, DayEditorView |
| Sessions | TodaysTrainingView, ActiveTrainingView, NewSessionView, SessionHistoryView, SessionCalendarView |
| Exercises | ExerciseLibraryView, ExerciseDetailView, CustomDrillGeneratorView, DrillDiagramView, QuickDrillSheet |
| Matches | MatchLogView, MatchHistoryView, SeasonManagementView |
| Avatar | AvatarCustomizationView, ProgrammaticAvatarView, ShopView |
| Analytics | SkillTrendChartView, CalendarHeatMapView, InsightsEngine |
| Settings | SettingsView, EditProfileView, SharePlanView |

## Deferred / Outstanding
- Sign in with Apple (entitlement added, implementation pending)
- App icon (needs design assets)
- API key rotation (keys in functions/.env.yaml need revoking)
- Accessibility labels (zero currently)
- Localization (English only)
- Incremental sync (currently full-sync on each cycle)
