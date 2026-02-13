# Adaptive AI Coach — Design Document

**Date:** 2026-02-12
**Approach:** Part A (Smart Daily Coach) then Part B (Adaptive Training Plans)
**Goal:** Transform AI from generate-only to adaptive — recommendations drive action, plans adjust to performance

---

## 1. Architecture Overview

Two features, built in order:

**Part A — AI Daily Coach (Smart Recommendations)**
- New Firebase Function: `get_daily_coaching` — receives full player context, returns structured coaching response with focus area, reasoning, recommended drill, tips, and AI-powered insights
- New service: `AICoachService` (@MainActor singleton) — calls function on first daily open, caches in memory + UserDefaults
- New dashboard card: "Today's Focus" — AI reasoning + recommended drill with one-tap start
- PlayerProgress integration: AI insights prepend to rule-based InsightsEngine results

**Part B — Adaptive Training Plans**
- New Firebase Function: `get_plan_adaptation` — receives plan structure + week's session data, returns proposed modifications
- Weekly check-in UI: after completing a plan week, AI presents review + proposed adjustments
- Player approves/rejects, plan updates in Core Data

---

## 2. AI Daily Coach — Data Model & Service

### AICoachService

```swift
@MainActor
class AICoachService: ObservableObject {
    static let shared = AICoachService()

    @Published var dailyCoaching: DailyCoaching?
    @Published var aiInsights: [TrainingInsight] = []
    @Published var isLoading: Bool = false
    @Published var error: String?

    private var lastFetchDate: Date?

    func fetchDailyCoaching(for player: Player) async
    func getCachedCoaching() -> DailyCoaching?
}
```

### Response Models

```swift
struct DailyCoaching: Codable {
    let focusArea: String          // "Passing" / "Dribbling" / etc.
    let reasoning: String          // "Your passing ratings dropped 18% over 2 weeks..."
    let recommendedDrill: RecommendedDrill
    let additionalTips: [String]   // 1-3 short coaching tips
    let streakMessage: String?     // Optional motivational nudge
    let fetchDate: Date
}

struct RecommendedDrill: Codable {
    let name: String
    let description: String
    let category: String
    let difficulty: Int
    let duration: Int              // minutes
    let steps: [String]
    let equipment: [String]
    let targetSkills: [String]
    let isFromLibrary: Bool        // true = matched existing exercise
    let libraryExerciseID: String? // UUID of matched Exercise if from library
}
```

### Cache Strategy

- First daily open: call Firebase Function, cache as JSON in UserDefaults
- Subsequent opens same day: return cached DailyCoaching
- Day comparison via `Calendar.isDateInToday(lastFetchDate)`
- Network fail: show yesterday's coaching with "Updated yesterday" label
- No Core Data entity — ephemeral daily data

### Player Context Sent to AI

Same rich context pattern as CustomDrillService.buildPlayerProfile():
- Profile (age, position, experience, style, dominant foot)
- Goals + weaknesses (from onboarding)
- Last 10 sessions: per-exercise skill tags + ratings + duration
- Category balance (% technical/physical/tactical)
- Current plan progress (if active plan)
- Streak info + days since last session

---

## 3. Firebase Function — `get_daily_coaching`

### Endpoint

`https://us-central1-techniq-b9a27.cloudfunctions.net/get_daily_coaching`

Auth: Required (Firebase Auth token), same pattern as existing endpoints.

### Request Payload

```json
{
  "player_profile": {
    "age": 16, "position": "striker", "experience": "intermediate",
    "style": "technical", "dominant_foot": "right",
    "goals": ["improve finishing", "better first touch"],
    "weaknesses": ["weak foot", "heading"]
  },
  "recent_sessions": [
    {
      "date": "2026-02-10",
      "duration_minutes": 45,
      "overall_rating": 4,
      "exercises": [
        { "name": "Cone Weaving", "category": "technical", "skills": ["dribbling"], "rating": 3, "duration": 10 }
      ]
    }
  ],
  "category_balance": { "technical": 55, "physical": 30, "tactical": 15 },
  "active_plan": { "name": "4-Week Striker Plan", "week": 2, "progress": 0.35 },
  "streak_days": 5,
  "days_since_last_session": 0,
  "total_sessions": 34
}
```

### AI Prompt Strategy

Single Vertex AI/Gemini call with structured output. System prompt:
1. Analyze skill trends from session ratings — identify weakest/declining areas
2. Consider category balance — flag if imbalanced
3. Factor in active plan context — complement, don't contradict
4. Pick ONE focus area with data-backed reasoning (2 sentences max)
5. Generate or select a drill matching focus area + player level
6. Generate 1-3 AI insights (celebration, recommendation, or warning)
7. Return structured JSON matching DailyCoaching + insights schema

### Response

```json
{
  "focus_area": "Passing",
  "reasoning": "Your passing ratings averaged 2.8 over the last 5 sessions, down from 3.6 two weeks ago. Let's reverse that trend.",
  "recommended_drill": {
    "name": "Triangle Passing Circuit",
    "description": "...",
    "category": "technical",
    "difficulty": 3,
    "duration": 15,
    "steps": ["Set up 3 cones...", "..."],
    "equipment": ["3 cones", "1 ball"],
    "target_skills": ["short passing", "first touch", "movement"],
    "is_from_library": false
  },
  "additional_tips": [
    "Focus on using the inside of your foot for short passes",
    "Try to receive the ball on the half-turn"
  ],
  "streak_message": "5 days strong — keep the momentum going!",
  "insights": [
    {
      "title": "Dribbling Breakthrough",
      "description": "Your dribbling ratings improved 22% this month. Your cone work is paying off.",
      "type": "celebration",
      "priority": 10
    },
    {
      "title": "Tactical Gap",
      "description": "Only 15% of your training is tactical. Positioning drills would complement your technical work.",
      "type": "recommendation",
      "priority": 9,
      "actionable": "Try a tactical drill this week"
    }
  ]
}
```

### Error/Fallback

- Network fail → show cached yesterday's coaching
- Auth fail → skip coaching card, show regular dashboard
- Timeout: 30s (lighter than drill gen's 90s)
- Retry: 1 retry with 2s backoff

---

## 4. Dashboard "Today's Focus" Card

### Placement

In DashboardView between `modernStatsOverview` and `continuePlanCard`.

### Layout

```
┌─ emerald accent edge ──────────────────────────┐
│  🎯  TODAY'S FOCUS                              │
│                                                  │
│  "Your passing ratings dropped 18% over 2 weeks. │
│   Let's reverse that trend."                     │
│                                                  │
│  ┌─ surfaceOverlay ──────────────────────┐      │
│  │  △ Triangle Passing Circuit           │      │
│  │  Technical · ★★★ · 15 min            │      │
│  │  [short passing] [first touch]        │      │
│  └───────────────────────────────────────┘      │
│                                                  │
│  💡 Focus on inside-of-foot for short passes     │
│                                                  │
│  [ Start Drill ─────────── primary button ]      │
│  [ Browse Library ──────── ghost button   ]      │
└──────────────────────────────────────────────────┘
```

### Behavior

- **Start Drill** → If `isFromLibrary` + `libraryExerciseID`, fetch Exercise and launch ActiveTrainingView. If AI-generated, create new Exercise entity then launch.
- **Browse Library** → ExerciseLibraryView pre-filtered by focusArea category
- **Loading:** Skeleton shimmer card
- **Error/no-data:** Card hidden entirely
- **Stale cache:** "Updated yesterday" label in header

### Accessibility

- Card: `.a11y(label: "Today's focus: \(focusArea). \(reasoning)", trait: .isStaticText)`
- Start: `.a11y(label: "Start \(drill.name) drill", hint: "\(drill.duration) minute \(drill.category) drill", trait: .isButton)`

---

## 5. AI-Powered Insights in PlayerProgressView

### Integration

- `AICoachService` exposes `@Published var aiInsights: [TrainingInsight]` — mapped from response `insights` array into existing `TrainingInsight` model
- `PlayerProgressView.loadProgressData()` checks `AICoachService.shared.aiInsights` first
- AI insights get priority 9-10 (sort above rule-based which max at 9)
- Deduplication by InsightType — if AI covers `.recommendation`, skip rule-based recommendations
- No AI insights cached → 100% rule-based as today

### No Breaking Changes

- `InsightsEngine` untouched — still generates its full list as fallback
- `TrainingInsight` model unchanged — AI insights map into same struct
- `PlayerProgressView` just prepends AI insights before rule-based ones

---

## 6. Adaptive Training Plans — Weekly Check-In

### Trigger

When player completes last session of a plan week (detected in TrainingPlanService when currentWeek advances):

```swift
@Published var weeklyCheckInAvailable: Bool = false
@Published var completedWeekNumber: Int = 0
```

### Check-In Flow

1. Player completes final day → SessionCompleteView shows "Week X Complete — See AI Review"
2. Tap opens WeeklyCheckInView (sheet)
3. Sheet loads while calling `get_plan_adaptation`
4. AI response renders:

```
┌─ gold accent edge ─────────────────────────────┐
│  📊  WEEK 2 REVIEW                              │
│                                                  │
│  "Strong week — you completed 4/5 sessions with  │
│   avg rating 3.8. Dribbling improved but passing  │
│   stayed flat."                                  │
│                                                  │
│  PROPOSED CHANGES FOR WEEK 3:                    │
│                                                  │
│  ✓  Increase passing drill frequency (2→3/week)  │
│  ✓  Bump dribbling difficulty from 3→4           │
│  ✗  Remove extra rest day (you're consistent)    │
│                                                  │
│  [ Apply Changes ──── primary button ]           │
│  [ Keep Original Plan ── ghost button ]          │
└──────────────────────────────────────────────────┘
```

5. **Apply Changes** → modifies next week's PlanDay/PlanSession in Core Data
6. **Keep Original** → dismisses sheet, plan unchanged

### Firebase Function: `get_plan_adaptation`

**Endpoint:** `https://us-central1-techniq-b9a27.cloudfunctions.net/get_plan_adaptation`

**Auth:** Required.

**Request:** Current plan structure (weeks/days/sessions), completed week's session data (per-exercise ratings, durations, notes), player profile.

**Response:**
```json
{
  "summary": "Strong week — you completed 4/5 sessions...",
  "adaptations": [
    {
      "type": "add_session",
      "day": 2,
      "description": "Add passing drill",
      "drill": { "name": "Wall Pass Combos", "category": "technical", "difficulty": 3 }
    },
    {
      "type": "modify_difficulty",
      "day": 3,
      "session_index": 0,
      "old_difficulty": 3,
      "new_difficulty": 4,
      "description": "Bump dribbling difficulty"
    },
    {
      "type": "remove_session",
      "day": 5,
      "session_index": 1,
      "description": "Remove extra rest day"
    }
  ]
}
```

### Applying Adaptations

```swift
// TrainingPlanService
func applyAdaptations(_ adaptations: [PlanAdaptation], to plan: TrainingPlan, week: Int) throws
```

Operates on next week's PlanWeek → PlanDay → PlanSession entities. Additive patterns — no schema change needed.

### Edge Cases

- Skip check-in → no changes, reminder card on dashboard next open
- Low session count that week → AI notes low data, lighter adjustments
- No active plan → feature hidden
- Network fail → "Couldn't reach AI coach. Retry or keep current plan."

---

## 7. New & Modified Files

### New Files (4)

| File | Purpose |
|------|---------|
| `AICoachService.swift` | @MainActor singleton. Daily coaching fetch, UserDefaults cache, AI insights. 30s timeout, 1 retry. |
| `TodaysFocusCard.swift` | Dashboard card — reasoning, drill preview, Start/Browse, loading/stale states |
| `WeeklyCheckInView.swift` | Sheet — week review, adaptation list, Apply/Keep buttons |
| `functions/main.py` additions | 2 new endpoints: `get_daily_coaching`, `get_plan_adaptation` |

### Modified Files (5)

| File | Change |
|------|--------|
| `DashboardView.swift` | Add TodaysFocusCard between stats and continue-plan. Trigger fetchDailyCoaching in onAppear. |
| `PlayerProgressView.swift` | Prepend AI insights from AICoachService before rule-based InsightsEngine results. |
| `SessionCompleteView.swift` | Show "Week X Complete — See AI Review" card when weeklyCheckInAvailable. Present WeeklyCheckInView. |
| `TrainingPlanService.swift` | Add weeklyCheckInAvailable property. Add applyAdaptations method. Detect week completion. |
| `Xcode project file` | Add new Swift files to build target |

### Unchanged

- InsightsEngine.swift — untouched, fallback role
- CustomDrillService.swift — separate concern
- CloudMLService.swift — recommendations stay separate
- Core Data schema — no new entities or attributes

---

## 8. Unresolved Questions

1. `get_daily_coaching` and `get_plan_adaptation` — separate functions in main.py or separate deployments?
2. Library drill matching — should AI match against player's existing Exercise library, or always generate fresh?
3. Rate limit on `get_daily_coaching` — 1/day server-side or just client cache?
