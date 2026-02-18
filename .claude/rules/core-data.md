---
paths:
  - "TechnIQ/**/*.swift"
  - "TechnIQ/**/*.xcdatamodeld/**"
---

# Core Data Conventions

- **Codegen**: category+class for TrainingPlan/PlanWeek/PlanDay/PlanSession; class codegen for everything else
- **Migrations**: Must be additive only (lightweight migration with auto-inferred mapping)
- **Context**: `CoreDataManager.shared.context` is the single viewContext source
- **Error handling**: `CoreDataManager.persistentStoreError` published for UI — never fatalError on store failure
- **CloudRestoreService**: Takes no context param — uses `CoreDataManager.shared.context` internally
- **Progression**: Training plans are completion-based (`getCurrentDay()` walks hierarchy), NOT calendar-based. Rest days auto-complete.

## Entity Hierarchy
```
Player (root) → exercises, sessions, trainingPlans, avatarConfiguration,
  ownedAvatarItems, stats, playerProfile, playerGoals, matches, seasons,
  recommendationFeedback
Independent: CloudSyncStatus, MLRecommendation
```
