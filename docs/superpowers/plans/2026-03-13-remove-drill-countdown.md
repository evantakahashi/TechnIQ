# Remove Drill Countdown/Timer Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove all countdowns, timers, and elapsed time tracking from active training sessions so players read drill instructions on-app then do drills off-app.

**Architecture:** Collapse `TrainingPhase` from 5 states to 3 (`exercise`, `rating`, `sessionComplete`). Strip all timer/pause logic from `ActiveSessionManager`. Simplify views to show drill content + "I've completed this drill" button → rating → next drill.

**Tech Stack:** SwiftUI, Core Data

---

## File Structure

| File | Action | Responsibility after change |
|------|--------|-----------------------------|
| `TechnIQ/ActiveSessionManager.swift` | Modify | Simplified state machine: exercise → rating → sessionComplete. No timers. |
| `TechnIQ/ActiveTrainingView.swift` | Modify | Route 3 phases. No top-bar timer. No preparing overlay. No rest routing. |
| `TechnIQ/ExerciseStepView.swift` | Modify | Show drill info + "I've completed this drill" button. No timer section. |
| `TechnIQ/DrillWalkthroughView.swift` | Modify | Remove perform-phase timer. Show completion button without step-gate. |
| `TechnIQ/RestCountdownView.swift` | Delete | No longer needed. |
| `TechnIQ/SessionCompleteView.swift` | Modify | Remove `totalTime` parameter and time display. |
| `TechnIQTests/ActiveSessionManagerTests.swift` | Modify | Update tests for new phase enum and simplified flow. |

---

## Chunk 1: Core State Machine

### Task 1: Simplify ActiveSessionManager

**Files:**
- Modify: `TechnIQ/ActiveSessionManager.swift`

- [ ] **Step 1: Replace TrainingPhase enum**

Replace the enum at lines 8-14:

```swift
enum TrainingPhase: Equatable {
    case exercise        // viewing drill instructions
    case rating          // rating the completed drill
    case sessionComplete // done
}
```

- [ ] **Step 2: Strip timer properties and date tracking**

Remove these published properties:
- `isPaused`
- `preparingCountdown`
- `exerciseDurations`
- `restDuration`

Remove private properties:
- `sessionStartTime`, `exerciseStartTime`, `restStartTime`
- `accumulatedSessionPause`, `accumulatedExercisePause`, `pauseStartTime`
- `displayTimer`, `preparingTimer`, `foregroundObserver`

Remove computed properties:
- `totalElapsedTime`, `exerciseElapsedTime`, `restTimeRemaining`, `restProgress`
- `completedExerciseCount`

Keep:
- `phase`, `currentExerciseIndex`
- `exerciseRatings`, `exerciseNotes`
- `exercises` (let)
- `currentExercise`, `upNextExercise`, `isLastExercise`

- [ ] **Step 3: Rewrite init**

```swift
init(exercises: [Exercise]) {
    self.exercises = exercises
    self.exerciseRatings = Array(repeating: 0, count: exercises.count)
    self.exerciseNotes = Array(repeating: "", count: exercises.count)
}
```

Remove `deinit` entirely (no timers to cancel, no observers).

- [ ] **Step 4: Remove all timer methods**

Delete: `startDisplayTimer()`, `stopDisplayTimer()`, `startPreparingCountdown()`, `beginExercise()`

- [ ] **Step 5: Rewrite session lifecycle**

Replace `start()` with:
```swift
func start() {
    phase = .exercise
}
```

- [ ] **Step 6: Rewrite exercise flow**

Replace `completeExercise()` with:
```swift
func completeExercise() {
    guard phase == .exercise else { return }
    phase = .rating
    HapticManager.shared.exerciseComplete()
}
```

Keep `rateExercise(_:notes:)` as-is.

Replace `nextExercise()` with:
```swift
func nextExercise() {
    if isLastExercise {
        phase = .sessionComplete
        HapticManager.shared.sessionComplete()
    } else {
        currentExerciseIndex += 1
        phase = .exercise
    }
}
```

- [ ] **Step 7: Remove rest and pause methods**

Delete: `startRest()`, `adjustRest(_:)`, `skipRest()`, `restFinished()`, `pause()`, `resume()`

- [ ] **Step 8: Simplify endSessionEarly and finishSession**

Replace `endSessionEarly()`:
```swift
func endSessionEarly() {
    phase = .sessionComplete
    HapticManager.shared.sessionComplete()
}
```

In `finishSession(player:context:)`:
- Change `completedCount` to use `exerciseRatings.filter { $0 > 0 }.count`
- Remove `session.duration = totalElapsedTime / 60.0` line (set to 0 or remove)
- Remove `session.intensity = Int16(averageRating())` — keep `session.overallRating` instead

- [ ] **Step 9: Remove formattedTime helper**

Delete `formattedTime(_:)` — no longer needed.

- [ ] **Step 10: Remove Combine and UIKit imports**

Remove `import Combine` and `import UIKit` (no more Timer publishers or foreground observers).

- [ ] **Step 11: Build**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build`

Expect: build errors in views that still reference old phases/properties. That's fine — we fix those in Task 2-4.

- [ ] **Step 12: Commit**

```bash
git add TechnIQ/ActiveSessionManager.swift
git commit -m "refactor: simplify ActiveSessionManager — remove all timers and countdown phases"
```

---

### Task 2: Simplify ActiveTrainingView

**Files:**
- Modify: `TechnIQ/ActiveTrainingView.swift`

- [ ] **Step 1: Remove timer-related state**

Remove: `showingPauseMenu`, `showingEndConfirm` state vars.

- [ ] **Step 2: Replace top bar**

Remove the clock/elapsed time display. Keep exercise counter and add an "End Session" button (no pause needed):

```swift
private var topBar: some View {
    HStack {
        // Exercise counter
        Text("\(manager.currentExerciseIndex + 1) of \(manager.exercises.count)")
            .font(DesignSystem.Typography.titleSmall)
            .foregroundColor(DesignSystem.Colors.textPrimary)

        Spacer()

        // End session button
        Button {
            showingEndConfirm = true
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.title2)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }
    .padding(.horizontal, DesignSystem.Spacing.screenPadding)
    .padding(.vertical, DesignSystem.Spacing.sm)
}
```

Actually keep `showingEndConfirm` for the end-session alert. Remove `showingPauseMenu` only.

- [ ] **Step 3: Rewrite phaseContent**

```swift
@ViewBuilder
private var phaseContent: some View {
    switch manager.phase {
    case .exercise:
        if let exercise = manager.currentExercise, exercise.diagramJSON != nil {
            DrillWalkthroughView(exercise: exercise) { rating, difficulty, notes in
                manager.completeExercise()
                manager.rateExercise(rating, notes: notes)
                manager.nextExercise()
            }
        } else {
            ExerciseStepView(manager: manager)
        }

    case .rating:
        exerciseCompleteView

    case .sessionComplete:
        sessionCompleteContent
    }
}
```

- [ ] **Step 4: Remove preparingView**

Delete the entire `preparingView` computed property.

- [ ] **Step 5: Remove pauseOverlay**

Delete the entire `pauseOverlay` computed property.

- [ ] **Step 6: Update top bar visibility**

Change the condition from `manager.phase != .preparing && manager.phase != .sessionComplete` to just `manager.phase != .sessionComplete`.

- [ ] **Step 7: Remove statusBarHidden modifier**

Remove `.statusBarHidden(manager.phase == .preparing)`.

- [ ] **Step 8: Update exerciseCompleteView**

Remove the duration display line:
```swift
Text(manager.formattedTime(manager.exerciseDurations[manager.currentExerciseIndex]))
```

- [ ] **Step 9: Update sessionCompleteContent**

Remove `totalTime: manager.totalElapsedTime` from `SessionCompleteView` init.

- [ ] **Step 10: Build**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build`

- [ ] **Step 11: Commit**

```bash
git add TechnIQ/ActiveTrainingView.swift
git commit -m "refactor: simplify ActiveTrainingView — remove countdown, rest, and pause UI"
```

---

## Chunk 2: View Simplifications

### Task 3: Simplify ExerciseStepView

**Files:**
- Modify: `TechnIQ/ExerciseStepView.swift`

- [ ] **Step 1: Remove timerSection**

Delete the entire `timerSection` computed property (lines 76-89).

- [ ] **Step 2: Remove timerSection from body**

Remove `timerSection` reference from the VStack in body.

- [ ] **Step 3: Rename "Done" button to "I've completed this drill"**

In `doneButton`, change the label:

```swift
private var doneButton: some View {
    Button {
        manager.completeExercise()
    } label: {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
            Text("I've completed this drill")
                .font(DesignSystem.Typography.titleMedium)
                .fontWeight(.bold)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(DesignSystem.Colors.primaryGreen)
        .cornerRadius(DesignSystem.CornerRadius.button)
    }
    .padding(.horizontal, DesignSystem.Spacing.screenPadding)
    .padding(.bottom, DesignSystem.Spacing.sm)
}
```

- [ ] **Step 4: Build**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build`

- [ ] **Step 5: Commit**

```bash
git add TechnIQ/ExerciseStepView.swift
git commit -m "refactor: remove timer from ExerciseStepView, add completion button text"
```

---

### Task 4: Simplify DrillWalkthroughView

**Files:**
- Modify: `TechnIQ/DrillWalkthroughView.swift`

- [ ] **Step 1: Remove timer state and methods**

Remove:
- `@State private var elapsedSeconds: Int = 0`
- `@State private var timer: Timer?`
- `private var formattedTime` computed property
- `startTimer()` and `stopTimer()` methods
- `.onDisappear` timer cleanup

- [ ] **Step 2: Remove timer from perform phase top bar**

In `performPhase`, remove the HStack with clock icon and `formattedTime`. Keep just the drill name:

```swift
// Top bar
Text(exercise.name ?? "Drill")
    .font(DesignSystem.Typography.headlineSmall)
    .foregroundColor(DesignSystem.Colors.textPrimary)
    .padding(.horizontal, DesignSystem.Spacing.lg)
    .padding(.top, DesignSystem.Spacing.md)
    .padding(.bottom, DesignSystem.Spacing.sm)
```

- [ ] **Step 3: Show completion button always (remove step-gate)**

Change the completion button from conditional `if allStepsCompleted` to always visible. Update button text to "I've completed this drill":

```swift
// Complete button (always visible)
Button {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    transitionToRate()
} label: {
    Text("I've completed this drill")
        .font(DesignSystem.Typography.labelLarge)
        .foregroundColor(DesignSystem.Colors.textOnAccent)
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.primaryGreen)
        .cornerRadius(DesignSystem.CornerRadius.md)
}
.padding(.horizontal, DesignSystem.Spacing.lg)
```

Remove `@State private var allStepsCompleted` and the `onStepCompleted` callback that sets it.

- [ ] **Step 4: Remove elapsed time from rate phase**

In `ratePhase`, delete the "Time" VStack that displays `formattedTime`.

- [ ] **Step 5: Update transitionToPerform**

Remove `startTimer()` call and `elapsedSeconds = 0`:

```swift
private func transitionToPerform() {
    currentStep = 1
    isAutoPlaying = false
    allStepsCompleted = false
    phase = .perform
}
```

Wait — we removed `allStepsCompleted` in step 3. Update:

```swift
private func transitionToPerform() {
    currentStep = 1
    isAutoPlaying = false
    phase = .perform
}
```

- [ ] **Step 6: Simplify transitionToRate**

```swift
private func transitionToRate() {
    phase = .rate
}
```

- [ ] **Step 7: Remove UIKit import**

Remove `import UIKit` — use `HapticManager` instead of direct `UIImpactFeedbackGenerator`. Actually, check if `UIImpactFeedbackGenerator` is used elsewhere in the file. If it's only in the completion button, replace with `HapticManager.shared.lightTap()`.

- [ ] **Step 8: Build**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build`

- [ ] **Step 9: Commit**

```bash
git add TechnIQ/DrillWalkthroughView.swift
git commit -m "refactor: remove timer from DrillWalkthroughView, always show completion button"
```

---

### Task 5: Delete RestCountdownView

**Files:**
- Delete: `TechnIQ/RestCountdownView.swift`
- Modify: `TechnIQ.xcodeproj/project.pbxproj` (remove file reference)

- [ ] **Step 1: Delete the file**

```bash
rm TechnIQ/RestCountdownView.swift
```

- [ ] **Step 2: Remove from Xcode project**

Use Ruby script or manually remove from pbxproj. Alternatively, build will still succeed if file is just deleted — Xcode handles missing file references gracefully for non-referenced files. If build fails, remove the file reference from pbxproj.

- [ ] **Step 3: Build**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build`

- [ ] **Step 4: Commit**

```bash
git add -A TechnIQ/RestCountdownView.swift TechnIQ.xcodeproj/project.pbxproj
git commit -m "refactor: delete RestCountdownView"
```

---

## Chunk 3: Cleanup

### Task 6: Update SessionCompleteView

**Files:**
- Modify: `TechnIQ/SessionCompleteView.swift`

- [ ] **Step 1: Remove totalTime property**

Remove `var totalTime: TimeInterval = 0` from the struct.

- [ ] **Step 2: Remove time display**

Remove or replace the time display section (around lines 500-501) that formats `totalTime`.

- [ ] **Step 3: Update any callers**

Check `NewSessionView.swift` for `SessionCompleteView` usage — remove `totalTime` param if passed.

- [ ] **Step 4: Build**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build`

- [ ] **Step 5: Commit**

```bash
git add TechnIQ/SessionCompleteView.swift TechnIQ/NewSessionView.swift
git commit -m "refactor: remove totalTime from SessionCompleteView"
```

---

### Task 7: Update Tests

**Files:**
- Modify: `TechnIQTests/ActiveSessionManagerTests.swift`

- [ ] **Step 1: Read existing tests**

Read `TechnIQTests/ActiveSessionManagerTests.swift` to understand what's tested.

- [ ] **Step 2: Rewrite tests for new flow**

Update tests to cover:
- `start()` sets phase to `.exercise`
- `completeExercise()` transitions to `.rating`
- `rateExercise()` stores rating and notes
- `nextExercise()` advances index and goes to `.exercise`
- `nextExercise()` on last exercise goes to `.sessionComplete`
- `endSessionEarly()` goes to `.sessionComplete`

Remove tests for:
- Preparing countdown
- Rest countdown
- Pause/resume
- Timer elapsed time
- Display timer

- [ ] **Step 3: Build and run tests**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' test`

- [ ] **Step 4: Commit**

```bash
git add TechnIQTests/ActiveSessionManagerTests.swift
git commit -m "test: update ActiveSessionManager tests for simplified flow"
```

---

### Task 8: Final verification

- [ ] **Step 1: Full build**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build`

- [ ] **Step 2: Run all tests**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' test`

- [ ] **Step 3: Final commit if any fixups needed**
