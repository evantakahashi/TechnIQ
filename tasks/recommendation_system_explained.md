# TechnIQ Recommendation System - Complete Explanation

## Overview

The recommendation system analyzes a player's training history to suggest personalized exercises. It prioritizes drills based on recent performance, skill gaps, difficulty progression, and variety.

---

## How It Works (Step-by-Step)

### 1. User Opens Dashboard

When the user opens the Dashboard, the app calls:
```swift
loadSmartRecommendations(for: player)
```

This triggers the entire recommendation flow.

###  2. Training History Analysis

**File**: `CoreDataManager.swift` (lines 1674-1790)

The system first analyzes all training sessions:

```swift
func analyzeTrainingHistory(for player: Player) -> TrainingHistory
```

**What it tracks**:

**A. Time Windows**
- Last 3 days: Exercises to avoid recommending (just completed)
- Last 7 days: Very recent performance (for priority boost)
- Last 14 days: Recent performance (for priority boost)
- Last 30 sessions: Overall analysis

**B. Skill Metrics**
- `skillFrequency`: How often each skill is practiced
  - Example: `["Shooting": 5, "Passing": 12, "Dribbling": 3]`
- `skillPerformance`: Average rating (1-5 stars) for each skill
  - Example: `["Shooting": 4.2, "Passing": 2.8, "Dribbling": 3.5]`
- `recentSkillPerformance`: Last 14 days only
  - Example: `["Shooting": 2.3, "Passing": 3.1]`
- `veryRecentSkillPerformance`: Last 7 days only
  - Example: `["Shooting": 2.1]`

**C. Other Tracking**
- `categoryFrequency`: How often each category is practiced (Physical, Technical, Tactical)
- `recentExercises`: Set of exercise names done in last 3 days
- `poorPerformanceSkills`: Skills with < 3.0 stars in last 14 days

**Example Output**:
```swift
TrainingHistory(
    totalSessions: 15,
    skillFrequency: ["Shooting": 3, "Passing": 8, "Dribbling": 5],
    recentSkillPerformance: ["Shooting": 2.3],  // Poor recent performance!
    veryRecentSkillPerformance: ["Shooting": 2.1],  // Even worse last week
    recentExercises: ["Ball Control", "Sprint Training"],  // Done in last 3 days
    poorPerformanceSkills: ["Shooting"]  // < 3.0 stars recently
)
```

### 3. Identify Skill Gaps

**File**: `CoreDataManager.swift` (lines 1792-1805)

```swift
func identifySkillGaps(from history: TrainingHistory) -> [String]
```

**Logic**:
- Checks all 10 core skills: Ball Control, Passing, Shooting, Dribbling, Defending, Speed, Agility, Endurance, Vision, Decision Making
- Marks as "gap" if:
  - Practiced less than 2 times, OR
  - Average performance < 3.0 stars

**Example**:
```swift
// Input: Player has practiced Shooting 3 times with 2.8 avg rating
// Output: ["Shooting"] ← Identified as skill gap (performance < 3.0)
```

### 4. Generate Recommendations (4 Categories)

**File**: `CoreDataManager.swift` (lines 1570-1629)

The system generates 4 types of recommendations in priority order:

#### **Category 1: Skill Gap Recommendations** (Highest Priority)
**File**: `CoreDataManager.swift` (lines 2097-2188)

**What it does**:
1. For each skill gap (top 3)
2. Find exercises that target that skill
3. **Filter out**:
   - Already used in this recommendation batch
   - ✅ **Done in last 3 days** (new!)
4. Calculate confidence score

**Confidence Calculation** (lines 2127-2163):

```swift
// PRIORITY 1: Recent poor performance (last 14 days)
if skill performed < 3.0 stars in last 14 days:
    confidence = 82-90%  // 🔥 HIGHEST PRIORITY
    reasoning = "Your recent shooting sessions averaged 2.3/5 stars (46%)"

// PRIORITY 2: Very recent struggle (last 7 days)
else if skill performed < 3.5 stars in last 7 days:
    confidence = 75-84%  // ⚡ HIGH PRIORITY
    reasoning = "This past week, your shooting work showed room to grow (avg: 2.1/5)"

// PRIORITY 3: Completely neglected (never practiced)
else if frequency == 0 and totalSessions > 5:
    confidence = 85%
    reasoning = "Time to explore shooting - it's a gap in your training"

// PRIORITY 4: Not practiced in 2+ weeks
else if days since last practice > 14:
    confidence = 70-80%
    reasoning = "It's been 18 days since your last shooting session"

// PRIORITY 5: Overall poor performance
else if overall performance < 3.0:
    confidence = 65-75%
    reasoning = "Your shooting showed room for improvement (overall avg: 2.7/5)"

// PRIORITY 6: General gap
else:
    confidence = 55-65%
    reasoning = "Balance your training with some shooting work"

// Difficulty matching adjustment
playerLevel = Intermediate → Level 3
exerciseLevel = Level 3
if perfect match: +8%
if 1 level diff: +3%
if 2+ levels diff: -10%

// Final clamp: 40-90%
```

**Example Recommendation**:
```swift
DrillRecommendation(
    exercise: "Shooting Practice",
    reason: "Your recent shooting sessions averaged 2.3/5 stars (46%) - let's improve that together!",
    confidenceScore: 0.86,  // 86%
    priority: 1,  // Highest
    category: "Skill Gap"
)
```

#### **Category 2: Difficulty Progression** (Medium Priority)
**File**: `CoreDataManager.swift` (lines 2190-2260)

**What it does**:
1. Check if player is ready for harder exercises
2. If Level 1 mastered (4+ stars average) → Recommend Level 2
3. If Level 2 mastered → Recommend Level 3

**Confidence**: 60-72% based on readiness

**Example**:
```swift
// Player averages 4.2 stars on Level 1 exercises
→ Recommend Level 2 exercise with 68% confidence
reasoning = "Impressive! Your level 1 sessions are averaging 84% - ready for the next challenge?"
```

#### **Category 3: Variety Recommendations** (Low Priority)
**File**: `CoreDataManager.swift` (lines 2262-2330)

**What it does**:
1. Find underrepresented categories (Physical, Technical, Tactical)
2. Recommend exercises from those categories
3. Helps balance training

**Confidence**: 45-58%

**Example**:
```swift
// Player has done 10 Technical, 2 Physical, 8 Tactical
→ Recommend Physical exercise with 52% confidence
reasoning = "Your training is heavy on other areas - let's balance it out with physical work"
```

#### **Category 4: Success Pattern** (Medium Priority)
**File**: `CoreDataManager.swift` (lines 2332-2390)

**What it does**:
1. Find skills player excels at (4+ stars recent performance)
2. Recommend similar exercises to build on strengths

**Confidence**: 55-70%

**Example**:
```swift
// Player averages 4.5 stars on Passing exercises
→ Recommend advanced Passing drill with 65% confidence
reasoning = "Passing is clearly your strength (90% avg.) - let's make it legendary!"
```

### 5. Sort and Deduplicate

**File**: `CoreDataManager.swift` (lines 1616-1628)

```swift
// Sort by:
// 1. Priority (1 = highest)
// 2. Confidence score (higher = better)
recommendations
    .sorted { first, second in
        if first.priority != second.priority {
            return first.priority < second.priority  // Lower number = higher priority
        }
        return first.confidenceScore > second.confidenceScore
    }
    .prefix(5)  // Take top 5
```

**Example Final List**:
```
1. Shooting Practice - 86% (Priority 1, Skill Gap, Recent poor performance)
2. Passing Drill - 78% (Priority 1, Skill Gap, Never practiced)
3. Level 2 Ball Control - 68% (Priority 2, Difficulty Progression)
4. Advanced Passing - 65% (Priority 3, Success Pattern)
5. Speed Training - 52% (Priority 4, Variety)
```

### 6. Display on Dashboard

**File**: `DashboardView.swift` (lines 833-900)

Recommendations are displayed with:
- Exercise name
- Difficulty level (dots)
- Match percentage (confidence score × 100)
- Reasoning text (up to 3 lines, complete)

---

## Key Improvements Made

### **Before** (Original System)

**Problems**:
- ❌ Generic text: "Perfect! Level 1 drills are ideal for building your soccer foundation step b..."
- ❌ Inflated scores: 75-94% for everything
- ❌ No recency: Couldn't tell if skill performed poorly recently
- ❌ Could recommend just-completed drills
- ❌ No prioritization of recent struggles

### **After** (Improved System)

**Solutions**:
- ✅ **Specific text**: "Your recent shooting sessions averaged 2.3/5 stars (46%) - let's improve that together!"
- ✅ **Meaningful scores**: 40-90% range with clear tiers
- ✅ **Recency awareness**: Tracks 3-day, 7-day, and 14-day windows
- ✅ **Filters recent drills**: Won't recommend exercises done in last 3 days
- ✅ **Prioritizes recent poor performance**: 82-90% confidence for recent struggles

---

## Confidence Score Tiers (Quick Reference)

| Score | Meaning | Example |
|-------|---------|---------|
| **82-90%** | 🔥 Recent poor performance (last 14 days) | "Your recent shooting averaged 2.3/5" |
| **75-84%** | ⚡ Very recent struggle (last 7 days) | "This past week, shooting showed room to grow" |
| **70-85%** | Neglected skill or new player | "Passing hasn't appeared in your training yet" |
| **65-75%** | Moderately neglected | "It's been 18 days since last ball control session" |
| **60-72%** | Ready for progression | "Your level 1 mastery shows you're ready for advanced techniques" |
| **55-70%** | Build on strengths | "Dribbling is clearly your strength - let's make it legendary" |
| **45-58%** | Variety and balance | "Add some physical training to round out your skillset" |

---

## Example Scenario

**Player Profile**:
- Carson Yang, Intermediate level (maps to Level 3)
- 15 total training sessions
- Last session: 2 days ago (Ball Control, Sprint Training)

**Recent Training (Last 14 days)**:
- Shooting: 3 sessions, avg 2.3/5 stars ⚠️ **Poor performance!**
- Passing: 6 sessions, avg 4.1/5 stars ✅ Strong
- Dribbling: 2 sessions, avg 3.5/5 stars
- Ball Control: Last session was 2 days ago ✅ Too recent to recommend

**System Analysis**:
1. ✅ Identifies "Shooting" as skill gap (< 3.0 recent performance)
2. ✅ Tracks recent poor performance: 2.3/5 stars in last 14 days
3. ✅ Finds "Shooting Practice" exercise (Level 3)
4. ✅ Calculates 86% confidence (recent poor performance + perfect difficulty match)
5. ✅ Generates specific reasoning: "Your recent shooting sessions averaged 2.3/5 stars (46%)"
6. ✅ Won't recommend "Ball Control" (done 2 days ago)

**Final Recommendations**:
```
1. Shooting Practice - Level 3, 86% match
   "Your recent shooting sessions averaged 2.3/5 stars (46%) - let's improve that together!"

2. Advanced Passing - Level 3, 65% match
   "Passing is clearly your strength (82% avg.) - let's make it legendary!"

3. Tactical Awareness - Level 3, 58% match
   "Your training is heavy on technical work - let's balance it out with tactical drills."

4. Endurance Run - Level 2, 72% match
   "Impressive! Your level 1 sessions are averaging 84% - ready for the next challenge?"

5. Defending Fundamentals - Level 3, 75% match
   "Defending hasn't appeared in your training yet. As a midfielder, defensive awareness is crucial!"
```

---

## Technical Implementation Details

### Data Flow

```
User Opens Dashboard
    ↓
loadSmartRecommendations(for: player)
    ↓
analyzeTrainingHistory(for: player) → TrainingHistory
    ├─ Calculate time windows (3, 7, 14 days)
    ├─ Track recent exercises
    ├─ Calculate skill performance (overall + recent)
    └─ Identify poor performance skills
    ↓
identifySkillGaps(from: history) → [String]
    ↓
Generate 4 Recommendation Categories:
    ├─ Skill Gap Recommendations (Priority 1)
    │   ├─ Filter out exercises done in last 3 days ✅
    │   ├─ Boost confidence for recent poor performance ✅
    │   └─ Generate specific reasoning with data ✅
    ├─ Difficulty Progression (Priority 2)
    ├─ Variety Recommendations (Priority 3)
    └─ Success Pattern Recommendations (Priority 4)
    ↓
Sort by priority & confidence, deduplicate, take top 5
    ↓
Display on Dashboard with complete reasoning text
```

### Key Files Modified

1. **CoreDataManager.swift**
   - Lines 1650-1665: Enhanced TrainingHistory struct
   - Lines 1695-1789: Updated training history analysis
   - Lines 1855-1927: Improved reasoning text generation
   - Lines 2097-2188: Skill gap recommendations with recency filtering
   - Lines 2127-2163: Confidence calculation with recent performance boost

2. **DashboardView.swift**
   - Lines 860-864: Increased line limit for complete reasoning text

---

## Why This Matters

### **User Experience Impact**

**Before**:
- User sees "Ball Control - 94% - Perfect! Level 1 drills are ideal for building..."
- **Feels generic, unclear why 94%, text is cut off**

**After**:
- User sees "Shooting Practice - 86% - Your recent shooting sessions averaged 2.3/5 stars (46%) - let's improve that together!"
- **Feels personalized, understands why recommended, knows exactly what to work on**

### **Training Effectiveness**

- ✅ Addresses **actual** weak areas (based on recent performance data)
- ✅ Avoids recommending just-completed drills (prevents "did this yesterday" frustration)
- ✅ Provides **actionable** feedback with specific performance data
- ✅ Creates a **progressive** training program (difficulty matching)
- ✅ Ensures **variety** to build well-rounded skills

---

## Future Enhancements (Optional)

1. **Player Goal Integration**
   - Weight recommendations based on player's stated goals from onboarding
   - Example: If goal is "Improve shooting", boost shooting drill confidence by 10%

2. **Position-Specific Recommendations**
   - Strikers: Prioritize shooting/finishing drills
   - Defenders: Prioritize defensive positioning/tackling
   - Midfielders: Balance between defensive and attacking

3. **Time-of-Day Preferences**
   - Track when player usually trains
   - Recommend high-intensity drills during peak energy times

4. **Weather/Location Integration**
   - Indoor drills for rainy days
   - Field drills for sunny days

5. **Peer Comparison**
   - "Players at your level typically have 4.0 stars in passing - you're at 2.8"
   - Motivational boost through social comparison

---

## Summary

The TechnIQ recommendation system is a **smart, data-driven coach** that:

1. **Analyzes** training history with focus on recent performance (3, 7, 14-day windows)
2. **Identifies** skill gaps and areas needing improvement
3. **Prioritizes** recent struggles (82-90% confidence for poor recent performance)
4. **Filters** recently completed drills to avoid repetition
5. **Generates** specific, personalized reasoning with actual performance data
6. **Provides** actionable recommendations to improve player development

The system ensures players always know **exactly** what to work on and **why**, leading to more effective training and faster skill development.
