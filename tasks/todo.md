# App Store Readiness Fixes

## Parallel Workstreams (no file conflicts)

### Stream 1: View Crash Fixes
- [ ] NewSessionView.swift: Replace force unwraps on exercise.id (lines 368,369,528,550)
- [ ] PlayerProgressView.swift: Guard unwrap session dates (line 474)
- [ ] SessionCalendarView.swift: Safe optional access (lines 543,547,725,729)
- [ ] CalendarHeatMapView.swift: Fix double unwrap (lines 154,161)
- [ ] TrainingPlanModels.swift: Use flatMap for DayOfWeek (line 273)
- [ ] InsightsEngine.swift: Guard unwrap dates.last (line 193)

### Stream 2: Core Service Crash + Concurrency
- [ ] CoreDataManager.swift: Replace fatalError() at lines 84,92 with graceful recovery
- [ ] CloudSyncManager.swift: Add @MainActor, fix timer in deinit
- [ ] CloudRestoreService.swift: Fix unsafe context parameter

### Stream 3: Auth + Security + Firebase
- [ ] AuthenticationManager.swift: Fix deprecated UIApplication.windows (line 118)
- [ ] AuthenticationManager.swift: Fix auth state race (lines 29-36)
- [ ] functions/main.py: Make auth required in production
- [ ] firestore.rules: Add subcollection rules under /users/{userId}

### Stream 4: App Store Compliance Files
- [ ] Create PrivacyInfo.xcprivacy
- [ ] Create TechnIQ.entitlements
- [ ] Update Info.plist with privacy descriptions + UIRequiredDeviceCapabilities

### Stream 5: Performance + Resilience
- [ ] ActiveSessionManager.swift: Fix array bounds (lines 195,202,203,274)
- [ ] CloudMLService.swift: Fix array bounds (line 408), add retry logic
- [ ] CustomDrillService.swift: Add timeout config
- [ ] CloudDataService.swift: Fix network monitor callback

### Deferred (needs user action or separate planning)
- Sign in with Apple (complex integration, needs Apple Developer setup)
- App icon (needs design assets from user)
- API key revocation (manual action in Google/OpenAI consoles)
- Print → AppLogger replacement (268 occurrences, separate pass)
- Localization
- Certificate pinning
- Full incremental sync redesign
- Accessibility labels

## Unresolved Questions
- Sign in with Apple: implement now or defer?
- App icon: do you have assets?
- API keys: have they been revoked yet?
- Print→AppLogger: tackle in this pass or separate?
