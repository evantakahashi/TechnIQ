import XCTest
import CoreData
@testable import TechnIQ

/// The coach contract: snake_case answers decode, the library reaches the model with ids, the
/// week recap adds up, and the weekly review fires when a plan week's window has ended.
@MainActor
final class CoachTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    // MARK: Decoding

    func test_dailyCoaching_decodesTheServersSnakeCase() throws {
        let json = """
        {"focus_area": "Passing", "reasoning": "Your passing ratings dropped from 3.6 to 2.8.", "cue": "Open your hips before the second touch.",
         "recommended_drill": {"name": "Two-touch wall passing", "description": "Wall work", "category": "technical", "difficulty": 2, "duration": 15,
                               "steps": ["Pass", "Move"], "equipment": ["ball"], "target_skills": ["passing"], "is_from_library": true,
                               "library_exercise_id": "2A6F1C6E-6F0B-4C7B-9C0B-2E6C8A5D1F11"},
         "additional_tips": ["Scan early"], "streak_message": null, "insights": [{"title": "Steady", "description": "3 sessions", "type": "pattern", "priority": 5}]}
        """
        let coaching = try JSONDecoder().decode(DailyCoaching.self, from: Data(json.utf8))
        XCTAssertEqual(coaching.focusArea, "Passing")
        XCTAssertEqual(coaching.cue, "Open your hips before the second touch.")
        XCTAssertTrue(coaching.recommendedDrill.isFromLibrary)
        XCTAssertEqual(coaching.recommendedDrill.libraryExerciseID, "2A6F1C6E-6F0B-4C7B-9C0B-2E6C8A5D1F11")
        XCTAssertEqual(coaching.recommendedDrill.targetSkills, ["passing"])
        XCTAssertEqual(coaching.insights.first?.actionable, nil)
        XCTAssertTrue(Calendar.current.isDateInToday(coaching.fetchDate), "the decoder stamps today's fetch date")

        // The cache round-trips with its fetch date.
        let data = try JSONEncoder().encode(coaching)
        let again = try JSONDecoder().decode(DailyCoaching.self, from: data)
        XCTAssertEqual(again.recommendedDrill.name, "Two-touch wall passing")
        XCTAssertEqual(again.fetchDate.timeIntervalSince1970, coaching.fetchDate.timeIntervalSince1970, accuracy: 1)
    }

    func test_dailyCoaching_toleratesMissingOptionalFields() throws {
        let json = """
        {"focus_area": "Shooting", "reasoning": "r", "recommended_drill": {"name": "X", "is_from_library": false}}
        """
        let coaching = try JSONDecoder().decode(DailyCoaching.self, from: Data(json.utf8))
        XCTAssertNil(coaching.cue)
        XCTAssertEqual(coaching.additionalTips, [])
        XCTAssertEqual(coaching.recommendedDrill.duration, 15)
        XCTAssertFalse(coaching.recommendedDrill.isFromLibrary)
    }

    func test_planAdaptation_decodesReasons() throws {
        let json = """
        {"summary": "Solid week.", "adaptations": [{"type": "modify_difficulty", "day": 2, "session_index": 0, "description": "Dribbling to level 4",
          "reason": "You rated all three dribbling drills 5/5.", "old_difficulty": 3, "new_difficulty": 4, "drill": null}]}
        """
        let response = try JSONDecoder().decode(PlanAdaptationResponse.self, from: Data(json.utf8))
        XCTAssertEqual(response.adaptations.count, 1)
        XCTAssertEqual(response.adaptations[0].reason, "You rated all three dribbling drills 5/5.")
        XCTAssertEqual(response.adaptations[0].sessionIndex, 0)
        XCTAssertEqual(response.adaptations[0].newDifficulty, 4)
    }

    // MARK: Library payload

    func test_libraryPayload_carriesIdsMostRecentFirst() {
        let stack = TestCoreDataStack()
        let player = stack.makePlayer()
        let old = stack.makeExercise(player: player, name: "Old")
        old.lastUsedAt = date(2026, 9, 1)
        old.targetSkills = ["Passing", "Vision", "Scanning", "Touch", "Extra"]
        let recent = stack.makeExercise(player: player, name: "Recent")
        recent.lastUsedAt = date(2026, 9, 11)
        recent.estimatedDurationSeconds = 20 * 60
        let never = stack.makeExercise(player: player, name: "Never")
        try? stack.context.save()

        let payload = AICoachService.libraryPayload(for: player, now: date(2026, 9, 12), calendar: calendar)
        XCTAssertEqual(payload.map { $0["name"] as? String }, ["Recent", "Old", "Never"])
        XCTAssertEqual(payload[0]["last_used_days_ago"] as? Int, 1)
        XCTAssertEqual(payload[0]["minutes"] as? Int, 20)
        XCTAssertEqual(payload[0]["id"] as? String, recent.id?.uuidString)
        XCTAssertEqual((payload[1]["skills"] as? [String])?.count, 4, "skills are capped at four")
        XCTAssertNil(payload[2]["last_used_days_ago"])
        XCTAssertEqual(payload[2]["source"] as? String, "template")
    }

    // MARK: Week recap

    func test_weekRecap_addsUpAndPicksTheBestDrill() {
        let weeks = TrainingPlanService.templateWeeks(count: 2, trainingDays: [.monday, .thursday], sessionType: .technical, difficulty: .beginner, focus: [])
        var week1 = weeks[0]
        week1 = PlanWeekModel(id: week1.id, weekNumber: 1, focusArea: nil, notes: nil, isCompleted: false, completedAt: nil, days: week1.days.map { day in
            PlanDayModel(id: day.id, dayNumber: day.dayNumber, dayOfWeek: day.dayOfWeek, isRestDay: day.isRestDay, isSkipped: false, notes: nil,
                         isCompleted: day.dayOfWeek == .monday, completedAt: nil, sessions: day.sessions)
        })
        let plan = TrainingPlanModel(
            id: UUID(), name: "Recap", description: "", durationWeeks: 2, difficulty: .beginner, category: .technical, targetRole: nil,
            isPrebuilt: false, isActive: true, currentWeek: 1, progressPercentage: 0, startedAt: date(2026, 9, 7), completedAt: nil,
            createdAt: date(2026, 9, 7), updatedAt: date(2026, 9, 7), weeks: [week1, weeks[1]]
        )
        let sessions = [
            WeekRecap.Session(date: date(2026, 9, 7), minutes: 30, rating: 4, drillNames: ["Wall passing", "Cone weave"], drillRatings: ["Wall passing": 5, "Cone weave": 3])
        ]
        let previous = [WeekRecap.Session(date: date(2026, 8, 31), minutes: 30, rating: 2, drillNames: [], drillRatings: [:])]
        let recap = WeekRecap.build(plan: plan, weekNumber: 1, sessions: sessions, previousSessions: previous, startDate: date(2026, 9, 7), now: date(2026, 9, 14), calendar: calendar)
        XCTAssertEqual(recap.planned, 2)
        XCTAssertEqual(recap.done, 1)
        XCTAssertEqual(recap.missed, 1, "Thursday went by untrained")
        XCTAssertEqual(recap.minutes, 30)
        XCTAssertEqual(recap.effortLabel, "4.0/5")
        XCTAssertEqual(recap.effortTrend, "Harder than last week")
        XCTAssertEqual(recap.bestDrill, "Wall passing")
        XCTAssertEqual(recap.headline, "1 of 2 sessions done")
        XCTAssertEqual(recap.payload["best_drill"] as? String, "Wall passing")
    }
}
