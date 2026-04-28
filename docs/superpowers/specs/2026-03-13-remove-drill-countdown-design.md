# Remove Drill Countdown/Timer Feature

## Summary
Remove all countdown, timer, and elapsed-time tracking from active training sessions. Players shouldn't be on the app while doing drills — they read instructions, go do the drill, come back, tap "I've completed this drill", then rate it.

## New Flow
```
Start session → Exercise (view instructions/diagram) → "I've completed this drill" → Rating → [next exercise | Session Complete]
```

3 phases: `exercise` → `rating` → `sessionComplete`

## What Gets Removed

### ActiveSessionManager.swift
- `TrainingPhase` cases `preparing`, `exerciseActive`, `rest` → replaced with `exercise`, `rating`, `sessionComplete`
- All timer properties: `displayTimer`, `preparingTimer`, `preparingCountdown`, `restDuration`, `restTimeRemaining`, `isPaused`
- All date tracking: `sessionStartTime`, `exerciseStartTime`, `restStartTime`, pause accumulators
- Methods: `startPreparingCountdown()`, `startDisplayTimer()`, `startRest()`, pause/resume
- Computed properties: `exerciseElapsedTime`, `sessionElapsedTime`, `restProgress`

### Views removed entirely
- `RestCountdownView.swift`

### Views simplified
- `ActiveTrainingView.swift` — remove preparing countdown overlay, rest phase routing; route only exercise → rating → session complete
- `ExerciseStepView.swift` — remove `timerSection`, add "I've completed this drill" button
- `DrillWalkthroughView.swift` — remove elapsed timer in perform phase, add completion button

## What Stays
- Drill instructions and diagram display
- Rating screen after each drill
- Session complete screen with summary
- XP/coin/achievement awards on completion

## UX
- "I've completed this drill" button at bottom of drill view (both ExerciseStepView and DrillWalkthroughView)
- Prominent button, single tap transitions to rating
- No confirmation dialog
