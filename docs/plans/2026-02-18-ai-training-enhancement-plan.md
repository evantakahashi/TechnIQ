# AI Training Enhancement Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Transform the AI training experience with animated drill diagrams, weakness-targeted generation, and a redesigned active training flow.

**Architecture:** Layered approach — data model first, then animated diagram component, active training integration, weakness picker + smart recs, AI pipeline, template expansion. Each phase builds on the previous and is independently committable.

**Tech Stack:** SwiftUI, Core Data (lightweight migration), Firebase Functions (Python), DesignSystem constants

---

## Task 1: Core Data Schema — Add New Fields

**Files:**
- Modify: `TechnIQ/DataModel.xcdatamodeld` (Core Data model editor — use Xcode or manual XML edit)
- Modify: `TechnIQ/CustomDrillModels.swift`

**Step 1: Add `step` field to DiagramPath model**

In `CustomDrillModels.swift`, add `step` to `DiagramPath`:

```swift
struct DiagramPath: Codable {
    let from: String
    let to: String
    let style: String
    let step: Int?  // nil = show on all steps (backward compat)

    var pathStyle: DiagramPathStyle {
        DiagramPathStyle(rawValue: style) ?? .run
    }
}
```

**Step 2: Add new fields to Exercise entity in Core Data model**

Add these optional attributes to the `Exercise` entity in `DataModel.xcdatamodeld`:
- `estimatedDurationSeconds` — Integer 16, Optional
- `variationsJSON` — String, Optional
- `weaknessCategories` — String, Optional

**Step 3: Add `weaknessProfileJSON` to Player entity**

Add to `Player` entity in `DataModel.xcdatamodeld`:
- `weaknessProfileJSON` — String, Optional

**Step 4: Build and verify migration**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build`
Expected: Clean build, lightweight migration succeeds.

**Step 5: Commit**

```
feat: add Core Data fields for drill steps, variations, weakness tracking
```

---

## Task 2: Weakness Data Models

**Files:**
- Create: `TechnIQ/WeaknessModels.swift`

**Step 1: Create weakness category and sub-weakness enums**

```swift
import Foundation

// MARK: - Weakness Models

enum WeaknessCategory: String, CaseIterable, Codable, Identifiable {
    case dribbling, passing, shooting, firstTouch, defending
    case speedAgility, stamina, positioning, weakFoot, aerialAbility

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dribbling: return "Dribbling"
        case .passing: return "Passing"
        case .shooting: return "Shooting"
        case .firstTouch: return "First Touch"
        case .defending: return "Defending"
        case .speedAgility: return "Speed & Agility"
        case .stamina: return "Stamina"
        case .positioning: return "Positioning"
        case .weakFoot: return "Weak Foot"
        case .aerialAbility: return "Aerial Ability"
        }
    }

    var icon: String {
        switch self {
        case .dribbling: return "figure.soccer"
        case .passing: return "arrow.triangle.branch"
        case .shooting: return "target"
        case .firstTouch: return "hand.point.up"
        case .defending: return "shield.fill"
        case .speedAgility: return "bolt.fill"
        case .stamina: return "heart.fill"
        case .positioning: return "mappin.and.ellipse"
        case .weakFoot: return "shoe.fill"
        case .aerialAbility: return "arrow.up.circle"
        }
    }

    var subWeaknesses: [SubWeakness] {
        switch self {
        case .dribbling:
            return [.underPressure, .changeOfDirection, .tightSpaces, .weakFootDribbling, .beat1v1, .speedDribbling]
        case .passing:
            return [.longRangeAccuracy, .weakFootPassing, .throughBalls, .firstTimePassing, .passingUnderPressure, .switchingPlay]
        case .shooting:
            return [.finishing1v1, .weakFootShooting, .volleys, .longRange, .placementVsPower, .headersOnGoal]
        case .firstTouch:
            return [.touchUnderPressure, .aerialBalls, .turningWithFirstTouch, .weakFootControl, .bouncingBalls]
        case .defending:
            return [.tackling1v1, .defensivePositioning, .aerialDuels, .recoveryRuns, .readingTheGame, .pressingTriggers]
        case .speedAgility:
            return [.acceleration, .agilityChangeOfDirection, .sprintEndurance, .agilityTightSpaces]
        case .stamina:
            return [.matchFitness, .highIntensityIntervals, .recoveryBetweenEfforts]
        case .positioning:
            return [.offTheBallMovement, .creatingSpace, .defensiveShape, .transitionPositioning]
        case .weakFoot:
            return [.weakFootPassing, .weakFootShooting, .weakFootDribbling, .weakFootControl, .weakFootCrossing]
        case .aerialAbility:
            return [.headingAccuracy, .jumpingTiming, .aerialDuels, .headedPasses]
        }
    }
}

enum SubWeakness: String, CaseIterable, Codable, Identifiable {
    // Dribbling
    case underPressure, changeOfDirection, tightSpaces, weakFootDribbling, beat1v1, speedDribbling
    // Passing
    case longRangeAccuracy, weakFootPassing, throughBalls, firstTimePassing, passingUnderPressure, switchingPlay
    // Shooting
    case finishing1v1, weakFootShooting, volleys, longRange, placementVsPower, headersOnGoal
    // First Touch
    case touchUnderPressure, aerialBalls, turningWithFirstTouch, weakFootControl, bouncingBalls
    // Defending
    case tackling1v1, defensivePositioning, aerialDuels, recoveryRuns, readingTheGame, pressingTriggers
    // Speed & Agility
    case acceleration, agilityChangeOfDirection, sprintEndurance, agilityTightSpaces
    // Stamina
    case matchFitness, highIntensityIntervals, recoveryBetweenEfforts
    // Positioning
    case offTheBallMovement, creatingSpace, defensiveShape, transitionPositioning
    // Weak Foot
    case weakFootCrossing
    // Aerial
    case headingAccuracy, jumpingTiming, headedPasses

    var id: String { rawValue }

    var displayName: String {
        // Convert camelCase to readable string
        rawValue.replacingOccurrences(of: "([A-Z])", with: " $1", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
            .capitalized
    }
}

// MARK: - Selected Weakness (for API payload)

struct SelectedWeakness: Codable {
    let category: String
    let specific: String
}

// MARK: - Weakness Profile (cached analysis)

struct WeaknessProfile: Codable {
    let suggestedWeaknesses: [SelectedWeakness]
    let dataSources: [String]  // e.g., ["5 matches", "12 sessions"]
    let lastUpdated: Date
}
```

**Step 2: Build**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build`

**Step 3: Commit**

```
feat: add weakness category models with two-tier hierarchy
```

---

## Task 3: Animated Field Renderer

**Files:**
- Modify: `TechnIQ/DrillDiagramView.swift` (rewrite)

This is the core visual upgrade. Replace the current static diagram with an animated, step-aware renderer.

**Step 1: Create the new AnimatedDrillDiagramView**

Replace the contents of `DrillDiagramView.swift` with the new animated version. Key changes:

- **Field rendering:** Replace flat green rectangle with grass-stripe gradient pattern + field markings (center line, center circle, penalty areas scaled to field size)
- **Element rendering upgrades:**
  - Players: filled circles with jersey number label inside, `primaryGreen` fill, pulsing glow when active (`@State activeStep` controls which elements highlight)
  - Cones: gradient fill (orange top → darker orange bottom) for 3D effect
  - Goals: goal-post lines with hatched net pattern (diagonal lines inside rectangle)
  - Ball: white circle with subtle pentagon pattern (5-sided path overlay), drop shadow
- **Path rendering upgrades:**
  - Replace straight `Path.addLine` with `Path.addQuadCurve` for curved bezier paths
  - Animated dot traveling along path using `AnimatableData` on a `TrimmedShape`
  - Pass paths keep arrowhead at endpoint
- **Step state:** `@Binding var currentStep: Int?` — when nil, show all elements/paths. When set, highlight only elements/paths matching that step, dim others to 40% opacity.

The view signature becomes:
```swift
struct AnimatedDrillDiagramView: View {
    let diagram: DrillDiagram
    let instructions: [String]
    @Binding var currentStep: Int?
    @Binding var isAutoPlaying: Bool
    var playbackSpeed: Double = 1.0
    var isTrainingMode: Bool = false
    var onStepCompleted: ((Int) -> Void)? = nil
}
```

Keep the old `DrillDiagramView` as a deprecated wrapper that creates an `AnimatedDrillDiagramView` with `currentStep: .constant(nil)` for backward compat in `ExerciseDetailView`.

**Step 2: Implement grass texture and field markings**

Field background layers (bottom to top):
1. Base dark green rounded rectangle
2. Alternating stripe overlay: `ForEach(0..<stripeCount)` of thin lighter-green rectangles at regular intervals, clipped to field bounds
3. Center line: horizontal white line at fieldHeight/2
4. Center circle: white circle stroke at field center, radius = min(fieldWidth, fieldHeight) * 0.15
5. Touchline border: white rounded rectangle stroke

```swift
private func fieldBackground(fieldWidth: CGFloat, fieldHeight: CGFloat, offsetX: CGFloat, offsetY: CGFloat) -> some View {
    ZStack {
        // Base green
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(red: 0.18, green: 0.42, blue: 0.18))
            .frame(width: fieldWidth, height: fieldHeight)

        // Grass stripes
        let stripeCount = 8
        let stripeHeight = fieldHeight / CGFloat(stripeCount)
        ForEach(0..<stripeCount, id: \.self) { i in
            if i % 2 == 0 {
                Rectangle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: fieldWidth, height: stripeHeight)
                    .offset(y: -fieldHeight / 2 + stripeHeight * CGFloat(i) + stripeHeight / 2)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))

        // Center line
        Rectangle()
            .fill(Color.white.opacity(0.3))
            .frame(width: fieldWidth - 8, height: 1)

        // Center circle
        Circle()
            .stroke(Color.white.opacity(0.3), lineWidth: 1)
            .frame(width: min(fieldWidth, fieldHeight) * 0.3)

        // Touchline border
        RoundedRectangle(cornerRadius: 8)
            .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
            .frame(width: fieldWidth, height: fieldHeight)
    }
    .position(x: offsetX + fieldWidth / 2, y: offsetY + fieldHeight / 2)
}
```

**Step 3: Implement upgraded element renderers**

Each element gets a new renderer. Example for player:
```swift
private func playerView(label: String, isActive: Bool) -> some View {
    VStack(spacing: 2) {
        ZStack {
            Circle()
                .fill(DesignSystem.Colors.primaryGreen)
                .frame(width: playerSize, height: playerSize)
            if isActive {
                Circle()
                    .fill(DesignSystem.Colors.primaryGreen.opacity(0.3))
                    .frame(width: playerSize + 10, height: playerSize + 10)
                    .modifier(PulseAnimation())
            }
            Text(label.prefix(2))
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
        }
        .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
    }
    .opacity(stepOpacity(for: label))
}
```

**Step 4: Implement bezier path rendering with animation**

Replace straight lines with quadratic curves. The control point is offset perpendicular to the line midpoint:

```swift
private func curvedPath(from: CGPoint, to: CGPoint) -> Path {
    var path = Path()
    path.move(to: from)
    let midX = (from.x + to.x) / 2
    let midY = (from.y + to.y) / 2
    let dx = to.x - from.x
    let dy = to.y - from.y
    let perpOffset: CGFloat = 20  // curve intensity
    let controlPoint = CGPoint(x: midX - dy * perpOffset / hypot(dx, dy),
                                y: midY + dx * perpOffset / hypot(dx, dy))
    path.addQuadCurve(to: to, control: controlPoint)
    return path
}
```

Animated dot: use `trim(from:to:)` on a circle overlaid on the path, driven by a `@State animationProgress: CGFloat` that animates from 0→1 with `.easeInOut(duration: 1.5 / playbackSpeed)`.

**Step 5: Implement step-by-step playback controls**

Bottom overlay bar:
```swift
private var stepControlBar: some View {
    VStack(spacing: DesignSystem.Spacing.sm) {
        // Step instruction text
        if let step = currentStep, step > 0, step <= instructions.count {
            Text(instructions[step - 1])
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.md)
        }

        HStack {
            // Previous step
            Button { previousStep() } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
            }
            .disabled((currentStep ?? 0) <= 1)

            Spacer()

            // Step counter
            Text("Step \(currentStep ?? 0) of \(instructions.count)")
                .font(DesignSystem.Typography.labelMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Spacer()

            if isTrainingMode {
                // Mark Step Done button (training mode)
                Button("Done") { completeCurrentStep() }
                    .font(DesignSystem.Typography.labelLarge)
                    .foregroundColor(.white)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(DesignSystem.Colors.primaryGreen)
                    .cornerRadius(DesignSystem.CornerRadius.button)
            } else {
                // Next step
                Button { nextStep() } label: {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title2)
                }
                .disabled((currentStep ?? 0) >= instructions.count)
            }
        }

        // Auto-play and speed controls
        HStack(spacing: DesignSystem.Spacing.md) {
            Button { isAutoPlaying.toggle() } label: {
                Image(systemName: isAutoPlaying ? "pause.fill" : "play.fill")
                Text(isAutoPlaying ? "Pause" : "Auto-play")
                    .font(DesignSystem.Typography.labelSmall)
            }
            .foregroundColor(DesignSystem.Colors.textSecondary)

            // Speed selector (only shown when not in training mode)
            if !isTrainingMode {
                HStack(spacing: 4) {
                    ForEach([0.5, 1.0, 2.0], id: \.self) { speed in
                        Button("\(speed == 1.0 ? "1" : speed == 0.5 ? "0.5" : "2")x") {
                            // update playbackSpeed
                        }
                        .font(DesignSystem.Typography.labelSmall)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(playbackSpeed == speed ? DesignSystem.Colors.primaryGreen.opacity(0.2) : Color.clear)
                        .cornerRadius(DesignSystem.CornerRadius.xs)
                    }
                }
            }
        }
    }
    .padding(DesignSystem.Spacing.md)
    .background(DesignSystem.Colors.surfaceRaised)
    .cornerRadius(DesignSystem.CornerRadius.lg)
}
```

**Step 6: Build and verify**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build`

**Step 7: Commit**

```
feat: animated drill diagram with grass texture, bezier paths, step playback
```

---

## Task 4: Integrate Animated Diagram into ExerciseDetailView

**Files:**
- Modify: `TechnIQ/ExerciseDetailView.swift`

**Step 1: Replace DrillDiagramView usage with AnimatedDrillDiagramView**

In ExerciseDetailView, find the existing drill diagram section and replace with the new animated version. Add `@State` vars for step control:

```swift
@State private var diagramStep: Int? = nil
@State private var isAutoPlaying: Bool = false
```

Replace the diagram frame with the interactive version + step controls.

**Step 2: Parse instructions into step array**

The exercise's `instructions` field is markdown. Parse numbered steps out of it:

```swift
private var parsedSteps: [String] {
    guard let instructions = exercise.instructions else { return [] }
    return instructions.components(separatedBy: "\n")
        .filter { $0.matches(of: /^\d+\./).count > 0 }
        .map { $0.replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression) }
}
```

**Step 3: Build and verify**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build`

**Step 4: Commit**

```
feat: integrate animated drill diagram into ExerciseDetailView
```

---

## Task 5: Active Training Drill Walkthrough

**Files:**
- Create: `TechnIQ/DrillWalkthroughView.swift`
- Modify: `TechnIQ/ActiveTrainingView.swift`

**Step 1: Create DrillWalkthroughView**

New view that wraps the animated diagram for active training use. Three phases: preview → perform → rate.

```swift
struct DrillWalkthroughView: View {
    let exercise: Exercise
    var onComplete: ((Int, String, String) -> Void)? // rating, difficulty, notes

    enum Phase { case preview, perform, rate }
    @State private var phase: Phase = .preview
    @State private var currentStep: Int? = 1
    @State private var isAutoPlaying: Bool = true
    @State private var playbackSpeed: Double = 1.0
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?

    // Rating state
    @State private var difficultyFeedback: String = "just_right"
    @State private var qualityRating: Int = 3
    @State private var feedbackNotes: String = ""
}
```

Key behaviors:
- **Preview phase:** AnimatedDrillDiagramView with `isAutoPlaying = true`, `isTrainingMode = false`. "Ready" button at bottom transitions to perform phase.
- **Perform phase:** AnimatedDrillDiagramView with `isAutoPlaying = false`, `isTrainingMode = true`. Timer runs in corner. `onStepCompleted` triggers haptic. After last step, shows "Complete Drill" button → transitions to rate phase.
- **Rate phase:** Difficulty picker (too easy / just right / too hard), star rating (1-5), notes field, "Done" button calls `onComplete`.

**Step 2: Integrate into ActiveTrainingView**

Modify `ActiveTrainingView.swift`'s `ExerciseStepView` to check if the exercise has `diagramJSON`. If yes, show `DrillWalkthroughView`. If no, show the existing text-based exercise view.

```swift
// In phaseContent, replace exerciseActive case:
case .exerciseActive:
    if let exercise = manager.currentExercise, exercise.diagramJSON != nil {
        DrillWalkthroughView(exercise: exercise) { rating, difficulty, notes in
            currentRating = rating
            currentNotes = notes
            manager.completeCurrentExercise()
        }
    } else {
        ExerciseStepView(manager: manager)
    }
```

**Step 3: Add haptics**

Use `UIImpactFeedbackGenerator` for step completion (light), drill completion (medium), and `UINotificationFeedbackGenerator` for session completion.

**Step 4: Build and verify**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build`

**Step 5: Commit**

```
feat: add drill walkthrough view with preview/perform/rate phases
```

---

## Task 6: Training Plan Integration — Mini Diagram Thumbnails

**Files:**
- Modify: `TechnIQ/TodaysTrainingView.swift`

**Step 1: Add mini diagram thumbnail to PlanSessionCard**

In the session card, add a small (80x60) static `AnimatedDrillDiagramView` thumbnail for exercises that have `diagramJSON`:

```swift
// Inside PlanSessionCard, after the session type icon:
if let firstExercise = sessionExercises.first,
   let diagramJSON = firstExercise.diagramJSON,
   let data = diagramJSON.data(using: .utf8),
   let diagram = try? JSONDecoder().decode(DrillDiagram.self, from: data) {
    AnimatedDrillDiagramView(
        diagram: diagram,
        instructions: [],
        currentStep: .constant(nil),
        isAutoPlaying: .constant(false)
    )
    .frame(width: 80, height: 60)
    .cornerRadius(DesignSystem.CornerRadius.sm)
    .allowsHitTesting(false)
}
```

**Step 2: Update "Start Session" to launch DrillWalkthroughView flow**

Modify the "Start Session" button handler: if exercises have diagrams, launch `ActiveTrainingView` which will automatically use `DrillWalkthroughView` (from Task 5).

**Step 3: Build and verify**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build`

**Step 4: Commit**

```
feat: add mini diagram thumbnails to training plan session cards
```

---

## Task 7: Session Summary Upgrade

**Files:**
- Modify: `TechnIQ/ActiveTrainingView.swift` (sessionCompleteContent section)

**Step 1: Enhance session complete view**

Replace the current session complete content with:
- Drills completed count, total time
- "You worked on:" section showing weakness categories from completed exercises
- Streak counter (query Core Data for consecutive sessions targeting same weakness)
- XP/coin awards (existing, just more prominent)
- "Generate Another Drill" shortcut button

**Step 2: Build and verify**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build`

**Step 3: Commit**

```
feat: enhanced session summary with weakness tracking and streaks
```

---

## Task 8: Weakness Analysis Engine

**Files:**
- Create: `TechnIQ/WeaknessAnalysisService.swift`

**Step 1: Create WeaknessAnalysisService**

Singleton service that analyzes player data to surface weakness suggestions:

```swift
class WeaknessAnalysisService {
    static let shared = WeaknessAnalysisService()

    func analyzeWeaknesses(for player: Player) -> WeaknessProfile {
        var suggestions: [SelectedWeakness] = []
        var sources: [String] = []

        // 1. Analyze match logs
        let matchWeaknesses = analyzeMatches(player)
        suggestions.append(contentsOf: matchWeaknesses.suggestions)
        if matchWeaknesses.matchCount > 0 {
            sources.append("\(matchWeaknesses.matchCount) matches")
        }

        // 2. Analyze session ratings
        let sessionWeaknesses = analyzeSessionRatings(player)
        suggestions.append(contentsOf: sessionWeaknesses.suggestions)
        if sessionWeaknesses.sessionCount > 0 {
            sources.append("\(sessionWeaknesses.sessionCount) sessions")
        }

        // 3. Analyze drill feedback
        let drillWeaknesses = analyzeDrillFeedback(player)
        suggestions.append(contentsOf: drillWeaknesses.suggestions)

        // Deduplicate and rank by frequency
        let ranked = rankAndDeduplicate(suggestions)

        return WeaknessProfile(
            suggestedWeaknesses: Array(ranked.prefix(3)),
            dataSources: sources,
            lastUpdated: Date()
        )
    }
}
```

Methods:
- `analyzeMatches(player)`: Fetch last 10 matches, extract weakness notes, map to WeaknessCategory/SubWeakness using keyword matching
- `analyzeSessionRatings(player)`: Fetch exercises rated <3/5 in recent sessions, group by category
- `analyzeDrillFeedback(player)`: Check RecommendationFeedback for negative ratings, extract skill categories

**Step 2: Cache results on Player.weaknessProfileJSON**

After analysis, encode the `WeaknessProfile` to JSON and store on the player. Re-analyze when a new match or session is logged.

**Step 3: Build and verify**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build`

**Step 4: Commit**

```
feat: weakness analysis engine with match/session/feedback data mining
```

---

## Task 9: Two-Tier Weakness Picker Component

**Files:**
- Create: `TechnIQ/WeaknessPickerView.swift`

**Step 1: Create WeaknessPickerView**

Reusable component for selecting weaknesses:

```swift
struct WeaknessPickerView: View {
    @Binding var selectedWeaknesses: [SelectedWeakness]
    @State private var expandedCategory: WeaknessCategory?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("What do you want to improve?")
                .font(DesignSystem.Typography.headlineSmall)

            // Tier 1: Category chips (horizontal scroll or 2-col grid)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSystem.Spacing.sm) {
                ForEach(WeaknessCategory.allCases) { category in
                    CategoryChip(category: category,
                                 isExpanded: expandedCategory == category,
                                 hasSelections: selectedWeaknesses.contains { $0.category == category.displayName })
                    .onTapGesture { toggleCategory(category) }
                }
            }

            // Tier 2: Sub-weaknesses for expanded category
            if let expanded = expandedCategory {
                subWeaknessGrid(for: expanded)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(DesignSystem.Animation.smooth, value: expandedCategory)
    }
}
```

**Step 2: Build and verify**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build`

**Step 3: Commit**

```
feat: two-tier weakness picker component with expand/collapse categories
```

---

## Task 10: Context-Aware Suggestions Card

**Files:**
- Create: `TechnIQ/WeaknessSuggestionsCard.swift`

**Step 1: Create the suggestion card component**

Shows "Suggested for You" based on WeaknessAnalysisService:

```swift
struct WeaknessSuggestionsCard: View {
    let player: Player
    @State private var profile: WeaknessProfile?
    var onWeaknessSelected: ((SelectedWeakness) -> Void)?

    var body: some View {
        if let profile = profile, !profile.suggestedWeaknesses.isEmpty {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                    Text("Suggested for You")
                        .font(DesignSystem.Typography.labelLarge)
                }

                Text("Based on your \(profile.dataSources.joined(separator: " and "))")
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                // Weakness pills
                FlowLayout(spacing: DesignSystem.Spacing.sm) {
                    ForEach(profile.suggestedWeaknesses, id: \.specific) { weakness in
                        Button {
                            onWeaknessSelected?(weakness)
                        } label: {
                            Text(weakness.specific)
                                .font(DesignSystem.Typography.labelMedium)
                                .padding(.horizontal, DesignSystem.Spacing.md)
                                .padding(.vertical, DesignSystem.Spacing.sm)
                                .background(DesignSystem.Colors.primaryGreen.opacity(0.15))
                                .foregroundColor(DesignSystem.Colors.primaryGreen)
                                .cornerRadius(DesignSystem.CornerRadius.pill)
                        }
                    }
                }
            }
            .padding(DesignSystem.Spacing.md)
            .cardStyle()
        } else {
            // Placeholder for new users
            // "Complete a few matches to get personalized suggestions"
        }
    }
}
```

**Step 2: Build and verify**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build`

**Step 3: Commit**

```
feat: context-aware weakness suggestions card from player data
```

---

## Task 11: Integrate Weakness Picker into Drill Generator

**Files:**
- Modify: `TechnIQ/CustomDrillGeneratorView.swift`
- Modify: `TechnIQ/CustomDrillModels.swift`

**Step 1: Add selectedWeaknesses to CustomDrillRequest**

```swift
struct CustomDrillRequest {
    var skillDescription: String
    var category: DrillCategory
    var difficulty: DifficultyLevel
    var equipment: Set<Equipment>
    var numberOfPlayers: Int
    var fieldSize: FieldSize
    var selectedWeaknesses: [SelectedWeakness]  // NEW
}
```

Update `CustomDrillRequest.empty` and `isValid` (valid if weaknesses selected OR skillDescription >= 10 chars).

**Step 2: Rebuild CustomDrillGeneratorView layout**

New form order:
1. `WeaknessSuggestionsCard` (top, pre-fills picker on tap)
2. `WeaknessPickerView` (replaces skill description as primary input)
3. "Anything else?" freeform text field (the old skill description, now optional)
4. Category, Difficulty, Equipment, Players, Field Size (existing)

**Step 3: Build and verify**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build`

**Step 4: Commit**

```
feat: integrate weakness picker and suggestions into drill generator
```

---

## Task 12: Smart Recommendations Dashboard Section

**Files:**
- Modify: `TechnIQ/DashboardView.swift` (or `TrainHubView.swift` depending on where it fits)
- Create: `TechnIQ/SmartDrillRecommendationsView.swift`

**Step 1: Create SmartDrillRecommendationsView**

"Drills For You" section showing 2-3 weakness-based drill suggestion cards:

```swift
struct SmartDrillRecommendationsView: View {
    let player: Player
    @State private var suggestions: [DrillSuggestion] = []
    @State private var showingGenerator = false
    @State private var selectedSuggestion: DrillSuggestion?

    struct DrillSuggestion: Identifiable {
        let id = UUID()
        let weakness: SelectedWeakness
        let title: String
        let description: String
        let difficulty: DifficultyLevel
    }
}
```

Each card: weakness name, brief description, difficulty tag, "Generate" button. Tapping "Generate" opens `CustomDrillGeneratorView` with the weakness pre-filled.

**Step 2: Add to dashboard/train hub**

Insert `SmartDrillRecommendationsView` into the appropriate dashboard section.

**Step 3: Build and verify**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build`

**Step 4: Commit**

```
feat: smart drill recommendations section on dashboard
```

---

## Task 13: Firebase Pipeline — Structured Weakness Input

**Files:**
- Modify: `functions/main.py` (Scout phase)
- Modify: `TechnIQ/CustomDrillService.swift` (payload construction)

**Step 1: Update client payload to include selected weaknesses**

In `CustomDrillService.swift`, in `callFirebaseCustomDrillFunction`, add `selected_weaknesses` to the request body:

```swift
if !request.selectedWeaknesses.isEmpty {
    body["selected_weaknesses"] = request.selectedWeaknesses.map {
        ["category": $0.category, "specific": $0.specific]
    }
}
```

**Step 2: Update Scout phase prompt in main.py**

Modify `phase_scout` to parse `selected_weaknesses` from `requirements`:

```python
# In phase_scout, after existing context building:
selected_weaknesses = requirements.get('selected_weaknesses', [])
if selected_weaknesses:
    weakness_text = "\n".join([f"- {w['category']}: {w['specific']}" for w in selected_weaknesses])
    # Add to prompt as structured input with higher priority than freeform
```

Update Scout prompt to:
1. Prioritize structured weaknesses over freeform `skill_description`
2. Map selected weaknesses to specific drill archetypes
3. Include anti-repetition: send last 5 drill names as "do not repeat"

**Step 3: Build and deploy functions**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build`
Run: `cd functions && firebase deploy --only functions`

**Step 4: Commit**

```
feat: structured weakness input in Scout phase, anti-repetition
```

---

## Task 14: Firebase Pipeline — Step-Indexed Paths + New Patterns

**Files:**
- Modify: `functions/main.py` (Coach, Writer, Referee phases)

**Step 1: Add new pattern types to Coach phase**

In `phase_coach`, expand the pattern_type options:

```python
# Current: zigzag, triangle, linear, gates, grid, free
# New: diamond, square, rondo_circle, channel, overlap_run, wall_pass_sequence
```

Add spatial rules for each new pattern in the Coach prompt.

**Step 2: Require step-indexed paths in Writer phase**

Update `phase_writer` prompt to require `"step": <int>` on every movement path:

```python
# In Writer prompt:
# "Every movement_path MUST include a 'step' integer (1-indexed) linking it to the corresponding instruction step."
```

Also require `variations` as structured array and `estimatedDuration` as top-level int.

Bump Writer temperature from 0.6 → 0.7.

**Step 3: Add step validation to Referee phase**

In `programmatic_validate`, add:
```python
# Check every instruction step has at least one matching path
instruction_count = len(drill.get('instructions', []))
paths = drill.get('diagram', {}).get('movement_paths', [])
for step_num in range(1, instruction_count + 1):
    if not any(p.get('step') == step_num for p in paths):
        errors.append({"check": "step_coverage", "issue": f"Step {step_num} has no associated movement path", "fix": f"Add a movement_path with step={step_num}"})
```

**Step 4: Deploy functions**

Run: `cd functions && firebase deploy --only functions`

**Step 5: Commit**

```
feat: step-indexed paths, new pattern types, step validation in Referee
```

---

## Task 15: Template Library Expansion

**Files:**
- Modify: `TechnIQ/TemplateExerciseLibrary.swift`

**Step 1: Add weak foot templates (8-10)**

Add exercise templates for weak foot skills: wall passes, shooting circuits, dribbling gates, crossing practice, etc.

**Step 2: Add defending templates (8-10)**

1v1 channel defending, recovery run drills, pressing triggers, aerial duel practice, etc.

**Step 3: Add under-pressure templates (8-10)**

Rondos (3v1, 4v2, 5v2), pressing escape drills, tight space turning, etc.

**Step 4: Add game-realistic templates (8-10)**

Counter-attack transitions, overlapping runs, switching play, build-up patterns, etc.

**Step 5: Add mental/decision templates (5-6)**

Scanning drills, decision gates, reaction-based passing, etc.

**Step 6: Build and verify**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build`

**Step 7: Commit**

```
feat: expand exercise template library from 45 to ~110 templates
```

---

## Task 16: Update QuickDrillSheet

**Files:**
- Modify: `TechnIQ/QuickDrillSheet.swift`

**Step 1: Add weakness-aware defaults**

Instead of always using `.technical` category and hardcoded defaults, have QuickDrillSheet:
- Accept optional `prefilledWeakness: SelectedWeakness?` parameter
- If weakness is provided, auto-set category based on weakness category mapping
- Pass `selectedWeaknesses` to `CustomDrillRequest`

**Step 2: Build and verify**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build`

**Step 3: Commit**

```
feat: weakness-aware QuickDrillSheet with category auto-mapping
```

---

## Task 17: Final Integration & Polish

**Files:**
- Multiple files for wiring and polish

**Step 1: Wire up dashboard → generator navigation with weakness pre-fill**

Ensure tapping a Smart Recommendation "Generate" button opens CustomDrillGeneratorView with the weakness pre-selected.

**Step 2: Ensure backward compatibility**

- Existing exercises without step data render diagrams in "all paths visible" mode
- Existing exercises without weakness tags are excluded from weakness filtering but appear in general library
- Old CustomDrillRequest payloads without `selected_weaknesses` still work in Firebase

**Step 3: Add deprecation wrapper for old DrillDiagramView**

```swift
// Keep for backward compat in any views still referencing it:
struct DrillDiagramView: View {
    let diagram: DrillDiagram
    var body: some View {
        AnimatedDrillDiagramView(
            diagram: diagram,
            instructions: [],
            currentStep: .constant(nil),
            isAutoPlaying: .constant(false)
        )
    }
}
```

**Step 4: Full build**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build`

**Step 5: Commit**

```
feat: final integration wiring and backward compatibility
```

---

## Summary

| Task | Description | Key Files |
|------|-------------|-----------|
| 1 | Core Data schema additions | DataModel.xcdatamodeld, CustomDrillModels.swift |
| 2 | Weakness data models | WeaknessModels.swift (new) |
| 3 | Animated field renderer | DrillDiagramView.swift (rewrite) |
| 4 | Integrate into ExerciseDetailView | ExerciseDetailView.swift |
| 5 | Active training drill walkthrough | DrillWalkthroughView.swift (new), ActiveTrainingView.swift |
| 6 | Training plan mini thumbnails | TodaysTrainingView.swift |
| 7 | Session summary upgrade | ActiveTrainingView.swift |
| 8 | Weakness analysis engine | WeaknessAnalysisService.swift (new) |
| 9 | Two-tier weakness picker | WeaknessPickerView.swift (new) |
| 10 | Context-aware suggestions card | WeaknessSuggestionsCard.swift (new) |
| 11 | Integrate picker into generator | CustomDrillGeneratorView.swift, CustomDrillModels.swift |
| 12 | Smart recommendations dashboard | SmartDrillRecommendationsView.swift (new), DashboardView.swift |
| 13 | Firebase: structured weakness input | main.py, CustomDrillService.swift |
| 14 | Firebase: step paths + new patterns | main.py |
| 15 | Template library expansion | TemplateExerciseLibrary.swift |
| 16 | QuickDrillSheet weakness awareness | QuickDrillSheet.swift |
| 17 | Final integration & polish | Multiple |
