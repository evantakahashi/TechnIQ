# Onboarding Overhaul Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace 3 overlapping onboarding flows with a single unified linear flow that collects profile data and auto-generates a training plan.

**Architecture:** Auth (creds only) → 5-step UnifiedOnboardingView (Welcome → Goal → About You → Soccer Profile → Plan Generation) → MainTabView. Player creation at step 4 end, plan generation at step 5 using existing CloudMLService. Sign-up passes name to onboarding via UserDefaults.

**Tech Stack:** SwiftUI, Core Data, CloudMLService (Firebase Functions), TrainingPlanService

---

### Task 1: Simplify Sign-Up Flow

**Files:**
- Modify: `TechnIQ/AuthenticationView.swift`

**Step 1: Remove soccer profile state vars and configuration step**

In `ModernSignUpView`, delete these state vars:
```swift
// DELETE these lines (~198-200):
@State private var selectedPositions: Set<String> = []
@State private var selectedStyle = "Balanced"
@State private var selectedFoot = "Right"
```

Delete these constants:
```swift
// DELETE these lines (~202-204):
private let positions = ["GK", "CB", "LB", "RB", "CDM", "CM", "CAM", "LW", "RW", "ST"]
private let styles = ["Aggressive", "Defensive", "Balanced", "Creative", "Fast", "Playmaker", "Box-to-Box", "Target Man", "Poacher", "Sweeper"]
private let feet = ["Left", "Right", "Both"]
```

Delete `@State private var currentStep = 0` (~197).

**Step 2: Remove step navigation from header**

Replace the back button action (line ~210-217):
```swift
// Change from step-based navigation to just dismissing sign-up
Button(action: {
    withAnimation(DesignSystem.Animation.smooth) {
        isSignUp = false
    }
}) {
```

**Step 3: Remove progress indicator and step switching**

Delete the `HStack` with `StepIndicator` components (~245-252).

Replace the `ScrollView` body — remove the `if currentStep == 0` / `else` branching. Keep only `modernDataStep` content. Delete `modernConfigurationStep` entirely (~358-436).

**Step 4: Make CREATE ACCOUNT the action on the data step**

Move the "CREATE ACCOUNT" button into `modernDataStep` (replacing the CONTINUE button). The button action:
```swift
ModernButton("CREATE ACCOUNT", icon: "checkmark") {
    // Save name for onboarding prefill
    let fullName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    if !fullName.isEmpty {
        UserDefaults.standard.set(fullName, forKey: "onboarding_prefill_name")
    }
    Task {
        await authManager.signUp(email: email, password: password)
    }
}
.disabled(!fieldsAreValid || authManager.isLoading)
```

Update `fieldsAreValid` — keep as-is (username, firstName, lastName, email, password, confirmPassword).

**Step 5: Delete unused helper components**

Delete `StepIndicator`, `ProgressLine` structs (~446-506) — they were only used in sign-up step indicator. Also delete `MultiSelectPillSelector` and `PillSelector` references if they're only used here (check first — they may be used elsewhere).

**Step 6: Build and verify**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build`
Expected: BUILD SUCCEEDED

**Step 7: Commit**

```bash
git add TechnIQ/AuthenticationView.swift
git commit -m "simplify sign-up: remove soccer config step, save name for onboarding"
```

---

### Task 2: Create UnifiedOnboardingView

**Files:**
- Create: `TechnIQ/UnifiedOnboardingView.swift`

**Step 1: Create the view with all state and step definitions**

Create `TechnIQ/UnifiedOnboardingView.swift` with:

```swift
import SwiftUI
import CoreData

struct UnifiedOnboardingView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var coreDataManager: CoreDataManager
    @EnvironmentObject private var authManager: AuthenticationManager
    @Binding var isOnboardingComplete: Bool

    // Step state
    @State private var currentStep = 0
    private let totalSteps = 5

    // Step 2: Goal
    @State private var selectedGoal = "Improve Skills"
    @State private var selectedFrequency = "3-4x per week"

    // Step 3: About You
    @State private var playerName = ""
    @State private var playerAge = 16
    @State private var selectedExperienceLevel = "Beginner"
    @State private var yearsPlaying: Int = 2

    // Step 4: Soccer Profile
    @State private var selectedPosition = "Midfielder"
    @State private var selectedPlayingStyle = "Balanced"
    @State private var selectedDominantFoot = "Right"

    // Step 5: Plan Generation
    @State private var isGeneratingPlan = false
    @State private var planGenerationFailed = false
    @State private var planErrorMessage = ""
    @State private var loadingPhase: LoadingPhase = .connecting
    @State private var generationTask: Task<Void, Never>?
    @State private var planGenerationComplete = false

    // Constants
    let trainingGoals = ["Improve Skills", "Build Fitness", "Prepare for Tryouts", "Stay Active", "Become Pro"]
    let trainingFrequencies = ["2-3x per week", "3-4x per week", "5-6x per week", "Daily"]
    let positions = ["Goalkeeper", "Defender", "Midfielder", "Forward"]
    let playingStyles = ["Aggressive", "Defensive", "Balanced", "Creative", "Fast"]
    let dominantFeet = ["Left", "Right", "Both"]
    let experienceLevels = ["Beginner", "Intermediate", "Advanced", "Professional"]

    var body: some View {
        // ... (built in subsequent steps)
    }
}
```

**Step 2: Build the main body, header, and progress indicator**

Reuse the exact layout from `EnhancedOnboardingView` (lines 35-67, 71-148): ZStack with background gradient, VStack with header, progress indicator, step content, continue button. Key changes:
- Skip button on steps 0 and 1 (skips to step 2 — profile creation)
- Back button disabled on step 0 and step 4 (plan gen in progress)
- `stepTitle` returns: "Welcome", "Your Goal", "About You", "Your Style", "Your Plan"

**Step 3: Build Steps 1-4 (reuse EnhancedOnboardingView step views)**

Copy the step views from `EnhancedOnboardingView`:
- `welcomeStep` (lines 229-277) — identical
- `goalStep` (lines 279-338) — identical
- `basicInfoStep` (lines 352-456) — identical
- `positionStyleStep` (lines 458-551) — identical

Add name prefill in `onAppear`:
```swift
.onAppear {
    if let prefillName = UserDefaults.standard.string(forKey: "onboarding_prefill_name"), !prefillName.isEmpty {
        playerName = prefillName
        UserDefaults.standard.removeObject(forKey: "onboarding_prefill_name")
    }
}
```

**Step 4: Build Step 5 — Plan Generation screen**

```swift
private var planGenerationStep: some View {
    VStack(spacing: DesignSystem.Spacing.xl) {
        Spacer()

        if planGenerationComplete {
            // Celebration state
            MascotView(state: .excited, size: .xlarge, showSpeechBubble: true, speechText: "Let's go!")

            VStack(spacing: DesignSystem.Spacing.md) {
                Text("You're All Set!")
                    .font(DesignSystem.Typography.headlineLarge)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text("Your personalized training plan is ready")
                    .font(DesignSystem.Typography.bodyLarge)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        } else if planGenerationFailed {
            // Error state
            MascotView(state: .thinking, size: .large, showSpeechBubble: true, speechText: "Hmm...")

            VStack(spacing: DesignSystem.Spacing.md) {
                Text("Couldn't Generate Plan")
                    .font(DesignSystem.Typography.headlineMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text(planErrorMessage)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: DesignSystem.Spacing.md) {
                ModernButton("Try Again", icon: "arrow.clockwise", style: .primary) {
                    generateInitialPlan()
                }

                Button("Skip for Now") {
                    isOnboardingComplete = true
                }
                .font(DesignSystem.Typography.labelMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        } else {
            // Loading state
            MascotView(state: .coaching, size: .large, showSpeechBubble: true, speechText: loadingPhase.title)

            VStack(spacing: DesignSystem.Spacing.md) {
                Text("Building Your Plan")
                    .font(DesignSystem.Typography.headlineMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text(loadingPhase.description)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            ProgressView(value: loadingPhase.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: DesignSystem.Colors.primaryGreen))
                .frame(width: 200)
        }

        Spacer()
    }
    .padding(.horizontal, DesignSystem.Spacing.screenPadding)
}
```

**Step 5: Build `createPlayer()` function**

Reuse from `EnhancedOnboardingView` lines 625-724 — identical logic. Called at the transition from step 3 → step 4 (actually at the end of step 4, when user taps "START TRAINING").

**Step 6: Build `generateInitialPlan()` function**

```swift
private func generateInitialPlan() {
    isGeneratingPlan = true
    planGenerationFailed = false
    loadingPhase = .connecting

    // Animate through loading phases
    let phaseTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { timer in
        DispatchQueue.main.async {
            switch loadingPhase {
            case .connecting: loadingPhase = .analyzing
            case .analyzing: loadingPhase = .generating
            case .generating: loadingPhase = .structuring
            case .structuring: loadingPhase = .finalizing
            case .finalizing: timer.invalidate()
            }
        }
    }

    generationTask = Task {
        do {
            // Fetch the player we just created
            let request = Player.fetchRequest()
            request.predicate = NSPredicate(format: "firebaseUID == %@", authManager.userUID)
            guard let player = try viewContext.fetch(request).first else {
                throw NSError(domain: "Onboarding", code: 1, userInfo: [NSLocalizedDescriptionKey: "Player not found"])
            }

            let difficulty = mapExperienceToDifficulty(selectedExperienceLevel)
            let category = mapGoalToCategory(selectedGoal)
            let preferredDays = mapFrequencyToDays(selectedFrequency)
            let restDays = DayOfWeek.allCases.map(\.rawValue).filter { !preferredDays.contains($0) }

            let structure = try await CloudMLService.shared.generateTrainingPlan(
                for: player,
                duration: 4,
                difficulty: difficulty,
                category: category,
                targetRole: selectedPosition,
                focusAreas: [],
                preferredDays: preferredDays,
                restDays: restDays
            )

            // Save plan to Core Data
            let _ = TrainingPlanService.shared.createPlanFromAIGeneration(structure, for: player)

            await MainActor.run {
                phaseTimer.invalidate()
                isGeneratingPlan = false
                planGenerationComplete = true

                // Auto-navigate after brief celebration
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    isOnboardingComplete = true
                }
            }
        } catch {
            await MainActor.run {
                phaseTimer.invalidate()
                isGeneratingPlan = false
                planGenerationFailed = true
                planErrorMessage = error.localizedDescription
            }
        }
    }
}
```

**Step 7: Build mapping helpers**

```swift
private func mapExperienceToDifficulty(_ experience: String) -> String {
    switch experience {
    case "Beginner": return PlanDifficulty.beginner.rawValue
    case "Intermediate": return PlanDifficulty.intermediate.rawValue
    case "Advanced": return PlanDifficulty.advanced.rawValue
    case "Professional": return PlanDifficulty.elite.rawValue
    default: return PlanDifficulty.intermediate.rawValue
    }
}

private func mapGoalToCategory(_ goal: String) -> String {
    switch goal {
    case "Improve Skills": return PlanCategory.technical.rawValue
    case "Build Fitness": return PlanCategory.physical.rawValue
    case "Prepare for Tryouts": return PlanCategory.general.rawValue
    case "Stay Active": return PlanCategory.general.rawValue
    case "Become Pro": return PlanCategory.technical.rawValue
    default: return PlanCategory.general.rawValue
    }
}

private func mapFrequencyToDays(_ frequency: String) -> [String] {
    switch frequency {
    case "2-3x per week": return ["Monday", "Wednesday", "Friday"]
    case "3-4x per week": return ["Monday", "Tuesday", "Thursday", "Friday"]
    case "5-6x per week": return ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    case "Daily": return DayOfWeek.allCases.map(\.rawValue)
    default: return ["Monday", "Wednesday", "Friday"]
    }
}
```

**Step 8: Update continue button logic**

The continue button behavior per step:
- Steps 0-3: advance `currentStep`
- Step 3 (About You) → Step 4: just advances (no special action)
- Step 4 (Soccer Profile) → tapping "START TRAINING": call `createPlayer()` then advance to step 5, which triggers `generateInitialPlan()` in `onAppear`
- Step 5: no continue button shown (auto-navigates on success, or shows retry/skip)

```swift
private var continueButton: some View {
    Group {
        if currentStep < totalSteps - 1 {
            Button(action: {
                HapticManager.shared.mediumTap()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    if currentStep == 3 {
                        // End of soccer profile — create player, then advance to plan gen
                        createPlayer()
                        currentStep += 1
                        generateInitialPlan()
                    } else {
                        currentStep += 1
                    }
                }
            }) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Text(buttonTitle)
                        .font(DesignSystem.Typography.labelLarge)
                        .fontWeight(.semibold)
                    if currentStep == 3 {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(canContinue ? DesignSystem.Colors.primaryGreen : Color.gray)
                .cornerRadius(DesignSystem.CornerRadius.button)
            }
            .disabled(!canContinue)
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.bottom, 34)
        }
        // Step 5: no continue button — auto-navigates or shows retry/skip inline
    }
}
```

**Step 9: Add the file to the Xcode project**

Use the Ruby xcodeproj script or manually add `UnifiedOnboardingView.swift` to the TechnIQ target.

**Step 10: Build and verify**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build`
Expected: BUILD SUCCEEDED

**Step 11: Commit**

```bash
git add TechnIQ/UnifiedOnboardingView.swift TechnIQ.xcodeproj/project.pbxproj
git commit -m "feat: add UnifiedOnboardingView with 5-step flow and plan generation"
```

---

### Task 3: Wire Up UnifiedOnboardingView and Delete Old Files

**Files:**
- Modify: `TechnIQ/ContentView.swift`
- Modify: `TechnIQ/DashboardView.swift`
- Delete: `TechnIQ/OnboardingView.swift`
- Delete: `TechnIQ/EnhancedOnboardingView.swift`

**Step 1: Update ContentView**

In `PlayerContentView` (line ~102), replace:
```swift
EnhancedOnboardingView(isOnboardingComplete: $isOnboardingComplete)
```
with:
```swift
UnifiedOnboardingView(isOnboardingComplete: $isOnboardingComplete)
```

**Step 2: Update DashboardView**

In `DashboardView` (line ~102), replace:
```swift
EnhancedOnboardingView(isOnboardingComplete: $isOnboardingComplete)
```
with:
```swift
UnifiedOnboardingView(isOnboardingComplete: $isOnboardingComplete)
```

**Step 3: Delete old onboarding files**

Delete `TechnIQ/OnboardingView.swift` and `TechnIQ/EnhancedOnboardingView.swift`. Remove their references from the Xcode project file.

**Step 4: Move helper views if needed**

Check if `OnboardingFeatureRow`, `OnboardingOptionButton`, `FrequencyChip`, `PositionButton`, `SummaryRow` are defined in `EnhancedOnboardingView.swift`. If so, they need to either:
- Be included in `UnifiedOnboardingView.swift`, or
- Be extracted to a shared file

They ARE all defined in `EnhancedOnboardingView.swift` (lines 730-864). Move them into `UnifiedOnboardingView.swift` at the bottom.

**Step 5: Build and verify**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build`
Expected: BUILD SUCCEEDED

**Step 6: Commit**

```bash
git add TechnIQ/ContentView.swift TechnIQ/DashboardView.swift TechnIQ.xcodeproj/project.pbxproj
git rm TechnIQ/OnboardingView.swift TechnIQ/EnhancedOnboardingView.swift
git commit -m "wire up UnifiedOnboardingView, delete old onboarding files"
```

---

### Task 4: Verify StepIndicator/ProgressLine Cleanup

**Files:**
- Modify: `TechnIQ/AuthenticationView.swift` (if StepIndicator/ProgressLine still referenced elsewhere)

**Step 1: Check for other usages of StepIndicator and ProgressLine**

Search the codebase for `StepIndicator` and `ProgressLine` references outside `AuthenticationView.swift`. If none, delete them from Task 1 was correct. If they're used elsewhere, leave them.

**Step 2: Check for MultiSelectPillSelector / PillSelector**

These were used in the deleted `modernConfigurationStep`. Search for other references. If unused, delete. If used elsewhere, leave.

**Step 3: Build and verify**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build`
Expected: BUILD SUCCEEDED

**Step 4: Commit (if changes were made)**

```bash
git add -u
git commit -m "cleanup: remove unused StepIndicator/ProgressLine/PillSelector components"
```

---

### Task 5: Final Build + Push

**Step 1: Full clean build**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' clean build`
Expected: BUILD SUCCEEDED

**Step 2: Push**

```bash
git push origin main
```
