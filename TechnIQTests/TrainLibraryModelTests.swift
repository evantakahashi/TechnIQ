import XCTest
@testable import TechnIQ

/// Rules behind the Train screen's sections: skill mapping, "My drills" first, the two-drill
/// minimum, pins, usage ordering, the weak-spot cold start, and the row meta line.
final class TrainLibraryModelTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func drill(_ name: String, skills: [String] = [], category: String? = "Technical", source: TrainDrill.Source = .template,
                       weakness: String? = nil, uses: Int = 0, daysAgo: Int? = nil, difficulty: Int = 2, minutes: Int = 15,
                       favorite: Bool = false) -> TrainDrill {
        TrainDrill(
            id: UUID(), name: name, category: category, difficulty: difficulty, minutes: minutes, targetSkills: skills,
            weaknessCategories: weakness, source: source, isFavorite: favorite,
            lastUsedAt: daysAgo.map { now.addingTimeInterval(-Double($0) * 86_400) }, usageCount: uses
        )
    }

    // MARK: Mapping

    func test_mapper_usesExplicitWeaknessCategoriesFirst() {
        let d = drill("Anything", skills: ["Passing"], weakness: "shooting:Weak foot finishing,passing:Vision")
        XCTAssertEqual(TrainSkillMapper.skill(for: d), .shooting)
    }

    func test_mapper_readsDefaultLibraryTags() {
        XCTAssertEqual(TrainSkillMapper.skill(for: drill("Ball Control", skills: ["Ball Control", "First Touch"])), .firstTouch)
        XCTAssertEqual(TrainSkillMapper.skill(for: drill("Dribbling Cones", skills: ["Dribbling", "Agility"])), .dribbling)
        XCTAssertEqual(TrainSkillMapper.skill(for: drill("Shooting Practice", skills: ["Shooting", "Accuracy"])), .shooting)
        XCTAssertEqual(TrainSkillMapper.skill(for: drill("Passing Accuracy", skills: ["Passing", "Vision"])), .passing)
        XCTAssertEqual(TrainSkillMapper.skill(for: drill("Sprint Training", skills: ["Speed", "Acceleration"])), .speedAgility)
        XCTAssertEqual(TrainSkillMapper.skill(for: drill("Endurance Run", skills: ["Endurance", "Fitness"])), .stamina)
        XCTAssertEqual(TrainSkillMapper.skill(for: drill("1v1 Practice", skills: ["Defending", "Attacking"])), .defending)
        XCTAssertEqual(TrainSkillMapper.skill(for: drill("Small-Sided Games", skills: ["Teamwork", "Decision Making"])), .positioning)
    }

    func test_mapper_prefersSpecificPhrasesAndFallsBackToName() {
        XCTAssertEqual(TrainSkillMapper.skill(matching: "Weak foot passing"), .weakFoot)
        XCTAssertEqual(TrainSkillMapper.skill(matching: "Headers on goal"), .aerialAbility)
        XCTAssertEqual(TrainSkillMapper.skill(matching: "First touch under pressure"), .firstTouch)
        XCTAssertEqual(TrainSkillMapper.skill(for: drill("Get better at shooting with my weak foot", skills: [])), .weakFoot)
        XCTAssertNil(TrainSkillMapper.skill(for: drill("Mystery drill", skills: ["Vibes"])))
    }

    // MARK: Sections

    func test_build_myDrillsLeadsAndExcludesTemplates() {
        let layout = TrainLibraryModel.build(drills: [
            drill("Template A", skills: ["Passing"]),
            drill("My AI drill", skills: ["Passing"], source: .ai),
            drill("My manual drill", skills: ["Shooting"], source: .manual),
            drill("Saved from community", skills: ["Shooting"], source: .community)
        ], pinned: [], weakSpots: [])
        XCTAssertEqual(layout.sections.first?.kind, .mine)
        XCTAssertEqual(layout.sections.first?.drills.map(\.name).sorted(), ["My AI drill", "My manual drill", "Saved from community"])
    }

    func test_build_noMineSectionForTemplateOnlyLibrary() {
        let layout = TrainLibraryModel.build(drills: [drill("A", skills: ["Passing"]), drill("B", skills: ["Passing"])], pinned: [], weakSpots: [])
        XCTAssertEqual(layout.sections.map(\.kind), [.skill(.passing)])
    }

    func test_build_singletonsBecomeMoreChipsUnlessPinned() {
        let layout = TrainLibraryModel.build(drills: [
            drill("P1", skills: ["Passing"]), drill("P2", skills: ["Passing"]),
            drill("D1", skills: ["Dribbling"]),
            drill("S1", skills: ["Shooting"])
        ], pinned: [.shooting], weakSpots: [])
        XCTAssertEqual(layout.sections.map(\.kind), [.skill(.shooting), .skill(.passing)], "pinned singleton keeps a section and leads")
        XCTAssertEqual(layout.more.map(\.kind), [.skill(.dribbling)])
        XCTAssertTrue(layout.sections[0].isPinned)
    }

    func test_build_ordersByUsageThenRecency() {
        let layout = TrainLibraryModel.build(drills: [
            drill("P1", skills: ["Passing"], uses: 1, daysAgo: 1), drill("P2", skills: ["Passing"]),
            drill("S1", skills: ["Shooting"], uses: 3, daysAgo: 9), drill("S2", skills: ["Shooting"], uses: 2, daysAgo: 20),
            drill("F1", skills: ["First Touch"], uses: 1, daysAgo: 0), drill("F2", skills: ["First Touch"])
        ], pinned: [], weakSpots: [])
        XCTAssertEqual(layout.sections.map(\.kind), [.skill(.shooting), .skill(.firstTouch), .skill(.passing)],
                       "5 uses first; then the two 1-use skills by most recent use")
    }

    func test_build_coldStartFollowsWeakSpotsThenSize() {
        let layout = TrainLibraryModel.build(drills: [
            drill("P1", skills: ["Passing"]), drill("P2", skills: ["Passing"]), drill("P3", skills: ["Passing"]),
            drill("S1", skills: ["Shooting"]), drill("S2", skills: ["Shooting"]),
            drill("D1", skills: ["Dribbling"]), drill("D2", skills: ["Dribbling"])
        ], pinned: [], weakSpots: [.shooting, .dribbling])
        XCTAssertEqual(layout.sections.map(\.kind), [.skill(.shooting), .skill(.dribbling), .skill(.passing)])
    }

    func test_build_previewIsTopThreeByRecency() {
        let layout = TrainLibraryModel.build(drills: [
            drill("Old", skills: ["Passing"], daysAgo: 30), drill("Newest", skills: ["Passing"], daysAgo: 0),
            drill("Never", skills: ["Passing"]), drill("Recent", skills: ["Passing"], daysAgo: 2)
        ], pinned: [], weakSpots: [])
        let section = layout.sections[0]
        XCTAssertEqual(section.count, 4)
        XCTAssertEqual(section.preview.map(\.name), ["Newest", "Recent", "Old"])
    }

    func test_build_unmappedDrillsGroupByCategoryAfterSkills() {
        let layout = TrainLibraryModel.build(drills: [
            drill("P1", skills: ["Passing"]), drill("P2", skills: ["Passing"]),
            drill("Yoga flow", skills: ["Vibes"], category: "Physical"), drill("Breathing", skills: [], category: "Physical"),
            drill("Highlights", skills: [], category: nil, source: .video)
        ], pinned: [], weakSpots: [])
        XCTAssertEqual(layout.sections.map(\.kind), [.mine, .skill(.passing), .other("Physical")])
        XCTAssertEqual(layout.more.map(\.kind), [.other("Video")])
        XCTAssertEqual(layout.sections[2].title, "Other · Physical")
    }

    // MARK: Meta

    func test_relativeUse_buckets() {
        func ago(_ days: Int) -> Date { now.addingTimeInterval(-Double(days) * 86_400) }
        XCTAssertNil(TrainLibraryModel.relativeUse(nil, now: now))
        XCTAssertNil(TrainLibraryModel.relativeUse(now.addingTimeInterval(3600), now: now), "future dates never label")
        XCTAssertEqual(TrainLibraryModel.relativeUse(now, now: now), "Today")
        XCTAssertEqual(TrainLibraryModel.relativeUse(ago(1), now: now), "Yesterday")
        XCTAssertEqual(TrainLibraryModel.relativeUse(ago(3), now: now), "3 days ago")
        XCTAssertEqual(TrainLibraryModel.relativeUse(ago(8), now: now), "Last week")
        XCTAssertEqual(TrainLibraryModel.relativeUse(ago(15), now: now), "2 weeks ago")
        XCTAssertEqual(TrainLibraryModel.relativeUse(ago(40), now: now), "Last month")
        XCTAssertEqual(TrainLibraryModel.relativeUse(ago(100), now: now), "3 months ago")
        XCTAssertEqual(TrainLibraryModel.relativeUse(ago(400), now: now), "Over a year ago")
    }

    func test_meta_showsSkillOnlyOutsideSkillSections() {
        let d = drill("Two-touch wall passing", skills: ["Passing"], daysAgo: 1)
        XCTAssertEqual(TrainLibraryModel.meta(for: d, showSkill: true, now: now), "Passing · Lvl 2 · 15′ · Yesterday")
        XCTAssertEqual(TrainLibraryModel.meta(for: d, showSkill: false, now: now), "Lvl 2 · 15′ · Yesterday")
        let video = drill("Clip", skills: [], source: .video, difficulty: 0, minutes: 9)
        XCTAssertEqual(TrainLibraryModel.meta(for: video, showSkill: true, now: now), "Video · 9′")
    }
}
