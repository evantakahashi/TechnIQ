---
paths:
  - "TechnIQ/Services/Cloud*.swift"
  - "TechnIQ/Services/CustomDrill*.swift"
  - "functions/**"
---

# Firebase Patterns

- All Firebase-facing services must use `@MainActor` (CloudMLService, CloudDataService, CloudSyncManager, CustomDrillService)
- Retry with exponential backoff on ALL Firebase Functions HTTP calls
- All 4 endpoints in `functions/main.py` require Firebase Auth in production
- `ALLOW_UNAUTHENTICATED=true` env var is for local testing ONLY — never deploy with it
- CloudSyncManager auto-syncs every 5 min, throttled to 30-sec minimum between syncs
- Network monitoring via NWPathMonitor in CloudDataService
- Test that Firebase calls handle auth failures gracefully
