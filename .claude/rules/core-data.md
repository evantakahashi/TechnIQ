---
paths:
  - "TechnIQ/**/*.swift"
  - "TechnIQ/**/*.xcdatamodeld/**"
---

# Core Data Conventions

- **Codegen**: category+class for TrainingPlan/PlanWeek/PlanDay/PlanSession; class codegen for everything else
- **Migrations**: The model is versioned (`DataModel` = v1 as shipped, `DataModel 2` = current). Never edit a shipped version; add a new version for any change that must ship after it, keep changes within lightweight inferred migration (add/remove/optional), and extend `ModelMigrationTests`
- **Context**: `CoreDataManager.shared.context` is the single viewContext source
- **Error handling**: `CoreDataManager.persistentStoreError` published for UI — never fatalError on store failure
- **CloudRestoreService**: Takes no context param — uses `CoreDataManager.shared.context` internally
- **Progression**: Training plans are completion-based (`getCurrentDay()` walks hierarchy), NOT calendar-based. Rest days auto-complete.

## Entity Hierarchy
```
Player (root) → exercises, sessions, trainingPlans, avatarConfiguration,
  stats, playerProfile, playerGoals, matches, seasons,
  recommendationFeedback, cameraRuns, benchmarks
Independent: CloudSyncStatus, MLRecommendation
```
