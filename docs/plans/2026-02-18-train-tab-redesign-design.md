# Train Tab Redesign — Exercise-First with Hero AI CTA

## Problem
AI drill generation is TechnIQ's key selling point but is buried 2 taps deep (Train → Exercises tab → small AI button). Default Train view shows session history, not the core value prop. Double segment controls (Sessions/Exercises + List/Calendar) add unnecessary complexity.

## Solution: "Exercise Hub" (Approach A)
Replace segmented Train tab with a single scrollable exercise-focused view. AI drill creation gets a hero card at the very top. Session history moves to a nav bar button.

## Layout

```
┌─────────────────────────────┐
│  Train              📅 (nav)│  nav title + calendar icon → pushes SessionHistoryView
├─────────────────────────────┤
│ ┌─────────────────────────┐ │
│ │  ✨ Create AI Drill     │ │  Hero card, gradient bg
│ │  Personalized drill in  │ │
│ │  seconds                │ │
│ │  [Generate Drill →]     │ │
│ └─────────────────────────┘ │
│                             │
│ 🔍 Search exercises...     │  Search bar
│ [AI] [Manual] [YouTube]    │  Compact action buttons
│                             │
│ ⭐ Recommended for You     │  Horizontal scroll sections
│ 🤖 AI Custom Drills        │  (same as ExerciseLibraryView)
│ ❤️ Favorites               │
│ ⚽ Technical                │
│ 💪 Physical                │
│ 🧠 Tactical                │
└─────────────────────────────┘
```

## Hero AI Card
- Background: `LinearGradient` — `primaryGreen.opacity(0.15)` → `primaryGreen.opacity(0.05)`
- Icon: `sparkles` SF Symbol
- Title: "Create AI Drill" (bold)
- Subtitle: "Get a personalized drill tailored to your weaknesses"
- CTA: `ModernButton` primary style — opens `CustomDrillGeneratorView` sheet
- Paywall: checks `subscriptionManager.canUseCustomDrill()` before opening

## Navigation
- Title: "Train" (inline)
- Right toolbar: calendar icon (`calendar` SF Symbol, `primaryGreen`) → pushes `SessionHistoryView`
- `SessionHistoryView` unchanged internally (keeps List/Calendar toggle)

## Files Changed

| File | Change |
|------|--------|
| `TrainHubView.swift` | Major rewrite — remove segment control, inline exercise content with hero card, add nav bar calendar button |
| `ExerciseLibraryView.swift` | Minor refactor — remove own `NavigationView` wrapper and `simpleHeader` since TrainHubView provides nav context |
| `SessionHistoryView.swift` | No changes |

No new files.

## Architecture
- `TrainHubView` fetches Player via `@FetchRequest`, passes to exercise content + drill generator
- All services (CustomDrillService, SubscriptionManager, CoreDataManager) accessed same as before
- ExerciseLibraryView's `NavigationView` removed; body content extracted/inlined into TrainHubView's nav stack

## Risk
- `ExerciseLibraryView` currently wraps its own `NavigationView`. Removing it means sheets and navigation must work within TrainHubView's stack. May need to extract ScrollView body into a subview.

## Unresolved Questions
None.
