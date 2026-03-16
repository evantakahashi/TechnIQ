# Diagram Quality & Alignment Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix AI drill diagram quality with new element types, a server-side post-processor, player-tailored prompts, and updated rendering.

**Architecture:** LLM generates drill + diagram → deterministic Python post-processor validates/fixes spatial issues → Referee validates. Enriched prompts embed drill design domain knowledge personalized to the player. Client renders 4 new element types (defender, server, mannequin, wall).

**Tech Stack:** Python (Firebase Functions), SwiftUI, XCTest, pytest

**Spec:** `docs/superpowers/specs/2026-03-15-diagram-quality-alignment-design.md`

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `functions/drill_post_processor.py` | Create | Deterministic spatial validation + fixing |
| `functions/test_drill_post_processor.py` | Create | Post-processor unit tests |
| `functions/main.py` | Modify | Insert post-processor into pipeline, update prompts |
| `TechnIQ/Models/CustomDrillModels.swift` | Modify | Add 4 element types to enum |
| `TechnIQ/Views/Exercises/DrillDiagramView.swift` | Modify | Add renderers for new element types |
| `TechnIQTests/DrillDiagramTests.swift` | Create | Swift rendering/parsing tests |

---

## Chunk 1: Data Model + Rendering

### Task 1: Add new element types to Swift data model

**Files:**
- Modify: `TechnIQ/Models/CustomDrillModels.swift:196-202`
- Test: `TechnIQTests/DrillDiagramTests.swift`

- [ ] **Step 1: Write failing tests for new element types**

Create `TechnIQTests/DrillDiagramTests.swift`:

```swift
import XCTest
@testable import TechnIQ

final class DrillDiagramTests: XCTestCase {

    // MARK: - DiagramElementType Parsing

    func testPlayerTypeParsesCorrectly() {
        XCTAssertEqual(DiagramElementType(rawValue: "player"), .player)
    }

    func testDefenderTypeParsesCorrectly() {
        XCTAssertEqual(DiagramElementType(rawValue: "defender"), .defender)
    }

    func testServerTypeParsesCorrectly() {
        XCTAssertEqual(DiagramElementType(rawValue: "server"), .server)
    }

    func testMannequinTypeParsesCorrectly() {
        XCTAssertEqual(DiagramElementType(rawValue: "mannequin"), .mannequin)
    }

    func testWallTypeParsesCorrectly() {
        XCTAssertEqual(DiagramElementType(rawValue: "wall"), .wall)
    }

    func testConeTypeParsesCorrectly() {
        XCTAssertEqual(DiagramElementType(rawValue: "cone"), .cone)
    }

    func testGoalTypeParsesCorrectly() {
        XCTAssertEqual(DiagramElementType(rawValue: "goal"), .goal)
    }

    func testBallTypeParsesCorrectly() {
        XCTAssertEqual(DiagramElementType(rawValue: "ball"), .ball)
    }

    func testTargetTypeParsesCorrectly() {
        XCTAssertEqual(DiagramElementType(rawValue: "target"), .target)
    }

    func testUnknownTypeDefaultsToCone() {
        let element = DiagramElement(type: "unknown_type", x: 5, y: 5, label: "X")
        XCTAssertEqual(element.elementType, .cone)
    }

    // MARK: - Backward Compatibility

    func testExistingDrillElementsParseUnchanged() {
        let elements = [
            DiagramElement(type: "cone", x: 2, y: 2, label: "A"),
            DiagramElement(type: "player", x: 5, y: 5, label: "P1"),
            DiagramElement(type: "goal", x: 10, y: 20, label: "Goal"),
            DiagramElement(type: "ball", x: 3, y: 3, label: "Ball"),
            DiagramElement(type: "target", x: 8, y: 10, label: "T1")
        ]
        XCTAssertEqual(elements[0].elementType, .cone)
        XCTAssertEqual(elements[1].elementType, .player)
        XCTAssertEqual(elements[2].elementType, .goal)
        XCTAssertEqual(elements[3].elementType, .ball)
        XCTAssertEqual(elements[4].elementType, .target)
    }

    func testNewElementTypesGenerateUniqueIds() {
        let wall = DiagramElement(type: "wall", x: 10, y: 0, label: "W1")
        let defender = DiagramElement(type: "defender", x: 8, y: 12, label: "D1")
        XCTAssertNotEqual(wall.id, defender.id)
        XCTAssertTrue(wall.id.contains("wall"))
        XCTAssertTrue(defender.id.contains("defender"))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' -only-testing:TechnIQTests/DrillDiagramTests 2>&1 | tail -20`
Expected: FAIL — `defender`, `server`, `mannequin`, `wall` are not members of `DiagramElementType`

- [ ] **Step 3: Add new cases to DiagramElementType enum**

In `TechnIQ/Models/CustomDrillModels.swift`, replace the `DiagramElementType` enum (lines 196-202):

```swift
enum DiagramElementType: String {
    case cone = "cone"
    case player = "player"
    case defender = "defender"
    case server = "server"
    case wall = "wall"
    case mannequin = "mannequin"
    case target = "target"
    case goal = "goal"
    case ball = "ball"
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' -only-testing:TechnIQTests/DrillDiagramTests 2>&1 | tail -20`
Expected: All 13 tests PASS

- [ ] **Step 5: Commit**

```bash
git add TechnIQ/Models/CustomDrillModels.swift TechnIQTests/DrillDiagramTests.swift
git commit -m "feat: add defender, server, mannequin, wall element types to diagram model"
```

---

### Task 2: Add renderers for new element types

**Files:**
- Modify: `TechnIQ/Views/Exercises/DrillDiagramView.swift:182-211` (elementView switch) and add 4 new renderer functions

- [ ] **Step 1: Add defender renderer**

In `DrillDiagramView.swift`, add after `playerElementView` (after line 242):

```swift
private func defenderElementView(label: String, isActive: Bool) -> some View {
    let displayText = String(label.prefix(2))

    return ZStack {
        if isActive {
            Circle()
                .fill(Color.red.opacity(0.3))
                .frame(width: playerSize + 14, height: playerSize + 14)
                .scaleEffect(pulseScale)
                .onAppear {
                    withAnimation(
                        .easeInOut(duration: 1.0)
                        .repeatForever(autoreverses: true)
                    ) {
                        pulseScale = 1.25
                    }
                }
        }

        Circle()
            .fill(Color.red)
            .frame(width: playerSize, height: playerSize)
            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)

        Text(displayText)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
    }
}
```

- [ ] **Step 2: Add server renderer**

Add after `defenderElementView`:

```swift
private func serverElementView(label: String, isActive: Bool) -> some View {
    let displayText = String(label.prefix(2))

    return ZStack {
        if isActive {
            Circle()
                .fill(DesignSystem.Colors.secondaryBlue.opacity(0.3))
                .frame(width: playerSize + 14, height: playerSize + 14)
                .scaleEffect(pulseScale)
                .onAppear {
                    withAnimation(
                        .easeInOut(duration: 1.0)
                        .repeatForever(autoreverses: true)
                    ) {
                        pulseScale = 1.25
                    }
                }
        }

        Circle()
            .fill(DesignSystem.Colors.secondaryBlue)
            .frame(width: playerSize, height: playerSize)
            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)

        Text(displayText)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
    }
}
```

- [ ] **Step 3: Add mannequin renderer**

Add after `serverElementView`:

```swift
private func mannequinElementView(label: String) -> some View {
    VStack(spacing: 2) {
        ZStack {
            Circle()
                .fill(DesignSystem.Colors.textTertiary)
                .frame(width: playerSize, height: playerSize)
                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)

            Text("X")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
        }

        Text(label)
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(DesignSystem.Colors.textSecondary)
    }
}
```

- [ ] **Step 4: Add wall renderer**

Add after `mannequinElementView`:

```swift
private func wallElementView(label: String) -> some View {
    VStack(spacing: 2) {
        RoundedRectangle(cornerRadius: 2)
            .fill(DesignSystem.Colors.textTertiary)
            .frame(width: 40, height: 12)
            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)

        Text(label)
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(DesignSystem.Colors.textSecondary)
    }
}
```

- [ ] **Step 5: Update the elementView switch statement**

Replace the switch in `elementView` (lines 195-206):

```swift
Group {
    switch element.elementType {
    case .player:
        playerElementView(label: element.label, isActive: isActive)
    case .defender:
        defenderElementView(label: element.label, isActive: isActive)
    case .server:
        serverElementView(label: element.label, isActive: isActive)
    case .mannequin:
        mannequinElementView(label: element.label)
    case .wall:
        wallElementView(label: element.label)
    case .cone:
        coneElementView(label: element.label)
    case .goal:
        goalElementView(label: element.label)
    case .ball:
        ballElementView()
    case .target:
        targetElementView(label: element.label)
    }
}
```

- [ ] **Step 6: Build to verify compilation**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 7: Run all diagram tests**

Run: `xcodebuild test -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' -only-testing:TechnIQTests/DrillDiagramTests 2>&1 | tail -20`
Expected: All tests PASS

- [ ] **Step 8: Commit**

```bash
git add TechnIQ/Views/Exercises/DrillDiagramView.swift
git commit -m "feat: add defender, server, mannequin, wall renderers to drill diagram"
```

---

## Chunk 2: Post-Processor

### Task 3: Create post-processor with spatial fixes

**Files:**
- Create: `functions/drill_post_processor.py`
- Create: `functions/test_drill_post_processor.py`

- [ ] **Step 1: Write failing tests for spatial fixes**

Create `functions/test_drill_post_processor.py`:

```python
"""Tests for drill_post_processor.py"""
import pytest
from drill_post_processor import post_process_drill

# --- Helpers ---

def make_drill(elements=None, paths=None, instructions=None, equipment=None, field_w=20, field_l=15):
    """Build a minimal drill dict for testing."""
    return {
        "name": "Test Drill",
        "description": "Test.",
        "setup": "Test setup.",
        "instructions": instructions or ["Dribble from A to B"],
        "diagram": {
            "field": {"width": field_w, "length": field_l},
            "elements": elements or [],
            "paths": paths or []
        },
        "difficulty": "intermediate",
        "category": "technical",
        "targetSkills": ["dribbling"],
        "equipment": equipment or ["ball", "cones"]
    }


def make_el(type_="cone", x=5, y=5, label="A"):
    return {"type": type_, "x": x, "y": y, "label": label}


def make_path(from_="A", to="B", style="dribble", step=1):
    return {"from": from_, "to": to, "style": style, "step": step}


# --- Bounds Clamping ---

class TestBoundsClamping:
    def test_negative_x_clamped_to_one(self):
        drill = make_drill(elements=[make_el(x=-5, y=5)])
        result, warnings = post_process_drill(drill, player_age=14)
        assert result["diagram"]["elements"][0]["x"] == 1

    def test_negative_y_clamped_to_one(self):
        drill = make_drill(elements=[make_el(x=5, y=-3)])
        result, warnings = post_process_drill(drill, player_age=14)
        assert result["diagram"]["elements"][0]["y"] == 1

    def test_x_exceeding_width_clamped(self):
        drill = make_drill(elements=[make_el(x=25, y=5)], field_w=20, field_l=15)
        result, warnings = post_process_drill(drill, player_age=14)
        assert result["diagram"]["elements"][0]["x"] == 19  # width - 1m padding

    def test_y_exceeding_length_clamped(self):
        drill = make_drill(elements=[make_el(x=5, y=20)], field_w=20, field_l=15)
        result, warnings = post_process_drill(drill, player_age=14)
        assert result["diagram"]["elements"][0]["y"] == 14  # length - 1m padding

    def test_valid_coords_unchanged(self):
        drill = make_drill(elements=[make_el(x=10, y=7)])
        result, _ = post_process_drill(drill, player_age=14)
        assert result["diagram"]["elements"][0]["x"] == 10
        assert result["diagram"]["elements"][0]["y"] == 7


# --- Overlap Resolution ---

class TestOverlapResolution:
    def test_two_elements_at_same_position_nudged_apart(self):
        drill = make_drill(elements=[
            make_el(x=10, y=10, label="A"),
            make_el(x=10, y=10, label="B")
        ])
        result, _ = post_process_drill(drill, player_age=14)
        els = result["diagram"]["elements"]
        dist = ((els[0]["x"] - els[1]["x"])**2 + (els[0]["y"] - els[1]["y"])**2) ** 0.5
        assert dist >= 2.0  # minimum 2m spacing

    def test_elements_with_sufficient_spacing_unchanged(self):
        drill = make_drill(elements=[
            make_el(x=5, y=5, label="A"),
            make_el(x=10, y=10, label="B")
        ])
        result, _ = post_process_drill(drill, player_age=14)
        els = result["diagram"]["elements"]
        assert els[0]["x"] == 5
        assert els[1]["x"] == 10


# --- Path Validation ---

class TestPathValidation:
    def test_pass_to_cone_flagged(self):
        drill = make_drill(
            elements=[make_el("player", 5, 5, "P1"), make_el("cone", 10, 10, "C1")],
            paths=[make_path("P1", "C1", "pass", 1)]
        )
        _, warnings = post_process_drill(drill, player_age=14)
        assert any("pass" in w.lower() and "cone" in w.lower() for w in warnings)

    def test_pass_to_player_valid(self):
        drill = make_drill(
            elements=[make_el("player", 5, 5, "P1"), make_el("player", 10, 10, "P2")],
            paths=[make_path("P1", "P2", "pass", 1)]
        )
        _, warnings = post_process_drill(drill, player_age=14)
        assert not any("pass" in w.lower() and "player" in w.lower() for w in warnings)

    def test_pass_to_wall_valid(self):
        drill = make_drill(
            elements=[make_el("player", 5, 5, "P1"), make_el("wall", 10, 0, "W1")],
            paths=[make_path("P1", "W1", "pass", 1)],
            equipment=["ball", "wall"]
        )
        _, warnings = post_process_drill(drill, player_age=14)
        assert not any("pass" in w.lower() and "wall" in w.lower() for w in warnings)

    def test_pass_to_goal_valid(self):
        drill = make_drill(
            elements=[make_el("player", 5, 5, "P1"), make_el("goal", 10, 15, "G1")],
            paths=[make_path("P1", "G1", "pass", 1)],
            equipment=["ball", "goals"]
        )
        _, warnings = post_process_drill(drill, player_age=14)
        assert not any("pass" in w.lower() and "goal" in w.lower() for w in warnings)

    def test_pass_to_defender_valid(self):
        drill = make_drill(
            elements=[make_el("player", 5, 5, "P1"), make_el("defender", 10, 10, "D1")],
            paths=[make_path("P1", "D1", "pass", 1)]
        )
        _, warnings = post_process_drill(drill, player_age=14)
        assert not any("invalid pass target" in w.lower() for w in warnings)

    def test_pass_to_server_valid(self):
        drill = make_drill(
            elements=[make_el("player", 5, 5, "P1"), make_el("server", 10, 10, "S1")],
            paths=[make_path("P1", "S1", "pass", 1)]
        )
        _, warnings = post_process_drill(drill, player_age=14)
        assert not any("invalid pass target" in w.lower() for w in warnings)

    def test_path_referencing_nonexistent_label_removed(self):
        drill = make_drill(
            elements=[make_el("player", 5, 5, "P1")],
            paths=[make_path("P1", "GHOST", "dribble", 1)]
        )
        result, warnings = post_process_drill(drill, player_age=14)
        assert len(result["diagram"]["paths"]) == 0
        assert any("GHOST" in w for w in warnings)

    def test_orphan_path_step_warned(self):
        drill = make_drill(
            elements=[make_el("player", 5, 5, "P1"), make_el("cone", 10, 10, "C1")],
            paths=[make_path("P1", "C1", "dribble", 5)],
            instructions=["Dribble from P1 to C1"]
        )
        _, warnings = post_process_drill(drill, player_age=14)
        assert any("step" in w.lower() for w in warnings)


# --- Equipment Consistency ---

class TestEquipmentConsistency:
    def test_wall_in_equipment_not_in_elements_warned(self):
        drill = make_drill(
            elements=[make_el("player", 5, 5, "P1")],
            equipment=["ball", "wall"]
        )
        _, warnings = post_process_drill(drill, player_age=14)
        assert any("wall" in w.lower() for w in warnings)

    def test_wall_in_equipment_and_elements_no_warning(self):
        drill = make_drill(
            elements=[make_el("player", 5, 5, "P1"), make_el("wall", 10, 0, "W1")],
            equipment=["ball", "wall"]
        )
        _, warnings = post_process_drill(drill, player_age=14)
        assert not any("wall" in w.lower() and "missing" in w.lower() for w in warnings)

    def test_partner_maps_to_player_types(self):
        drill = make_drill(
            elements=[make_el("player", 5, 5, "P1"), make_el("server", 10, 10, "S1")],
            equipment=["ball", "partner"]
        )
        _, warnings = post_process_drill(drill, player_age=14)
        assert not any("partner" in w.lower() and "missing" in w.lower() for w in warnings)

    def test_goals_maps_to_goal_element(self):
        drill = make_drill(
            elements=[make_el("player", 5, 5, "P1"), make_el("goal", 10, 15, "G1")],
            equipment=["ball", "goals"]
        )
        _, warnings = post_process_drill(drill, player_age=14)
        assert not any("goal" in w.lower() and "missing" in w.lower() for w in warnings)


# --- Instruction-Path Alignment ---

class TestInstructionPathAlignment:
    def test_three_instructions_one_path_warned(self):
        drill = make_drill(
            elements=[make_el("player", 5, 5, "P1"), make_el("cone", 10, 10, "C1")],
            paths=[make_path("P1", "C1", "dribble", 1)],
            instructions=["Dribble to C1", "Sprint back to P1", "Repeat the circuit"]
        )
        _, warnings = post_process_drill(drill, player_age=14)
        assert any("step" in w.lower() and ("2" in w or "3" in w) for w in warnings)


# --- Pass Target Rejection ---

class TestPassTargetRejection:
    def test_pass_to_mannequin_flagged(self):
        drill = make_drill(
            elements=[make_el("player", 5, 5, "P1"), make_el("mannequin", 10, 10, "M1")],
            paths=[make_path("P1", "M1", "pass", 1)]
        )
        _, warnings = post_process_drill(drill, player_age=14)
        assert any("pass" in w.lower() and "mannequin" in w.lower() for w in warnings)

    def test_pass_to_ball_flagged(self):
        drill = make_drill(
            elements=[make_el("player", 5, 5, "P1"), make_el("ball", 8, 8, "B1")],
            paths=[make_path("P1", "B1", "pass", 1)]
        )
        _, warnings = post_process_drill(drill, player_age=14)
        assert any("invalid pass target" in w.lower() for w in warnings)


# --- Duplicate Path Removal ---

class TestDuplicatePaths:
    def test_duplicate_paths_removed(self):
        drill = make_drill(
            elements=[make_el("player", 5, 5, "P1"), make_el("cone", 10, 10, "C1")],
            paths=[
                make_path("P1", "C1", "dribble", 1),
                make_path("P1", "C1", "dribble", 1),  # duplicate
            ]
        )
        result, _ = post_process_drill(drill, player_age=14)
        assert len(result["diagram"]["paths"]) == 1


# --- Age-Appropriate Spacing ---

class TestAgeSpacing:
    def test_u10_with_15m_cone_spacing_warned(self):
        drill = make_drill(
            elements=[make_el("cone", 1, 1, "A"), make_el("cone", 16, 1, "B")],
            field_w=20, field_l=15
        )
        _, warnings = post_process_drill(drill, player_age=10)
        assert any("spacing" in w.lower() for w in warnings)

    def test_u10_with_3m_cone_spacing_no_warning(self):
        drill = make_drill(
            elements=[make_el("cone", 5, 5, "A"), make_el("cone", 8, 5, "B")],
        )
        _, warnings = post_process_drill(drill, player_age=10)
        assert not any("spacing" in w.lower() for w in warnings)


# --- Schema Completeness ---

class TestSchemaCompleteness:
    def test_missing_required_field_warned(self):
        drill = make_drill()
        del drill["name"]
        _, warnings = post_process_drill(drill, player_age=14)
        assert any("name" in w.lower() for w in warnings)

    def test_complete_drill_no_schema_warning(self):
        drill = make_drill()
        _, warnings = post_process_drill(drill, player_age=14)
        assert not any("missing required" in w.lower() for w in warnings)


# --- Archetype Detection ---

class TestArchetypeDetection:
    def test_zigzag_pattern_maps_to_cone_weave(self):
        from drill_post_processor import map_pattern_to_archetype
        assert map_pattern_to_archetype("zigzag") == "cone_weave"

    def test_triangle_pattern_maps_to_triangle_passing(self):
        from drill_post_processor import map_pattern_to_archetype
        assert map_pattern_to_archetype("triangle") == "triangle_passing"

    def test_wall_pass_sequence_maps_to_wall_passing(self):
        from drill_post_processor import map_pattern_to_archetype
        assert map_pattern_to_archetype("wall_pass_sequence") == "wall_passing"

    def test_free_pattern_returns_none(self):
        from drill_post_processor import map_pattern_to_archetype
        assert map_pattern_to_archetype("free") is None

    def test_rondo_circle_maps_to_rondo(self):
        from drill_post_processor import map_pattern_to_archetype
        assert map_pattern_to_archetype("rondo_circle") == "rondo"
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/evantakahashi/Desktop/TechnIQ/functions && python -m pytest test_drill_post_processor.py -v 2>&1 | tail -30`
Expected: FAIL — `ModuleNotFoundError: No module named 'drill_post_processor'`

- [ ] **Step 3: Implement the post-processor**

Create `functions/drill_post_processor.py`:

```python
"""
Deterministic post-processor for AI-generated drill diagrams.
Validates and fixes spatial issues, path consistency, equipment alignment.
Runs after Writer phase, before Referee phase. No LLM calls.
"""
import math
import logging
from typing import Dict, List, Tuple

logger = logging.getLogger(__name__)

# Valid targets for "pass" style paths
VALID_PASS_TARGETS = {"player", "server", "defender", "wall", "goal"}

# Equipment → element type mapping
EQUIPMENT_TO_ELEMENT = {
    "ball": {"ball"},
    "cones": {"cone"},
    "goals": {"goal"},
    "wall": {"wall"},
    "partner": {"player", "server", "defender"},
    "hurdles": {"cone"},
    "ladder": {"cone"},
    "poles": {"cone"},
}

MIN_SPACING = 2.0  # meters
BOUNDS_PADDING = 1.0  # meters from edge

# Age group max cone spacing (meters)
AGE_MAX_CONE_SPACING = {
    8: 7,    # U8: max 7m between cones
    12: 10,  # U12: max 10m
    99: 15,  # U13+: max 15m
}

# Coach pattern_type → canonical archetype mapping
PATTERN_TO_ARCHETYPE = {
    "zigzag": "cone_weave",
    "linear": "cone_weave",
    "triangle": "triangle_passing",
    "diamond": "triangle_passing",
    "square": "triangle_passing",
    "wall_pass_sequence": "wall_passing",
    "channel": "server_executor",
    "overlap_run": "server_executor",
    "rondo_circle": "rondo",
    "gates": "gate_dribbling",
    "grid": "gate_dribbling",
    "free": None,  # No snapping for free-form
}

REQUIRED_FIELDS = ["name", "description", "setup", "instructions", "diagram",
                   "difficulty", "category", "targetSkills", "equipment"]


def map_pattern_to_archetype(pattern_type: str) -> str | None:
    """Map Coach phase pattern_type to canonical archetype name."""
    return PATTERN_TO_ARCHETYPE.get(pattern_type)


def post_process_drill(drill: Dict, player_age: int = 14) -> Tuple[Dict, List[str]]:
    """
    Validate and fix a drill's diagram. Returns (fixed_drill, warnings).

    Args:
        drill: The drill dict from the Writer phase
        player_age: Player's age for age-appropriate spacing validation

    Returns:
        Tuple of (fixed_drill_dict, list_of_warning_strings)
    """
    warnings: List[str] = []
    diagram = drill.get("diagram", {})
    field = diagram.get("field", {"width": 20, "length": 15})
    elements = diagram.get("elements", [])
    paths = diagram.get("paths", [])
    equipment = drill.get("equipment", [])
    instructions = drill.get("instructions", [])

    width = field.get("width", 20)
    length = field.get("length", 15)

    # 0. Schema completeness
    schema_warnings = _check_schema(drill)
    warnings.extend(schema_warnings)

    # 1. Bounds clamping
    elements = _clamp_bounds(elements, width, length)

    # 2. Overlap resolution
    elements = _resolve_overlaps(elements, width, length)

    # 3. Path validation (includes duplicate removal)
    paths, path_warnings = _validate_paths(paths, elements, instructions)
    warnings.extend(path_warnings)

    # 4. Equipment consistency
    equip_warnings = _check_equipment_consistency(equipment, elements)
    warnings.extend(equip_warnings)

    # 5. Age-appropriate spacing
    spacing_warnings = _check_age_spacing(elements, player_age)
    warnings.extend(spacing_warnings)

    # Write back
    drill["diagram"]["elements"] = elements
    drill["diagram"]["paths"] = paths

    return drill, warnings


def _check_schema(drill: Dict) -> List[str]:
    """Check for required top-level fields."""
    warnings = []
    for field in REQUIRED_FIELDS:
        if field not in drill:
            warnings.append(f"Missing required field: {field}")
    return warnings


def _clamp_bounds(elements: List[Dict], width: float, length: float) -> List[Dict]:
    """Clamp all element coordinates within field bounds with padding."""
    for el in elements:
        el["x"] = max(BOUNDS_PADDING, min(el.get("x", 0), width - BOUNDS_PADDING))
        el["y"] = max(BOUNDS_PADDING, min(el.get("y", 0), length - BOUNDS_PADDING))
    return elements


def _resolve_overlaps(elements: List[Dict], width: float, length: float) -> List[Dict]:
    """Nudge overlapping elements apart until all have >= MIN_SPACING."""
    max_iterations = 50
    for _ in range(max_iterations):
        moved = False
        for i in range(len(elements)):
            for j in range(i + 1, len(elements)):
                dx = elements[j]["x"] - elements[i]["x"]
                dy = elements[j]["y"] - elements[i]["y"]
                dist = math.sqrt(dx * dx + dy * dy)
                if dist < MIN_SPACING:
                    # Nudge apart along the vector between them
                    if dist == 0:
                        dx, dy = 1.0, 0.0
                        dist = 1.0
                    nudge = (MIN_SPACING - dist) / 2 + 0.1
                    nx = (dx / dist) * nudge
                    ny = (dy / dist) * nudge
                    elements[i]["x"] -= nx
                    elements[i]["y"] -= ny
                    elements[j]["x"] += nx
                    elements[j]["y"] += ny
                    # Re-clamp after nudge
                    for el in [elements[i], elements[j]]:
                        el["x"] = max(BOUNDS_PADDING, min(el["x"], width - BOUNDS_PADDING))
                        el["y"] = max(BOUNDS_PADDING, min(el["y"], length - BOUNDS_PADDING))
                    moved = True
        if not moved:
            break
    return elements


def _validate_paths(
    paths: List[Dict], elements: List[Dict], instructions: List[str]
) -> Tuple[List[Dict], List[str]]:
    """Validate paths: references, pass targets, step alignment."""
    warnings = []
    label_set = {el.get("label") for el in elements}
    label_to_type = {el.get("label"): el.get("type") for el in elements}
    valid_paths = []
    seen_paths = set()

    for path in paths:
        # Duplicate removal
        path_key = (path.get("from"), path.get("to"), path.get("style"), path.get("step"))
        if path_key in seen_paths:
            continue
        seen_paths.add(path_key)
        from_label = path.get("from", "")
        to_label = path.get("to", "")

        # Check references exist
        if from_label not in label_set or to_label not in label_set:
            missing = []
            if from_label not in label_set:
                missing.append(from_label)
            if to_label not in label_set:
                missing.append(to_label)
            warnings.append(f"Removed path: label(s) {', '.join(missing)} not found in elements")
            continue

        # Check pass targets
        if path.get("style") == "pass":
            target_type = label_to_type.get(to_label, "")
            if target_type not in VALID_PASS_TARGETS:
                warnings.append(
                    f"Invalid pass target: pass to {target_type} '{to_label}' — "
                    f"passes can only target player, server, defender, wall, or goal"
                )

        valid_paths.append(path)

    # Check step-instruction alignment
    steps_with_paths = {p.get("step") for p in valid_paths if p.get("step") is not None}
    for i in range(1, len(instructions) + 1):
        if steps_with_paths and i not in steps_with_paths:
            warnings.append(f"Instruction step {i} has no matching diagram path")

    # Check for orphan steps (path step > number of instructions)
    for path in valid_paths:
        step = path.get("step")
        if step is not None and step > len(instructions):
            warnings.append(f"Path step {step} exceeds instruction count ({len(instructions)})")

    return valid_paths, warnings


def _check_age_spacing(elements: List[Dict], player_age: int) -> List[str]:
    """Warn if cone spacing exceeds age-appropriate maximum."""
    warnings = []
    # Determine max spacing for age
    max_spacing = 15  # default
    for age_limit, spacing in sorted(AGE_MAX_CONE_SPACING.items()):
        if player_age <= age_limit:
            max_spacing = spacing
            break

    cones = [el for el in elements if el.get("type") == "cone"]
    for i in range(len(cones)):
        for j in range(i + 1, len(cones)):
            dx = cones[j]["x"] - cones[i]["x"]
            dy = cones[j]["y"] - cones[i]["y"]
            dist = math.sqrt(dx * dx + dy * dy)
            if dist > max_spacing:
                warnings.append(
                    f"Cone spacing {dist:.1f}m between '{cones[i].get('label')}' and "
                    f"'{cones[j].get('label')}' exceeds {max_spacing}m max for age {player_age}"
                )
    return warnings


def _check_equipment_consistency(equipment: List[str], elements: List[Dict]) -> List[str]:
    """Check that every equipment item has a corresponding diagram element."""
    warnings = []
    element_types = {el.get("type") for el in elements}

    for item in equipment:
        if item == "none":
            continue
        expected_types = EQUIPMENT_TO_ELEMENT.get(item)
        if expected_types is None:
            continue  # Unknown equipment, skip
        if not expected_types.intersection(element_types):
            warnings.append(f"Equipment '{item}' missing from diagram — no {'/'.join(expected_types)} element found")

    return warnings
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/evantakahashi/Desktop/TechnIQ/functions && python -m pytest test_drill_post_processor.py -v 2>&1 | tail -40`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add functions/drill_post_processor.py functions/test_drill_post_processor.py
git commit -m "feat: add drill diagram post-processor with spatial validation"
```

---

### Task 4: Integrate post-processor into pipeline

**Files:**
- Modify: `functions/main.py:326-373` (generate_drill_pipeline), `functions/main.py:631-671` (programmatic_validate), `functions/main.py:674-727` (phase_referee)

- [ ] **Step 1: Import post-processor at top of generate_drill_pipeline**

In `functions/main.py`, in the `generate_drill_pipeline` function (line 326), add import after the Anthropic import:

```python
def generate_drill_pipeline(player_profile: Dict, requirements: Dict, session_context: Dict, drill_feedback: list, field_size: str, anthropic_api_key: str) -> Dict:
    """4-phase agentic drill generation: Scout → Coach → Writer → PostProcess → Referee"""
    from anthropic import Anthropic
    from drill_post_processor import post_process_drill
    client = Anthropic(api_key=anthropic_api_key)
```

- [ ] **Step 2: Insert post-processor into the Writer→Referee loop**

Replace the loop body in `generate_drill_pipeline` (lines 348-367):

```python
    for attempt in range(3):
        logger.info(f"✍️ Phase 3: Writer - Attempt {attempt + 1}/3...")
        drill = phase_writer(client, skeletal_plan, focus_strategy, requirements, field_dims, revision_errors)

        # === Post-Process ===
        logger.info("🔧 Post-processing diagram...")
        player_age = player_profile.get('age', 14)
        drill, pp_warnings = post_process_drill(drill, player_age=player_age)
        if pp_warnings:
            logger.info(f"⚠️ Post-processor warnings: {pp_warnings}")

        logger.info(f"⚖️ Phase 4: Referee - Validating...")
        validation = phase_referee(client, drill, focus_strategy, requirements, field_dims, pp_warnings)

        score = validation.get("score", 0)
        if score > best_score:
            best_score = score
            best_drill = drill

        if validation.get("verdict") == "VALID":
            logger.info(f"✅ Drill validated on attempt {attempt + 1} (score={score})")
            if pp_warnings:
                drill["validationWarnings"] = pp_warnings
            return drill

        # Collect errors for next attempt
        errors = validation.get("errors", [])
        revision_errors = [f"{e['check']}: {e['issue']}. Fix: {e['fix']}" for e in errors]
        if pp_warnings:
            revision_errors.extend([f"post_process: {w}" for w in pp_warnings])
        logger.info(f"⚠️ Referee found {len(errors)} errors, retrying...")
```

- [ ] **Step 3: Update phase_referee to accept post-processor warnings**

Change `phase_referee` signature (line 674) to accept warnings:

```python
def phase_referee(client, drill: Dict, focus_strategy: Dict, requirements: Dict, field_dims: Dict, post_process_warnings: list = None) -> Dict:
    """Phase 4: Validate drill quality (LLM-only, programmatic checks moved to post-processor)"""
```

Remove the `programmatic_validate` call (lines 676-679) since the post-processor handles it now. Add post-processor warnings to the Referee prompt context:

```python
    pp_context = ""
    if post_process_warnings:
        pp_context = "\nPost-processor warnings (already applied fixes where possible):\n"
        for w in post_process_warnings:
            pp_context += f"- {w}\n"
```

In the Referee prompt f-string, insert `{pp_context}` after the "Context:" block (after the `Difficulty:` line, before `Validate:`):

```python
Context:
- Target weakness: {focus_strategy.get('primary_weakness', '')}
- Field size: {field_dims['width']}m x {field_dims['length']}m
- Available equipment: {', '.join(requirements.get('equipment', []))}
- Difficulty: {requirements.get('difficulty', 'intermediate')}
{pp_context}
Validate:
```

- [ ] **Step 4: Delete programmatic_validate function**

Remove the `programmatic_validate` function (lines 631-671) entirely — its checks are now in `drill_post_processor.py`.

- [ ] **Step 5: Test post-processor import**

Run: `cd /Users/evantakahashi/Desktop/TechnIQ/functions && python -c "from drill_post_processor import post_process_drill; print('import OK')"`
Expected: `import OK`

Note: `main.py` top-level imports require Firebase SDK — full import testing needs `firebase deploy` or the functions virtualenv.

- [ ] **Step 6: Commit**

```bash
git add functions/main.py
git commit -m "feat: integrate post-processor into drill pipeline, replace programmatic_validate"
```

---

## Chunk 3: Prompt Enrichment

### Task 5: Enrich Scout prompt with player-tailored archetype selection

**Files:**
- Modify: `functions/main.py:376-489` (phase_scout)

- [ ] **Step 1: Add archetype filtering by experience level**

In `phase_scout`, before the prompt string (around line 446), add:

```python
    # Archetype filtering by experience level
    exp_level = player_profile.get('experienceLevel', 'intermediate')
    age = player_profile.get('age', 14)
    position = player_profile.get('position', 'midfielder')
    playing_style = player_profile.get('playingStyle', '')

    archetype_by_level = {
        "beginner": "cone_weave, wall_passing, gate_dribbling, dribble_and_shoot",
        "intermediate": "cone_weave, wall_passing, gate_dribbling, dribble_and_shoot, relay_shuttle, server_executor, triangle_passing",
        "advanced": "cone_weave, wall_passing, gate_dribbling, dribble_and_shoot, relay_shuttle, server_executor, triangle_passing, 1v1_plus_server, rondo"
    }
    available_archetypes = archetype_by_level.get(exp_level, archetype_by_level["intermediate"])

    # Age-based spacing context
    if age <= 8:
        spacing_context = "Age U8: cone spacing 1-2m, passing distance 5-7m, drill duration 3-5 min"
    elif age <= 12:
        spacing_context = "Age U12: cone spacing 2-3m, passing distance 8-10m, drill duration 8-12 min"
    else:
        spacing_context = "Age U13+: cone spacing 3-5m, passing distance 10-15m, drill duration 10-15 min"

    # Position-based archetype weighting
    position_hints = {
        "winger": "Prefer 1v1 dribbling, change of direction, crossing drills",
        "midfielder": "Prefer passing patterns, possession, transition drills",
        "striker": "Prefer finishing, first touch, 1v1 vs keeper drills",
        "defender": "Prefer 1v1 defending, clearance, recovery run drills",
        "goalkeeper": "Prefer shot-stopping, distribution, positioning drills"
    }
    position_hint = position_hints.get(position.lower(), "")
```

- [ ] **Step 2: Add archetype/spacing/position context to Scout prompt**

Append to the Scout prompt string (before the "Return JSON:" line):

```python
Available archetypes for {exp_level} level: {available_archetypes}
{spacing_context}
{position_hint}
Playing style: {playing_style}

You MUST pick a drill_archetype from the available archetypes list above.
```

- [ ] **Step 3: Commit**

```bash
git add functions/main.py
git commit -m "feat: enrich Scout prompt with player-tailored archetype selection"
```

---

### Task 6: Enrich Writer prompt with realism rules and element types

**Files:**
- Modify: `functions/main.py:556-628` (phase_writer)

- [ ] **Step 1: Update element types in Writer prompt**

In `phase_writer`, replace line 599:
```
- element types: "cone", "player", "target", "goal", "ball"
```
With:
```
- element types: "cone", "player", "defender", "server", "wall", "mannequin", "target", "goal", "ball"
- Use "defender" for opposition players, "server" for feeders/passers, "mannequin" for passive obstacles, "wall" for rebound walls
- Use "player" only for the main player or generic attackers
```

- [ ] **Step 2: Add player-tailored context to Writer prompt**

In `phase_writer`, add player context extraction at the top of the function (after line 561). The function doesn't currently receive `player_profile`, so update the signature and the call site:

Update `phase_writer` signature:
```python
def phase_writer(client, skeletal_plan: Dict, focus_strategy: Dict, requirements: Dict, field_dims: Dict, revision_errors: list, player_profile: Dict = None) -> Dict:
```

Add after the existing variable declarations:
```python
    # Player-tailored context
    player_context = ""
    if player_profile:
        age = player_profile.get('age', 14)
        exp_level = player_profile.get('experienceLevel', 'intermediate')
        position = player_profile.get('position', '')
        playing_style = player_profile.get('playingStyle', '')
        weaknesses = player_profile.get('weaknesses', [])
        skill_goals = player_profile.get('skillGoals', [])

        if age <= 8:
            spacing_rule = "Cone spacing: 1-2m. Passing distance: 5-7m. Duration: 3-5 min. Keep instructions very simple."
        elif age <= 12:
            spacing_rule = "Cone spacing: 2-3m. Passing distance: 8-10m. Duration: 8-12 min."
        else:
            spacing_rule = "Cone spacing: 3-5m. Passing distance: 10-15m. Duration: 10-15 min."

        success_criteria = {
            "beginner": "Include a measurable goal like 'complete 10 passes without losing control'",
            "intermediate": "Include a measurable goal like 'complete 15 passes in 45 seconds'",
            "advanced": "Include a measurable challenge like 'complete 20 weak-foot passes in 30 seconds'"
        }

        player_context = f"""
PLAYER CONTEXT (tailor drill to this player):
- Age: {age}, Level: {exp_level}, Position: {position}, Style: {playing_style}
- Skill goals: {', '.join(skill_goals) if skill_goals else 'none specified'}
- {spacing_rule}
- {success_criteria.get(exp_level, success_criteria['intermediate'])}
- Coaching points must be body-mechanic specific (e.g., "lock ankle", "chest over ball", "check shoulder") — NOT generic ("practice more")
- Movement after passing is mandatory — passer must move to a new position
- Multi-player drills must assign clear roles with rotation instructions
"""
```

Add `{player_context}` to the prompt string before `INSTRUCTION RULES:`.

- [ ] **Step 3: Update the phase_writer call in generate_drill_pipeline**

In `generate_drill_pipeline` (around line 350), pass `player_profile`:

```python
        drill = phase_writer(client, skeletal_plan, focus_strategy, requirements, field_dims, revision_errors, player_profile)
```

- [ ] **Step 4: Commit**

```bash
git add functions/main.py
git commit -m "feat: enrich Writer prompt with player-tailored context and new element types"
```

---

### Task 7: Enrich Referee prompt with player-fit validation

**Files:**
- Modify: `functions/main.py:674-727` (phase_referee)

- [ ] **Step 1: Add player-fit validation items to Referee prompt**

In `phase_referee`, update the validation checklist in the prompt. Add after item 8:

```
9. PLAYER-FIT: Are distances age-appropriate? Is difficulty matched to experience level? Does the drill target the identified weakness specifically (not generically)?
10. ROLES: If multi-player, does every player have a clear role and rotation?
11. SUCCESS CRITERIA: Is there a measurable outcome (e.g., "complete X passes in Y seconds")?
```

- [ ] **Step 2: Commit**

```bash
git add functions/main.py
git commit -m "feat: enrich Referee prompt with player-fit validation checks"
```

---

## Chunk 4: Final Verification

### Task 8: Run all tests and verify

**Files:**
- All modified files

- [ ] **Step 1: Run Python post-processor tests**

Run: `cd /Users/evantakahashi/Desktop/TechnIQ/functions && python -m pytest test_drill_post_processor.py -v`
Expected: All tests PASS

- [ ] **Step 2: Run Swift tests**

Run: `xcodebuild test -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' -only-testing:TechnIQTests/DrillDiagramTests 2>&1 | tail -20`
Expected: All tests PASS

- [ ] **Step 3: Full build**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Verify no broken imports**

Run: `cd /Users/evantakahashi/Desktop/TechnIQ/functions && python -c "from drill_post_processor import post_process_drill, map_pattern_to_archetype; print('All imports OK')"`
Expected: `All imports OK`

---

## Deferred Items

- **Integration test (`test_drill_pipeline_integration.py`):** Spec requires this but full pipeline testing needs live Anthropic API calls (cost per run). Deferred to manual testing via `test_model_comparison.py` pattern after deployment. Could add mocked integration test in a follow-up.
