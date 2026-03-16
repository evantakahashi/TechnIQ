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
        result, warnings = post_process_drill(drill, player_age=14)
        assert any("pass" in w.lower() and "cone" in w.lower() for w in warnings)
        assert len(result["diagram"]["paths"]) == 0  # invalid pass path removed

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
        result, warnings = post_process_drill(drill, player_age=14)
        assert any("pass" in w.lower() and "mannequin" in w.lower() for w in warnings)
        assert len(result["diagram"]["paths"]) == 0

    def test_pass_to_ball_flagged(self):
        drill = make_drill(
            elements=[make_el("player", 5, 5, "P1"), make_el("ball", 8, 8, "B1")],
            paths=[make_path("P1", "B1", "pass", 1)]
        )
        result, warnings = post_process_drill(drill, player_age=14)
        assert any("invalid pass target" in w.lower() for w in warnings)
        assert len(result["diagram"]["paths"]) == 0


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

    def test_channel_pattern_maps_to_server_executor(self):
        from drill_post_processor import map_pattern_to_archetype
        assert map_pattern_to_archetype("channel") == "server_executor"

    def test_overlap_run_pattern_maps_to_server_executor(self):
        from drill_post_processor import map_pattern_to_archetype
        assert map_pattern_to_archetype("overlap_run") == "server_executor"
