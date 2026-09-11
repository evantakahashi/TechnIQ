import XCTest
import CoreData
@testable import TechnIQ

// MARK: - Shared drill ranking (Community 6b)

final class SharedDrillRankingTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func drill(_ id: String, saves: Int, daysAgo: Double, category: String = "technical", hidden: Bool = false) -> SharedDrill {
        SharedDrill(
            id: id, authorID: "a-\(id)", authorName: "Player", authorLevel: 1, title: id, description: "",
            category: category, difficulty: 2, targetSkills: [], duration: 10, equipment: [], steps: [],
            sets: 1, reps: 1, timestamp: now.addingTimeInterval(-daysAgo * 86_400),
            saveCount: saves, isSavedByCurrentUser: false, reportCount: 0, isHidden: hidden
        )
    }

    func test_featured_prefersMostSavedWithinSevenDays() {
        let drills = [drill("old-hit", saves: 900, daysAgo: 30), drill("recent", saves: 120, daysAgo: 2), drill("recent-2", saves: 80, daysAgo: 6)]
        XCTAssertEqual(SharedDrillRanking.featured(from: drills, now: now)?.id, "recent")
    }

    func test_featured_fallsBackToAllTimeWhenNothingRecent() {
        let drills = [drill("old-hit", saves: 900, daysAgo: 30), drill("older", saves: 50, daysAgo: 60)]
        XCTAssertEqual(SharedDrillRanking.featured(from: drills, now: now)?.id, "old-hit")
    }

    func test_featured_ignoresHiddenAndFutureDrills() {
        let drills = [drill("hidden", saves: 999, daysAgo: 1, hidden: true), drill("future", saves: 500, daysAgo: -1), drill("ok", saves: 10, daysAgo: 3)]
        XCTAssertEqual(SharedDrillRanking.featured(from: drills, now: now)?.id, "ok")
    }

    func test_featured_isNilForEmptyOrAllHidden() {
        XCTAssertNil(SharedDrillRanking.featured(from: [], now: now))
        XCTAssertNil(SharedDrillRanking.featured(from: [drill("h", saves: 5, daysAgo: 1, hidden: true)], now: now))
    }

    func test_visible_trendingSortsBySavesThenRecency() {
        let drills = [drill("b", saves: 10, daysAgo: 5), drill("a", saves: 10, daysAgo: 1), drill("c", saves: 50, daysAgo: 9)]
        XCTAssertEqual(SharedDrillRanking.visible(drills, chip: .trending).map(\.id), ["c", "a", "b"])
    }

    func test_visible_newSortsByRecencyAndDropsHidden() {
        let drills = [drill("old", saves: 99, daysAgo: 9), drill("hidden", saves: 1, daysAgo: 0, hidden: true), drill("fresh", saves: 1, daysAgo: 1)]
        XCTAssertEqual(SharedDrillRanking.visible(drills, chip: .new).map(\.id), ["fresh", "old"])
    }

    func test_visible_categoryChipsFilterCaseInsensitively() {
        let drills = [drill("t1", saves: 5, daysAgo: 1, category: "Technical"), drill("p1", saves: 9, daysAgo: 1, category: "physical"), drill("t2", saves: 7, daysAgo: 2, category: "technical")]
        XCTAssertEqual(SharedDrillRanking.visible(drills, chip: .technical).map(\.id), ["t2", "t1"])
        XCTAssertEqual(SharedDrillRanking.visible(drills, chip: .physical).map(\.id), ["p1"])
        XCTAssertTrue(SharedDrillRanking.visible(drills, chip: .tactical).isEmpty)
    }

    func test_chipCategoriesMatchFirestoreValues() {
        XCTAssertNil(SharedDrillRanking.Chip.trending.category)
        XCTAssertNil(SharedDrillRanking.Chip.new.category)
        XCTAssertEqual(SharedDrillRanking.Chip.technical.category, "technical")
        XCTAssertEqual(SharedDrillRanking.Chip.tactical.category, "tactical")
        XCTAssertEqual(SharedDrillRanking.Chip.physical.category, "physical")
        XCTAssertEqual(SharedDrillRanking.Chip.allCases.map(\.title), ["Trending", "New", "Technical", "Tactical", "Physical"])
    }

    func test_savesLabel_formatsThousands() {
        XCTAssertEqual(SharedDrillRanking.savesLabel(0), "0")
        XCTAssertEqual(SharedDrillRanking.savesLabel(-3), "0")
        XCTAssertEqual(SharedDrillRanking.savesLabel(842), "842")
        XCTAssertEqual(SharedDrillRanking.savesLabel(1000), "1K")
        XCTAssertEqual(SharedDrillRanking.savesLabel(1240), "1.2K")
        XCTAssertEqual(SharedDrillRanking.savesLabel(12_400), "12K")
    }
}

// MARK: - Onboarding mapping (7b)

final class OnboardingMappingTests: XCTestCase {
    func test_experienceMapsToEveryPlanDifficulty() {
        XCTAssertEqual(OnboardingMapping.difficulty(forExperience: "Beginner"), PlanDifficulty.beginner.rawValue)
        XCTAssertEqual(OnboardingMapping.difficulty(forExperience: "Intermediate"), PlanDifficulty.intermediate.rawValue)
        XCTAssertEqual(OnboardingMapping.difficulty(forExperience: "Advanced"), PlanDifficulty.advanced.rawValue)
        XCTAssertEqual(OnboardingMapping.difficulty(forExperience: "Professional"), PlanDifficulty.elite.rawValue)
        XCTAssertEqual(OnboardingMapping.difficulty(forExperience: "???"), PlanDifficulty.intermediate.rawValue)
        for level in OnboardingMapping.experienceLevels {
            XCTAssertNotNil(PlanDifficulty(rawValue: OnboardingMapping.difficulty(forExperience: level)), level)
        }
    }

    func test_goalMapsToValidPlanCategory() {
        for goal in OnboardingMapping.goals {
            XCTAssertNotNil(PlanCategory(rawValue: OnboardingMapping.category(forGoal: goal)), goal)
        }
        XCTAssertEqual(OnboardingMapping.category(forGoal: "Build Fitness"), PlanCategory.physical.rawValue)
        XCTAssertEqual(OnboardingMapping.category(forGoal: "Improve Skills"), PlanCategory.technical.rawValue)
        XCTAssertEqual(OnboardingMapping.category(forGoal: "nope"), PlanCategory.general.rawValue)
    }

    func test_frequencyDaysAreRealWeekdaysAndRestDaysComplementThem() {
        let all = Set(DayOfWeek.allCases.map(\.rawValue))
        for frequency in OnboardingMapping.frequencies {
            let preferred = OnboardingMapping.preferredDays(forFrequency: frequency)
            let rest = OnboardingMapping.restDays(forFrequency: frequency)
            XCTAssertFalse(preferred.isEmpty, frequency)
            XCTAssertTrue(Set(preferred).isSubset(of: all), frequency)
            XCTAssertEqual(Set(preferred).union(rest), all, frequency)
            XCTAssertTrue(Set(preferred).isDisjoint(with: rest), frequency)
        }
        XCTAssertEqual(OnboardingMapping.preferredDays(forFrequency: "Daily").count, 7)
        XCTAssertTrue(OnboardingMapping.restDays(forFrequency: "Daily").isEmpty)
        XCTAssertEqual(OnboardingMapping.preferredDays(forFrequency: "2-3x per week").count, 3)
    }

    func test_digitsKeepsOnlyNumbersUpToTheCap() {
        XCTAssertEqual(OnboardingMapping.digits("1a2b3", maxDigits: 2), "12")
        XCTAssertEqual(OnboardingMapping.digits("", maxDigits: 2), "")
        XCTAssertEqual(OnboardingMapping.digits("2024", maxDigits: 2), "20")
    }

    func test_ageAndKitNumberValidation() {
        XCTAssertEqual(OnboardingMapping.age(from: "14"), 14)
        XCTAssertEqual(OnboardingMapping.age(from: " 5 "), 5)
        XCTAssertNil(OnboardingMapping.age(from: "4"))
        XCTAssertNil(OnboardingMapping.age(from: "81"))
        XCTAssertNil(OnboardingMapping.age(from: ""))
        XCTAssertNil(OnboardingMapping.age(from: "abc"))

        XCTAssertEqual(OnboardingMapping.kitNumber(from: "9"), 9)
        XCTAssertEqual(OnboardingMapping.kitNumber(from: "99"), 99)
        XCTAssertNil(OnboardingMapping.kitNumber(from: "0"))
        XCTAssertNil(OnboardingMapping.kitNumber(from: "100"))
        XCTAssertNil(OnboardingMapping.kitNumber(from: ""))
    }

    func test_resolvedNameFallsBackToAccountThenPlayer() {
        XCTAssertEqual(OnboardingMapping.resolvedName(entered: "  Evan ", accountName: "Account"), "Evan")
        XCTAssertEqual(OnboardingMapping.resolvedName(entered: "   ", accountName: "Account Name"), "Account Name")
        XCTAssertEqual(OnboardingMapping.resolvedName(entered: "", accountName: " "), "Player")
    }
}

// MARK: - Plan templates (Plans 8a / Home 4a)

@MainActor
final class TrainingPlanTemplateTests: XCTestCase {
    func test_templateWeeks_buildsSevenDayWeeksWithSessionsOnTrainingDays() {
        let training: [DayOfWeek] = [.monday, .wednesday, .friday]
        let weeks = TrainingPlanService.templateWeeks(count: 4, trainingDays: training, sessionType: .technical, difficulty: .beginner, focus: ["A", "B"])
        XCTAssertEqual(weeks.count, 4)
        XCTAssertEqual(weeks.map(\.weekNumber), [1, 2, 3, 4])
        XCTAssertEqual(weeks.map(\.focusArea), ["A", "B", "A", "B"])
        for week in weeks {
            XCTAssertEqual(week.days.count, 7)
            XCTAssertEqual(week.days.map(\.dayNumber), Array(1...7))
            for day in week.days {
                let isTraining = day.dayOfWeek.map(training.contains) ?? false
                XCTAssertEqual(day.isRestDay, !isTraining)
                XCTAssertEqual(day.sessions.count, isTraining ? 1 : 0)
                if let session = day.sessions.first {
                    XCTAssertEqual(session.duration, 30)
                    XCTAssertEqual(session.intensity, 2)
                    XCTAssertEqual(session.sessionType, .technical)
                }
            }
        }
    }

    func test_templateWeeks_neverProducesAnEmptyPlan() {
        let weeks = TrainingPlanService.templateWeeks(count: 0, trainingDays: [], sessionType: .physical, difficulty: .elite, focus: [])
        XCTAssertEqual(weeks.count, 1, "count is clamped to at least one week")
        XCTAssertEqual(weeks[0].days.count, 7)
        XCTAssertNil(weeks[0].focusArea)
        XCTAssertTrue(weeks[0].days.allSatisfy(\.isRestDay))
    }

    func test_prebuiltTemplates_haveFullSchedules() {
        let templates = TrainingPlanService.shared.availablePlans
        XCTAssertEqual(templates.count, 6)
        for template in templates {
            XCTAssertEqual(template.weeks.count, template.durationWeeks, template.name)
            XCTAssertEqual(template.totalDays, template.durationWeeks * 7, template.name)
            XCTAssertGreaterThan(template.totalSessions, 0, "\(template.name) needs sessions or Home shows PLAN COMPLETE")
            XCTAssertFalse(template.isCompleted, template.name)
        }
    }
}

// MARK: - Player kit number

final class PlayerKitNumberTests: XCTestCase {
    func test_kitNumberValue_zeroMeansNone() {
        let stack = TestCoreDataStack()
        let player = stack.makePlayer()
        XCTAssertEqual(player.kitNumber, 0)
        XCTAssertNil(player.kitNumberValue)

        player.kitNumber = 9
        XCTAssertEqual(player.kitNumberValue, 9)

        player.kitNumber = -1
        XCTAssertNil(player.kitNumberValue, "negative numbers are never a shirt number")
    }
}
