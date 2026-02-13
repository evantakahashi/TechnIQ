# Adaptive AI Coach Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add AI-powered daily coaching (focus area + drill recommendation) and adaptive weekly plan check-ins that respond to player performance.

**Architecture:** New `AICoachService` (@MainActor singleton) calls 2 new Firebase Functions (`get_daily_coaching`, `get_plan_adaptation`). Dashboard gets a "Today's Focus" card. PlayerProgressView gets AI-powered insights. SessionCompleteView gets a weekly check-in prompt. All data cached in UserDefaults (no Core Data changes).

**Tech Stack:** SwiftUI, Firebase Auth, Firebase Functions (Python + OpenAI GPT-4), UserDefaults caching, existing DesignSystem/ModernComponents

**Design doc:** `docs/plans/2026-02-12-adaptive-ai-coach-design.md`

---

### Task 1: Data Models

**Files:**
- Create: `TechnIQ/AICoachModels.swift`

**Step 1: Create models file**

```swift
import Foundation

// MARK: - Daily Coaching Models

struct DailyCoaching: Codable {
    let focusArea: String
    let reasoning: String
    let recommendedDrill: RecommendedDrill
    let additionalTips: [String]
    let streakMessage: String?
    let insights: [AIInsight]
    let fetchDate: Date
}

struct RecommendedDrill: Codable {
    let name: String
    let description: String
    let category: String
    let difficulty: Int
    let duration: Int
    let steps: [String]
    let equipment: [String]
    let targetSkills: [String]
    let isFromLibrary: Bool
    let libraryExerciseID: String?
}

struct AIInsight: Codable {
    let title: String
    let description: String
    let type: String       // "celebration", "recommendation", "warning", "pattern"
    let priority: Int
    let actionable: String?
}

// MARK: - Plan Adaptation Models

struct PlanAdaptationResponse: Codable {
    let summary: String
    let adaptations: [PlanAdaptation]
}

struct PlanAdaptation: Codable {
    let type: String           // "add_session", "modify_difficulty", "remove_session", "swap_exercise"
    let day: Int
    let sessionIndex: Int?
    let description: String
    let drill: RecommendedDrill?
    let oldDifficulty: Int?
    let newDifficulty: Int?
}
```

**Step 2: Build**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add TechnIQ/AICoachModels.swift
git commit -m "feat: add AI coach data models"
```

**Note:** Add this file to the Xcode project. Use the Ruby `xcodeproj` gem pattern from previous tasks, or add manually. File references inside the TechnIQ group use relative paths (just the filename, not `TechnIQ/filename`).

---

### Task 2: AICoachService — Core Service

**Files:**
- Create: `TechnIQ/AICoachService.swift`

**Step 1: Create the service**

```swift
import Foundation
import FirebaseAuth
import CoreData

@MainActor
class AICoachService: ObservableObject {
    static let shared = AICoachService()

    @Published var dailyCoaching: DailyCoaching?
    @Published var aiInsights: [TrainingInsight] = []
    @Published var isLoading: Bool = false
    @Published var error: String?

    private let auth = Auth.auth()
    private let cacheKey = "cachedDailyCoaching"
    private let cacheDateKey = "dailyCoachingFetchDate"

    private init() {
        loadCachedCoaching()
    }

    // MARK: - Public API

    func fetchDailyCoachingIfNeeded(for player: Player) async {
        // Check if we already have today's coaching
        if let cached = dailyCoaching, Calendar.current.isDateInToday(cached.fetchDate) {
            return
        }

        isLoading = true
        error = nil

        do {
            let coaching = try await callDailyCoachingFunction(for: player)
            dailyCoaching = coaching
            aiInsights = coaching.insights.map { mapToTrainingInsight($0) }
            cacheCoaching(coaching)
        } catch {
            #if DEBUG
            print("❌ AICoachService: Failed to fetch coaching: \(error)")
            #endif
            self.error = error.localizedDescription
            // Keep showing yesterday's cached coaching if available
        }

        isLoading = false
    }

    // MARK: - Cache

    private func loadCachedCoaching() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return }
        do {
            let coaching = try JSONDecoder().decode(DailyCoaching.self, from: data)
            dailyCoaching = coaching
            aiInsights = coaching.insights.map { mapToTrainingInsight($0) }
        } catch {
            #if DEBUG
            print("⚠️ AICoachService: Failed to decode cached coaching: \(error)")
            #endif
        }
    }

    private func cacheCoaching(_ coaching: DailyCoaching) {
        do {
            let data = try JSONEncoder().encode(coaching)
            UserDefaults.standard.set(data, forKey: cacheKey)
        } catch {
            #if DEBUG
            print("⚠️ AICoachService: Failed to cache coaching: \(error)")
            #endif
        }
    }

    var isCacheStale: Bool {
        guard let coaching = dailyCoaching else { return true }
        return !Calendar.current.isDateInToday(coaching.fetchDate)
    }

    // MARK: - Insight Mapping

    private func mapToTrainingInsight(_ ai: AIInsight) -> TrainingInsight {
        let insightType: InsightType
        switch ai.type {
        case "celebration": insightType = .celebration
        case "warning": insightType = .warning
        case "recommendation": insightType = .recommendation
        case "pattern": insightType = .pattern
        default: insightType = .recommendation
        }

        return TrainingInsight(
            type: insightType,
            title: ai.title,
            description: ai.description,
            icon: iconForType(insightType),
            color: colorForType(insightType),
            priority: ai.priority,
            actionable: ai.actionable
        )
    }

    private func iconForType(_ type: InsightType) -> String {
        switch type {
        case .celebration: return "star.fill"
        case .warning: return "exclamationmark.triangle"
        case .recommendation: return "lightbulb.fill"
        case .pattern: return "chart.line.uptrend.xyaxis"
        case .achievement: return "trophy.fill"
        }
    }

    private func colorForType(_ type: InsightType) -> String {
        switch type {
        case .celebration: return "primaryGreen"
        case .warning: return "error"
        case .recommendation: return "secondaryBlue"
        case .pattern: return "accentOrange"
        case .achievement: return "accentYellow"
        }
    }

    // MARK: - Firebase Function Call

    private func callDailyCoachingFunction(for player: Player) async throws -> DailyCoaching {
        let functionsURL = "https://us-central1-techniq-b9a27.cloudfunctions.net/get_daily_coaching"

        guard let url = URL(string: functionsURL) else {
            throw URLError(.badURL)
        }

        let userUID = auth.currentUser?.uid ?? "anonymous_user"
        let playerContext = buildPlayerContext(for: player)

        let requestBody: [String: Any] = [
            "user_id": userUID,
            "player_profile": playerContext.profile,
            "recent_sessions": playerContext.sessions,
            "category_balance": playerContext.categoryBalance,
            "active_plan": playerContext.activePlan,
            "streak_days": Int(player.currentStreak),
            "days_since_last_session": playerContext.daysSinceLastSession,
            "total_sessions": player.sessions?.count ?? 0
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        // Add auth token
        if let user = auth.currentUser {
            let idToken = try await user.getIDToken()
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        // Single retry with 2s backoff
        var lastError: Error?
        for attempt in 0...1 {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                    throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: "Server returned \(statusCode)"])
                }

                // Parse response
                var coaching = try JSONDecoder().decode(DailyCoaching.self, from: data)
                // Server won't include fetchDate, so we set it client-side
                let mirror = coaching
                coaching = DailyCoaching(
                    focusArea: mirror.focusArea,
                    reasoning: mirror.reasoning,
                    recommendedDrill: mirror.recommendedDrill,
                    additionalTips: mirror.additionalTips,
                    streakMessage: mirror.streakMessage,
                    insights: mirror.insights,
                    fetchDate: Date()
                )
                return coaching
            } catch {
                lastError = error
                if attempt == 0 {
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                }
            }
        }
        throw lastError ?? URLError(.unknown)
    }

    // MARK: - Player Context Builder

    private struct PlayerContext {
        let profile: [String: Any]
        let sessions: [[String: Any]]
        let categoryBalance: [String: Int]
        let activePlan: [String: Any]
        let daysSinceLastSession: Int
    }

    private func buildPlayerContext(for player: Player) -> PlayerContext {
        // Profile (reuse pattern from CustomDrillService.buildPlayerProfile)
        var profile: [String: Any] = [
            "age": Int(player.age),
            "position": player.position ?? "Unknown",
            "experience": player.experienceLevel ?? "intermediate",
            "style": player.playingStyle ?? "",
            "dominant_foot": player.dominantFoot ?? ""
        ]

        if let pp = player.playerProfile {
            if let goals = pp.skillGoals, !goals.isEmpty {
                profile["goals"] = goals
            }
            if let weaknesses = pp.selfIdentifiedWeaknesses, !weaknesses.isEmpty {
                profile["weaknesses"] = weaknesses
            }
        }

        // Recent sessions (last 10)
        let allSessions = (player.sessions as? Set<TrainingSession>)?.sorted {
            ($0.date ?? .distantPast) > ($1.date ?? .distantPast)
        } ?? []
        let recentSessions = Array(allSessions.prefix(10))

        var sessionsData: [[String: Any]] = []
        for session in recentSessions {
            var sessionDict: [String: Any] = [
                "date": ISO8601DateFormatter().string(from: session.date ?? Date()),
                "duration_minutes": Int(session.duration),
                "overall_rating": Int(session.overallRating)
            ]

            var exercisesData: [[String: Any]] = []
            if let exercises = session.exercises as? Set<SessionExercise> {
                for se in exercises {
                    if let ex = se.exercise {
                        exercisesData.append([
                            "name": ex.name ?? "",
                            "category": ex.category ?? "",
                            "skills": ex.targetSkills ?? [],
                            "rating": Int(se.rating),
                            "duration": Int(se.duration)
                        ])
                    }
                }
            }
            sessionDict["exercises"] = exercisesData
            sessionsData.append(sessionDict)
        }

        // Category balance
        var technical = 0, physical = 0, tactical = 0
        for session in recentSessions {
            if let exercises = session.exercises as? Set<SessionExercise> {
                for se in exercises {
                    let cat = se.exercise?.category?.lowercased() ?? ""
                    if cat.contains("technical") { technical += 1 }
                    else if cat.contains("physical") { physical += 1 }
                    else if cat.contains("tactical") { tactical += 1 }
                }
            }
        }
        let total = max(technical + physical + tactical, 1)
        let categoryBalance: [String: Int] = [
            "technical": (technical * 100) / total,
            "physical": (physical * 100) / total,
            "tactical": (tactical * 100) / total
        ]

        // Active plan
        var activePlanDict: [String: Any] = [:]
        if let plan = TrainingPlanService.shared.fetchActivePlan(for: player) {
            activePlanDict = [
                "name": plan.name,
                "week": plan.currentWeek,
                "progress": plan.progressPercentage / 100.0
            ]
        }

        // Days since last session
        let daysSince: Int
        if let lastDate = allSessions.first?.date {
            daysSince = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
        } else {
            daysSince = 999
        }

        return PlayerContext(
            profile: profile,
            sessions: sessionsData,
            categoryBalance: categoryBalance,
            activePlan: activePlanDict,
            daysSinceLastSession: daysSince
        )
    }
}
```

**Step 2: Add to Xcode project and build**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add TechnIQ/AICoachService.swift
git commit -m "feat: add AICoachService with daily coaching fetch and caching"
```

---

### Task 3: Firebase Function — `get_daily_coaching`

**Files:**
- Modify: `functions/main.py` (add new endpoint after `generate_training_plan`, ~line 1443)

**Step 1: Add the endpoint**

Add after the `generate_training_plan` function (after line 1443 in `functions/main.py`):

```python
@https_fn.on_request(timeout_sec=60)
def get_daily_coaching(req: https_fn.Request) -> https_fn.Response:
    """
    Generate daily coaching recommendation based on player context.
    Returns focus area, reasoning, recommended drill, tips, and AI insights.
    """
    try:
        # Handle CORS preflight
        if req.method == 'OPTIONS':
            return https_fn.Response(
                "",
                status=200,
                headers={
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Methods': 'POST, OPTIONS',
                    'Access-Control-Allow-Headers': 'Content-Type, Authorization'
                }
            )

        if req.method != 'POST':
            return https_fn.Response("Method not allowed", status=405)

        # Auth verification (same pattern as existing endpoints)
        auth_header = req.headers.get('Authorization')
        allow_unauth = os.environ.get("ALLOW_UNAUTHENTICATED", "false") == "true"
        if auth_header and auth_header.startswith('Bearer '):
            try:
                id_token = auth_header.split('Bearer ')[1]
                decoded_token = auth.verify_id_token(id_token)
                logger.info(f"🔐 Authenticated user: {decoded_token['uid']}")
            except Exception as e:
                if not allow_unauth:
                    return https_fn.Response(json.dumps({"error": "Invalid authentication token"}), status=401, headers={'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'})
        elif not allow_unauth:
            return https_fn.Response(json.dumps({"error": "Authentication required"}), status=401, headers={'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'})

        request_data = req.get_json()
        if not request_data:
            return https_fn.Response("Invalid JSON", status=400)

        player_profile = request_data.get('player_profile', {})
        recent_sessions = request_data.get('recent_sessions', [])
        category_balance = request_data.get('category_balance', {})
        active_plan = request_data.get('active_plan', {})
        streak_days = request_data.get('streak_days', 0)
        days_since_last = request_data.get('days_since_last_session', 0)
        total_sessions = request_data.get('total_sessions', 0)

        logger.info(f"🎯 Generating daily coaching for user with {len(recent_sessions)} recent sessions")

        openai_api_key = os.environ.get('OPENAI_API_KEY')
        if not openai_api_key:
            return https_fn.Response(json.dumps({"error": "OpenAI API key not configured"}), status=500, headers={'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'})

        from openai import OpenAI
        client = OpenAI(api_key=openai_api_key)

        # Build session summary for prompt
        session_text = ""
        for s in recent_sessions[:10]:
            session_text += f"- {s.get('date', '?')}: {s.get('duration_minutes', 0)}min, rated {s.get('overall_rating', 0)}/5\n"
            for ex in s.get('exercises', []):
                session_text += f"  - {ex.get('name', '?')} ({ex.get('category', '?')}): skills={ex.get('skills', [])}, rated {ex.get('rating', 0)}/5\n"

        balance_text = f"Technical: {category_balance.get('technical', 0)}%, Physical: {category_balance.get('physical', 0)}%, Tactical: {category_balance.get('tactical', 0)}%"

        plan_text = ""
        if active_plan:
            plan_text = f"Active plan: {active_plan.get('name', 'Unknown')}, Week {active_plan.get('week', '?')}, {active_plan.get('progress', 0)*100:.0f}% complete"

        streak_text = f"Current streak: {streak_days} days. Days since last session: {days_since_last}. Total sessions: {total_sessions}."

        prompt = f"""Analyze this soccer player's recent training and provide today's coaching recommendation.

Player: Age {player_profile.get('age', '?')}, {player_profile.get('position', '?')}, {player_profile.get('experience', 'intermediate')} level
Style: {player_profile.get('style', 'unknown')}, Dominant foot: {player_profile.get('dominant_foot', 'unknown')}
Goals: {', '.join(player_profile.get('goals', []))}
Weaknesses: {', '.join(player_profile.get('weaknesses', []))}

Recent sessions (newest first):
{session_text or 'No sessions yet'}

Category balance: {balance_text}
{plan_text}
{streak_text}

Instructions:
1. Identify the ONE most important focus area based on skill rating trends, category imbalance, or neglected weaknesses
2. Provide 2-sentence reasoning with specific data points (e.g. "Your passing ratings dropped from 3.6 to 2.8")
3. Design a specific drill targeting this focus area, appropriate for the player's level
4. Give 1-3 actionable coaching tips
5. Generate 1-2 data-backed insights (celebrations for improvements, warnings for declines, recommendations for imbalances)
6. If streak > 3, include a brief motivational streak message

Return ONLY valid JSON:
{{"focus_area": "Passing", "reasoning": "Your passing ratings...", "recommended_drill": {{"name": "Short name", "description": "One sentence", "category": "technical", "difficulty": 3, "duration": 15, "steps": ["Step 1", "Step 2"], "equipment": ["ball", "cones"], "target_skills": ["passing", "first touch"], "is_from_library": false, "library_exercise_id": null}}, "additional_tips": ["Tip 1"], "streak_message": "5 days strong!", "insights": [{{"title": "Title", "description": "Description with data", "type": "celebration|recommendation|warning|pattern", "priority": 9, "actionable": "Optional action"}}]}}"""

        response = client.chat.completions.create(
            model="gpt-4-turbo",
            messages=[
                {"role": "system", "content": "You are an expert soccer coach providing daily personalized training guidance. Be concise, data-driven, and actionable. Focus on the most impactful improvement area."},
                {"role": "user", "content": prompt}
            ],
            max_tokens=1200,
            temperature=0.4
        )

        result = parse_llm_json(response.choices[0].message.content)

        logger.info(f"✅ Daily coaching generated: focus={result.get('focus_area', '?')}")
        return https_fn.Response(
            json.dumps(result),
            status=200,
            headers={
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, Authorization'
            }
        )

    except Exception as e:
        logger.error(f"❌ Error in get_daily_coaching: {str(e)}")
        logger.error(traceback.format_exc())
        return https_fn.Response(
            json.dumps({"error": str(e)}),
            status=500,
            headers={
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, Authorization'
            }
        )
```

**Step 2: Commit**

```bash
git add functions/main.py
git commit -m "feat: add get_daily_coaching Firebase Function endpoint"
```

---

### Task 4: TodaysFocusCard — Dashboard Card

**Files:**
- Create: `TechnIQ/TodaysFocusCard.swift`

**Step 1: Create the card view**

```swift
import SwiftUI

struct TodaysFocusCard: View {
    let coaching: DailyCoaching
    let isStale: Bool
    let onStartDrill: () -> Void
    let onBrowseLibrary: () -> Void

    var body: some View {
        ModernCard(accentEdge: .leading, accentColor: DesignSystem.Colors.primaryGreen) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                // Header
                HStack {
                    Image(systemName: "scope")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                    Text("TODAY'S FOCUS")
                        .font(DesignSystem.Typography.labelMedium)
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                        .fontWeight(.bold)

                    Spacer()

                    if isStale {
                        Text("Updated yesterday")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                }

                // AI Reasoning
                Text(coaching.reasoning)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                // Drill Preview Card
                drillPreview

                // Tips
                if let firstTip = coaching.additionalTips.first {
                    HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "lightbulb.fill")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.accentYellow)
                        Text(firstTip)
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }

                // Action Buttons
                VStack(spacing: DesignSystem.Spacing.sm) {
                    ModernButton("Start Drill", icon: "play.fill", style: .primary) {
                        onStartDrill()
                    }

                    ModernButton("Browse Library", icon: "books.vertical", style: .ghost) {
                        onBrowseLibrary()
                    }
                }
            }
        }
        .a11y(
            label: "Today's focus: \(coaching.focusArea). \(coaching.reasoning)",
            trait: .isStaticText
        )
    }

    private var drillPreview: some View {
        let drill = coaching.recommendedDrill

        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(drill.name)
                .font(DesignSystem.Typography.titleSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .fontWeight(.semibold)

            HStack(spacing: DesignSystem.Spacing.md) {
                Text(drill.category.capitalized)
                    .font(DesignSystem.Typography.labelSmall)
                    .foregroundColor(DesignSystem.Colors.primaryGreen)

                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { i in
                        Image(systemName: i < drill.difficulty ? "star.fill" : "star")
                            .font(.caption2)
                            .foregroundColor(DesignSystem.Colors.accentYellow)
                    }
                }

                Text("\(drill.duration) min")
                    .font(DesignSystem.Typography.labelSmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            // Skill tags
            HStack(spacing: DesignSystem.Spacing.xs) {
                ForEach(drill.targetSkills.prefix(3), id: \.self) { skill in
                    Text(skill)
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(DesignSystem.Colors.primaryGreen.opacity(0.1))
                        .cornerRadius(DesignSystem.CornerRadius.sm)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surfaceOverlay)
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
}

// MARK: - Loading Skeleton

struct TodaysFocusCardSkeleton: View {
    @State private var isAnimating = false

    var body: some View {
        ModernCard(accentEdge: .leading, accentColor: DesignSystem.Colors.primaryGreen) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(DesignSystem.Colors.surfaceHighlight)
                        .frame(width: 140, height: 16)
                    Spacer()
                }

                RoundedRectangle(cornerRadius: 4)
                    .fill(DesignSystem.Colors.surfaceHighlight)
                    .frame(height: 40)

                RoundedRectangle(cornerRadius: 8)
                    .fill(DesignSystem.Colors.surfaceHighlight)
                    .frame(height: 80)

                RoundedRectangle(cornerRadius: 12)
                    .fill(DesignSystem.Colors.surfaceHighlight)
                    .frame(height: 44)
            }
            .opacity(isAnimating ? 0.4 : 0.8)
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
            .onAppear { isAnimating = true }
        }
    }
}
```

**Step 2: Build**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Note:** The `ModernCard(accentEdge:accentColor:)` initializer was added in the UI foundation upgrade. If it doesn't exist, use `ModernCard { ... }` with a manual leading border overlay. Check `ModernComponents.swift` for exact signature.

**Step 3: Commit**

```bash
git add TechnIQ/TodaysFocusCard.swift
git commit -m "feat: add TodaysFocusCard dashboard component"
```

---

### Task 5: Integrate TodaysFocusCard into DashboardView

**Files:**
- Modify: `TechnIQ/DashboardView.swift`

**Step 1: Add AICoachService StateObject**

In `DashboardView`, after line 42 (`@StateObject private var cloudMLService = CloudMLService.shared`), add:

```swift
@StateObject private var aiCoachService = AICoachService.shared
```

**Step 2: Add state for drill launch**

After line 54 (`@State private var quickStartExercises: [Exercise] = []`), add:

```swift
@State private var aiDrillExercise: Exercise?
@State private var showingAIDrill = false
```

**Step 3: Insert TodaysFocusCard into body**

In the `LazyVStack` body (line 67-78), insert between `modernStatsOverview` and `continuePlanCard`:

```swift
modernStatsOverview(player: player)
todaysFocusSection(player: player)  // NEW
continuePlanCard(player: player)
```

**Step 4: Add the section method**

Add this private method to DashboardView (after `modernStatsOverview`):

```swift
@ViewBuilder
private func todaysFocusSection(player: Player) -> some View {
    if aiCoachService.isLoading {
        TodaysFocusCardSkeleton()
    } else if let coaching = aiCoachService.dailyCoaching {
        TodaysFocusCard(
            coaching: coaching,
            isStale: aiCoachService.isCacheStale,
            onStartDrill: {
                launchAIDrill(coaching.recommendedDrill, for: player)
            },
            onBrowseLibrary: {
                selectedTab = 2 // Navigate to Exercise Library tab
            }
        )
    }
    // If no coaching and not loading, card is hidden entirely
}
```

**Step 5: Add drill launch helper**

Add this method to DashboardView:

```swift
private func launchAIDrill(_ drill: RecommendedDrill, for player: Player) {
    // If drill references a library exercise, fetch it
    if drill.isFromLibrary, let idString = drill.libraryExerciseID, let uuid = UUID(uuidString: idString) {
        let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        request.fetchLimit = 1
        if let existing = try? viewContext.fetch(request).first {
            quickStartExercises = [existing]
            showingActiveTraining = true
            return
        }
    }

    // Otherwise create a temporary exercise from the AI drill
    let exercise = Exercise(context: viewContext)
    exercise.id = UUID()
    exercise.name = drill.name
    exercise.exerciseDescription = "AI Coach Recommendation: \(drill.description)"
    exercise.category = drill.category
    exercise.difficulty = Int16(drill.difficulty)
    exercise.targetSkills = drill.targetSkills
    exercise.instructions = drill.steps.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
    exercise.player = player

    try? viewContext.save()
    quickStartExercises = [exercise]
    showingActiveTraining = true
}
```

**Step 6: Add coaching fetch to onAppear**

In the `.onAppear` block (line 125-129), add after `loadActivePlan()`:

```swift
if let player = currentPlayer {
    Task {
        await aiCoachService.fetchDailyCoachingIfNeeded(for: player)
    }
}
```

**Step 7: Build**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 8: Commit**

```bash
git add TechnIQ/DashboardView.swift
git commit -m "feat: integrate TodaysFocusCard into dashboard"
```

---

### Task 6: AI Insights in PlayerProgressView

**Files:**
- Modify: `TechnIQ/PlayerProgressView.swift`

**Step 1: Add AICoachService reference**

At the top of `PlayerProgressView` struct, add a new property (after the existing `@State` properties around line 14):

```swift
@StateObject private var aiCoachService = AICoachService.shared
```

**Step 2: Modify loadProgressData to prepend AI insights**

In `loadProgressData()` (line 386-405), replace the insights generation section:

```swift
// Generate smart insights — AI first, then rule-based fallback
let ruleBasedInsights = InsightsEngine.shared.generateInsights(
    for: player,
    sessions: sessions,
    timeRange: selectedTimeRange
)

let aiInsights = aiCoachService.aiInsights
if !aiInsights.isEmpty {
    // Deduplicate: skip rule-based insights of types already covered by AI
    let aiTypes = Set(aiInsights.map { $0.type })
    let filteredRuleBased = ruleBasedInsights.filter { !aiTypes.contains($0.type) }
    trainingInsights = (aiInsights + filteredRuleBased).sorted { $0.priority > $1.priority }
} else {
    trainingInsights = ruleBasedInsights
}
```

**Step 3: Build**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add TechnIQ/PlayerProgressView.swift
git commit -m "feat: prepend AI insights in PlayerProgressView"
```

---

### Task 7: Firebase Function — `get_plan_adaptation`

**Files:**
- Modify: `functions/main.py` (add after `get_daily_coaching`)

**Step 1: Add the endpoint**

Add after `get_daily_coaching` in `main.py`:

```python
@https_fn.on_request(timeout_sec=60)
def get_plan_adaptation(req: https_fn.Request) -> https_fn.Response:
    """
    Review a completed plan week and propose adaptations for the next week.
    """
    try:
        if req.method == 'OPTIONS':
            return https_fn.Response("", status=200, headers={'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'POST, OPTIONS', 'Access-Control-Allow-Headers': 'Content-Type, Authorization'})

        if req.method != 'POST':
            return https_fn.Response("Method not allowed", status=405)

        # Auth verification
        auth_header = req.headers.get('Authorization')
        allow_unauth = os.environ.get("ALLOW_UNAUTHENTICATED", "false") == "true"
        if auth_header and auth_header.startswith('Bearer '):
            try:
                id_token = auth_header.split('Bearer ')[1]
                decoded_token = auth.verify_id_token(id_token)
                logger.info(f"🔐 Authenticated user: {decoded_token['uid']}")
            except Exception as e:
                if not allow_unauth:
                    return https_fn.Response(json.dumps({"error": "Invalid authentication token"}), status=401, headers={'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'})
        elif not allow_unauth:
            return https_fn.Response(json.dumps({"error": "Authentication required"}), status=401, headers={'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'})

        request_data = req.get_json()
        if not request_data:
            return https_fn.Response("Invalid JSON", status=400)

        player_profile = request_data.get('player_profile', {})
        plan_structure = request_data.get('plan_structure', {})
        completed_week = request_data.get('completed_week', {})
        week_number = request_data.get('week_number', 1)

        logger.info(f"📊 Generating plan adaptation for week {week_number}")

        openai_api_key = os.environ.get('OPENAI_API_KEY')
        if not openai_api_key:
            return https_fn.Response(json.dumps({"error": "OpenAI API key not configured"}), status=500, headers={'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'})

        from openai import OpenAI
        client = OpenAI(api_key=openai_api_key)

        # Build context
        week_summary = ""
        sessions_completed = 0
        total_sessions = 0
        ratings = []

        for day in completed_week.get('days', []):
            for session in day.get('sessions', []):
                total_sessions += 1
                if session.get('completed', False):
                    sessions_completed += 1
                    if session.get('rating'):
                        ratings.append(session['rating'])
                week_summary += f"- Day {day.get('day_number', '?')}: {session.get('type', '?')}, "
                week_summary += f"{'completed' if session.get('completed') else 'skipped'}"
                if session.get('rating'):
                    week_summary += f", rated {session['rating']}/5"
                week_summary += "\n"
                for ex in session.get('exercises', []):
                    week_summary += f"  - {ex.get('name', '?')}: rated {ex.get('rating', '?')}/5, skills: {ex.get('skills', [])}\n"

        avg_rating = sum(ratings) / len(ratings) if ratings else 0

        prompt = f"""Review this completed training plan week and propose specific adaptations for next week.

Player: Age {player_profile.get('age', '?')}, {player_profile.get('position', '?')}, {player_profile.get('experience', 'intermediate')}
Plan: {plan_structure.get('name', 'Unknown')}
Week {week_number} completed: {sessions_completed}/{total_sessions} sessions, avg rating {avg_rating:.1f}/5

Week details:
{week_summary or 'No data'}

Next week's current plan:
{json.dumps(plan_structure.get('next_week', {}), indent=2)}

Instructions:
1. Summarize the week in 2-3 sentences (what went well, what needs work)
2. Propose 1-3 specific adaptations for next week based on performance data
3. Each adaptation should be one of: add_session, modify_difficulty, remove_session, swap_exercise
4. Be conservative — only propose changes backed by clear data signals

Return ONLY valid JSON:
{{"summary": "Week summary...", "adaptations": [{{"type": "modify_difficulty", "day": 2, "session_index": 0, "description": "Bump dribbling difficulty from 3 to 4", "old_difficulty": 3, "new_difficulty": 4, "drill": null}}, {{"type": "add_session", "day": 3, "session_index": null, "description": "Add passing drill", "old_difficulty": null, "new_difficulty": null, "drill": {{"name": "Wall Pass Combos", "description": "...", "category": "technical", "difficulty": 3, "duration": 15, "steps": ["Step 1"], "equipment": ["ball", "wall"], "target_skills": ["passing"], "is_from_library": false, "library_exercise_id": null}}}}]}}"""

        response = client.chat.completions.create(
            model="gpt-4-turbo",
            messages=[
                {"role": "system", "content": "You are a soccer training plan analyst. Review weekly performance data and propose minimal, data-driven adaptations. Be conservative — only change what the data clearly supports."},
                {"role": "user", "content": prompt}
            ],
            max_tokens=1000,
            temperature=0.3
        )

        result = parse_llm_json(response.choices[0].message.content)

        logger.info(f"✅ Plan adaptation generated: {len(result.get('adaptations', []))} changes proposed")
        return https_fn.Response(
            json.dumps(result),
            status=200,
            headers={
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, Authorization'
            }
        )

    except Exception as e:
        logger.error(f"❌ Error in get_plan_adaptation: {str(e)}")
        logger.error(traceback.format_exc())
        return https_fn.Response(
            json.dumps({"error": str(e)}),
            status=500,
            headers={
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, Authorization'
            }
        )
```

**Step 2: Commit**

```bash
git add functions/main.py
git commit -m "feat: add get_plan_adaptation Firebase Function endpoint"
```

---

### Task 8: AICoachService — Plan Adaptation Methods

**Files:**
- Modify: `TechnIQ/AICoachService.swift`

**Step 1: Add plan adaptation properties and methods**

Add to `AICoachService` class, after the existing `isCacheStale` property:

```swift
// MARK: - Plan Adaptation

@Published var weeklyCheckInAvailable: Bool = false
@Published var completedWeekNumber: Int = 0
@Published var adaptationResponse: PlanAdaptationResponse?
@Published var isLoadingAdaptation: Bool = false
@Published var adaptationError: String?

func setWeeklyCheckInAvailable(weekNumber: Int) {
    completedWeekNumber = weekNumber
    weeklyCheckInAvailable = true
}

func fetchPlanAdaptation(for player: Player, plan: TrainingPlanModel, weekNumber: Int) async {
    isLoadingAdaptation = true
    adaptationError = nil

    do {
        adaptationResponse = try await callPlanAdaptationFunction(for: player, plan: plan, weekNumber: weekNumber)
    } catch {
        #if DEBUG
        print("❌ AICoachService: Failed to fetch plan adaptation: \(error)")
        #endif
        adaptationError = error.localizedDescription
    }

    isLoadingAdaptation = false
}

func dismissWeeklyCheckIn() {
    weeklyCheckInAvailable = false
    adaptationResponse = nil
}

private func callPlanAdaptationFunction(for player: Player, plan: TrainingPlanModel, weekNumber: Int) async throws -> PlanAdaptationResponse {
    let functionsURL = "https://us-central1-techniq-b9a27.cloudfunctions.net/get_plan_adaptation"

    guard let url = URL(string: functionsURL) else {
        throw URLError(.badURL)
    }

    let userUID = auth.currentUser?.uid ?? "anonymous_user"
    let playerContext = buildPlayerContext(for: player)

    // Build completed week data
    var completedWeekData: [String: Any] = ["days": []]
    var nextWeekData: [String: Any] = [:]

    if let completedWeek = plan.weeks.first(where: { $0.weekNumber == weekNumber }) {
        var daysData: [[String: Any]] = []
        for day in completedWeek.days.sorted(by: { $0.dayNumber < $1.dayNumber }) {
            var sessionsData: [[String: Any]] = []
            for session in day.sessions {
                var sessionDict: [String: Any] = [
                    "type": session.sessionType.rawValue,
                    "completed": session.isCompleted,
                    "duration": session.duration,
                    "intensity": session.intensity
                ]
                if session.isCompleted {
                    sessionDict["rating"] = session.actualIntensity
                }
                sessionsData.append(sessionDict)
            }
            daysData.append([
                "day_number": day.dayNumber,
                "is_rest_day": day.isRestDay,
                "sessions": sessionsData
            ])
        }
        completedWeekData["days"] = daysData
    }

    // Next week structure
    if let nextWeek = plan.weeks.first(where: { $0.weekNumber == weekNumber + 1 }) {
        var daysData: [[String: Any]] = []
        for day in nextWeek.days.sorted(by: { $0.dayNumber < $1.dayNumber }) {
            var sessionsData: [[String: Any]] = []
            for session in day.sessions {
                sessionsData.append([
                    "type": session.sessionType.rawValue,
                    "duration": session.duration,
                    "intensity": session.intensity
                ])
            }
            daysData.append([
                "day_number": day.dayNumber,
                "is_rest_day": day.isRestDay,
                "sessions": sessionsData
            ])
        }
        nextWeekData = ["days": daysData]
    }

    let requestBody: [String: Any] = [
        "user_id": userUID,
        "player_profile": playerContext.profile,
        "plan_structure": [
            "name": plan.name,
            "next_week": nextWeekData
        ],
        "completed_week": completedWeekData,
        "week_number": weekNumber
    ]

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.timeoutInterval = 30

    if let user = auth.currentUser {
        let idToken = try await user.getIDToken()
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
    }

    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
        throw URLError(.badServerResponse)
    }

    return try JSONDecoder().decode(PlanAdaptationResponse.self, from: data)
}
```

**Step 2: Build**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add TechnIQ/AICoachService.swift
git commit -m "feat: add plan adaptation methods to AICoachService"
```

---

### Task 9: WeeklyCheckInView

**Files:**
- Create: `TechnIQ/WeeklyCheckInView.swift`

**Step 1: Create the view**

```swift
import SwiftUI

struct WeeklyCheckInView: View {
    let weekNumber: Int
    let player: Player
    @StateObject private var aiCoachService = AICoachService.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        if aiCoachService.isLoadingAdaptation {
                            loadingState
                        } else if let response = aiCoachService.adaptationResponse {
                            reviewContent(response)
                        } else if let error = aiCoachService.adaptationError {
                            errorState(error)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                    .padding(.vertical, DesignSystem.Spacing.xl)
                }
            }
            .navigationTitle("Week \(weekNumber) Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear {
            if let plan = TrainingPlanService.shared.fetchActivePlan(for: player) {
                Task {
                    await aiCoachService.fetchPlanAdaptation(for: player, plan: plan, weekNumber: weekNumber)
                }
            }
        }
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Analyzing your week...")
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .padding(.top, 80)
    }

    // MARK: - Error State

    private func errorState(_ error: String) -> some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Text("Couldn't reach AI coach")
                .font(DesignSystem.Typography.titleSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Text("You can retry or keep your current plan.")
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            HStack(spacing: DesignSystem.Spacing.md) {
                ModernButton("Retry", icon: "arrow.clockwise", style: .secondary) {
                    if let plan = TrainingPlanService.shared.fetchActivePlan(for: player) {
                        Task {
                            await aiCoachService.fetchPlanAdaptation(for: player, plan: plan, weekNumber: weekNumber)
                        }
                    }
                }

                ModernButton("Keep Plan", style: .ghost) {
                    aiCoachService.dismissWeeklyCheckIn()
                    dismiss()
                }
            }
        }
        .padding(.top, 60)
    }

    // MARK: - Review Content

    private func reviewContent(_ response: PlanAdaptationResponse) -> some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            // Week summary
            ModernCard(accentEdge: .leading, accentColor: DesignSystem.Colors.accentYellow) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(DesignSystem.Colors.accentYellow)
                        Text("WEEK \(weekNumber) REVIEW")
                            .font(DesignSystem.Typography.labelMedium)
                            .foregroundColor(DesignSystem.Colors.accentYellow)
                            .fontWeight(.bold)
                    }

                    Text(response.summary)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Proposed changes
            if !response.adaptations.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Proposed Changes for Week \(weekNumber + 1)")
                        .font(DesignSystem.Typography.headlineSmall)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .fontWeight(.bold)

                    ForEach(Array(response.adaptations.enumerated()), id: \.offset) { _, adaptation in
                        adaptationRow(adaptation)
                    }
                }
            }

            // Action buttons
            VStack(spacing: DesignSystem.Spacing.sm) {
                ModernButton("Apply Changes", icon: "checkmark.circle", style: .primary) {
                    applyAdaptations(response.adaptations)
                }

                ModernButton("Keep Original Plan", icon: "xmark.circle", style: .ghost) {
                    aiCoachService.dismissWeeklyCheckIn()
                    dismiss()
                }
            }
        }
    }

    private func adaptationRow(_ adaptation: PlanAdaptation) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            Image(systemName: iconForAdaptationType(adaptation.type))
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(colorForAdaptationType(adaptation.type))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(adaptation.description)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text("Day \(adaptation.day)")
                    .font(DesignSystem.Typography.labelSmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surfaceRaised)
        .cornerRadius(DesignSystem.CornerRadius.md)
    }

    private func iconForAdaptationType(_ type: String) -> String {
        switch type {
        case "add_session": return "plus.circle.fill"
        case "modify_difficulty": return "arrow.up.circle.fill"
        case "remove_session": return "minus.circle.fill"
        case "swap_exercise": return "arrow.triangle.swap"
        default: return "circle.fill"
        }
    }

    private func colorForAdaptationType(_ type: String) -> Color {
        switch type {
        case "add_session": return DesignSystem.Colors.primaryGreen
        case "modify_difficulty": return DesignSystem.Colors.accentOrange
        case "remove_session": return DesignSystem.Colors.error
        case "swap_exercise": return DesignSystem.Colors.secondaryBlue
        default: return DesignSystem.Colors.textSecondary
        }
    }

    // MARK: - Apply Adaptations

    private func applyAdaptations(_ adaptations: [PlanAdaptation]) {
        guard let plan = TrainingPlanService.shared.fetchActivePlan(for: player) else { return }

        // Apply each adaptation via TrainingPlanService
        for adaptation in adaptations {
            TrainingPlanService.shared.applyAdaptation(adaptation, to: plan, targetWeek: weekNumber + 1)
        }

        aiCoachService.dismissWeeklyCheckIn()
        HapticManager.shared.success()
        dismiss()
    }
}
```

**Step 2: Build**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build 2>&1 | tail -5`
Expected: May fail — `TrainingPlanService.applyAdaptation` doesn't exist yet. That's Task 10.

**Step 3: Commit**

```bash
git add TechnIQ/WeeklyCheckInView.swift
git commit -m "feat: add WeeklyCheckInView for plan adaptation"
```

---

### Task 10: TrainingPlanService — Adaptation + Week Completion Hook

**Files:**
- Modify: `TechnIQ/TrainingPlanService.swift`

**Step 1: Add `applyAdaptation` method**

Add after `checkAndMarkWeekCompleted` (around line 435):

```swift
// MARK: - Plan Adaptation

func applyAdaptation(_ adaptation: PlanAdaptation, to planModel: TrainingPlanModel, targetWeek: Int) {
    // Find the plan entity
    let request: NSFetchRequest<TrainingPlan> = TrainingPlan.fetchRequest()
    request.predicate = NSPredicate(format: "id == %@", planModel.id as CVarArg)
    request.fetchLimit = 1

    guard let plan = try? context.fetch(request).first else { return }

    // Find the target week
    let weeks = (plan.weeks?.allObjects as? [PlanWeek]) ?? []
    guard let week = weeks.first(where: { $0.weekNumber == Int16(targetWeek) }) else { return }

    let days = (week.days?.allObjects as? [PlanDay]) ?? []

    switch adaptation.type {
    case "modify_difficulty":
        // Find the session and update its intensity
        if let day = days.first(where: { $0.dayNumber == Int16(adaptation.day) }),
           let sessionIndex = adaptation.sessionIndex {
            let sessions = ((day.sessions?.allObjects as? [PlanSession]) ?? []).sorted { $0.orderIndex < $1.orderIndex }
            if sessionIndex < sessions.count, let newDiff = adaptation.newDifficulty {
                sessions[sessionIndex].intensity = Int16(newDiff)
            }
        }

    case "add_session":
        // Add a new session to the specified day
        if let day = days.first(where: { $0.dayNumber == Int16(adaptation.day) }),
           let drill = adaptation.drill {
            let sessionType = SessionType(rawValue: drill.category.capitalized) ?? .technical
            // Match or create exercise
            let exercises = matchExercisesFromLibrary(
                suggestedNames: [drill.name],
                sessionType: sessionType,
                for: plan.player!
            )
            _ = addSessionToDay(
                day,
                sessionType: sessionType,
                duration: drill.duration,
                intensity: drill.difficulty,
                notes: "AI Coach: \(adaptation.description)",
                exercises: exercises
            )
        }

    case "remove_session":
        if let day = days.first(where: { $0.dayNumber == Int16(adaptation.day) }),
           let sessionIndex = adaptation.sessionIndex {
            let sessions = ((day.sessions?.allObjects as? [PlanSession]) ?? []).sorted { $0.orderIndex < $1.orderIndex }
            if sessionIndex < sessions.count {
                context.delete(sessions[sessionIndex])
            }
        }

    default:
        break
    }

    plan.updatedAt = Date()
    do {
        try context.save()
    } catch {
        #if DEBUG
        print("❌ TrainingPlanService: Failed to apply adaptation: \(error)")
        #endif
    }
}
```

**Step 2: Add weekly check-in trigger to `checkAndMarkWeekCompleted`**

Modify `checkAndMarkWeekCompleted` (line 422-435) to notify AICoachService when a week completes. Add after `week.completedAt = Date()` (line 428):

```swift
// Trigger weekly check-in
Task { @MainActor in
    AICoachService.shared.setWeeklyCheckInAvailable(weekNumber: Int(week.weekNumber))
}
```

**Step 3: Build**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add TechnIQ/TrainingPlanService.swift
git commit -m "feat: add plan adaptation and weekly check-in trigger"
```

---

### Task 11: SessionCompleteView — Weekly Check-In Prompt

**Files:**
- Modify: `TechnIQ/SessionCompleteView.swift`

**Step 1: Add AICoachService and state**

After the existing `@State` properties (around line 16), add:

```swift
@StateObject private var aiCoachService = AICoachService.shared
@State private var showingWeeklyCheckIn = false
```

**Step 2: Add weekly check-in card**

In the `body` ScrollView VStack (after `streakCard`, around line 68), add before `continueButton`:

```swift
// Weekly Check-In Card
if aiCoachService.weeklyCheckInAvailable {
    weeklyCheckInCard
}
```

**Step 3: Add the card view**

Add this computed property to SessionCompleteView:

```swift
private var weeklyCheckInCard: some View {
    ModernCard(padding: DesignSystem.Spacing.lg) {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(DesignSystem.Colors.accentYellow)
                Text("Week \(aiCoachService.completedWeekNumber) Complete!")
                    .font(DesignSystem.Typography.titleMedium)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                Spacer()
            }

            Text("Your AI coach has reviewed your performance and may have suggestions for next week.")
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            ModernButton("See AI Review", icon: "sparkles", style: .secondary) {
                showingWeeklyCheckIn = true
            }
        }
    }
    .overlay(
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
            .stroke(DesignSystem.Colors.accentYellow.opacity(0.3), lineWidth: 1.5)
    )
    .scaleEffect(animateAchievements ? 1 : 0.9)
    .opacity(animateAchievements ? 1 : 0)
}
```

**Step 4: Add sheet presenter**

Add `.sheet` modifier to the body's ZStack (after the existing `.onAppear`):

```swift
.sheet(isPresented: $showingWeeklyCheckIn) {
    WeeklyCheckInView(weekNumber: aiCoachService.completedWeekNumber, player: player)
}
```

**Step 5: Build**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 6: Commit**

```bash
git add TechnIQ/SessionCompleteView.swift
git commit -m "feat: add weekly check-in prompt to SessionCompleteView"
```

---

### Task 12: Add New Files to Xcode Project

**Files:**
- Modify: `TechnIQ.xcodeproj/project.pbxproj`

**Step 1: Add all new Swift files to the Xcode project**

Use the Ruby `xcodeproj` gem to add files. Create and run a temporary script:

```ruby
require 'xcodeproj'

project_path = 'TechnIQ.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'TechnIQ' }
group = project.main_group.find_subpath('TechnIQ', true)

new_files = [
  'AICoachModels.swift',
  'AICoachService.swift',
  'TodaysFocusCard.swift',
  'WeeklyCheckInView.swift'
]

new_files.each do |filename|
  filepath = filename  # relative to group, NOT TechnIQ/filename
  unless group.files.any? { |f| f.display_name == filename }
    file_ref = group.new_reference(filepath)
    target.source_build_phase.add_file_reference(file_ref)
    puts "Added #{filename}"
  else
    puts "#{filename} already exists"
  end
end

project.save
puts 'Project saved'
```

Run: `ruby add_files.rb && rm add_files.rb`

**Step 2: Build**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add TechnIQ.xcodeproj/project.pbxproj
git commit -m "chore: add AI coach files to Xcode project"
```

---

### Task 13: Final Build Verification

**Step 1: Clean build**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' clean build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

**Step 2: Verify all files are committed**

Run: `git status`
Expected: `nothing to commit, working tree clean`

**Step 3: Review the diff**

Run: `git log --oneline -15`
Expected: See all AI coach commits in sequence.

---

### Unresolved Questions

1. `get_daily_coaching` and `get_plan_adaptation` — kept as separate functions in `main.py` (same file, separate endpoints). Deploy together.
2. Library drill matching — AI always generates fresh drills for now. Future: pass library exercise names as candidates.
3. Rate limit — client-side cache only (1/day). No server-side enforcement yet.
