# Onboarding Overhaul Design

## Problem
Three overlapping flows (sign-up config, EnhancedOnboarding, legacy Onboarding) with redundant data collection, wasted sign-up data, and no guided first experience after onboarding.

## Solution: Unified Linear Flow

### Flow
```
Auth Screen (simplified sign-up — creds only)
  ↓ on auth success, no existing Player
Step 1: Welcome (mascot intro, feature highlights)
Step 2: Your Goal (training goal + frequency)
Step 3: About You (name, age, experience level, years playing)
Step 4: Soccer Profile (position, playing style, dominant foot)
Step 5: Plan Generation (loading → celebration → dashboard)
```

### Data Collection

| Step | Fields | Required | Defaults |
|------|--------|----------|----------|
| 2: Goal | goal, frequency | No (have defaults) | "Improve Skills", "3-4x per week" |
| 3: About You | name, age, experienceLevel, yearsPlaying | Name required | age=16, Beginner, 2 years |
| 4: Soccer Profile | position, playingStyle, dominantFoot | No (have defaults) | Midfielder, Balanced, Right |

### Player Creation
Happens at end of Step 4 (before plan gen). Persists to Core Data:
- name, age, position, playingStyle, dominantFoot, experienceLevel, createdAt, firebaseUID
- Default exercises via createDefaultExercises(for:)
- Cloud sync fires after save

### Plan Generation (Step 5)
Calls existing `CloudMLService.shared.generateTrainingPlan()` with mapped params:
- duration: 4 weeks
- difficulty: experienceLevel mapping
- category: goal mapping (e.g., "Improve Skills" → "technical")
- targetRole: selectedPosition
- preferredDays: derived from frequency selection
- restDays: inverse of preferredDays

Loading UX: 3-phase animation with mascot. On success → save plan + celebrate + navigate to MainTabView. On failure → retry or skip.

### Sign-Up → Onboarding Data Passing
firstName/lastName from sign-up pre-fill the name field via UserDefaults keys (`onboarding_prefill_name`). Read once on appear, then cleared.

## File Changes

### Create
- `UnifiedOnboardingView.swift` — new 5-step onboarding view

### Modify
- `AuthenticationView.swift` — remove modernConfigurationStep, all soccer profile state vars from sign-up. Sign-up becomes single-step creds only. Write prefill name to UserDefaults.
- `ContentView.swift` — replace EnhancedOnboardingView with UnifiedOnboardingView
- `DashboardView.swift` — replace EnhancedOnboardingView sheet with UnifiedOnboardingView

### Delete
- `OnboardingView.swift` — dead code
- `EnhancedOnboardingView.swift` — replaced by UnifiedOnboardingView

### Unchanged
- CloudMLService.swift, TrainingPlanService.swift, CoreDataManager.swift
- Helper views (OnboardingFeatureRow, FrequencyChip, PositionButton, etc.) move into or are imported by UnifiedOnboardingView

## Unresolved Questions
None — all decisions made during brainstorming.
