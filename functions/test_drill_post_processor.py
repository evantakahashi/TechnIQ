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

    def test_high_step_number_renumbered_to_one(self):
        drill = make_drill(
            elements=[make_el("player", 5, 5, "P1"), make_el("cone", 10, 10, "C1")],
            paths=[make_path("P1", "C1", "dribble", 5)],
            instructions=["Dribble from P1 to C1"]
        )
        result, _ = post_process_drill(drill, player_age=14)
        assert result["diagram"]["paths"][0]["step"] == 1

    def test_dropped_path_renumbers_remaining_steps(self):
        drill = make_drill(
            elements=[
                make_el("player", 5, 5, "P1"),
                make_el("cone", 10, 5, "C1"),
                make_el("cone", 15, 5, "C2"),
            ],
            paths=[
                make_path("P1", "C1", "pass", 1),     # dropped: cone is invalid pass target
                make_path("P1", "C1", "dribble", 2),
                make_path("P1", "C2", "pass", 3),     # dropped: cone is invalid pass target
                make_path("P1", "C2", "dribble", 4),
            ],
            instructions=["a", "b"],
        )
        result, _ = post_process_drill(drill, player_age=14)
        steps = [p["step"] for p in result["diagram"]["paths"]]
        assert steps == [1, 2], f"expected contiguous [1,2], got {steps}"


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


def test_annotate_path_positions_chains_player_movement():
    from drill_post_processor import annotate_path_positions
    drill = {"diagram": {
        "elements": [
            {"type": "player", "x": 2.0, "y": 5.0, "label": "P1", "role": "worker"},
            {"type": "cone", "x": 10.0, "y": 5.0, "label": "C1"},
            {"type": "goal", "x": 19.0, "y": 7.5, "label": "GL"},
        ],
        "paths": [
            {"step": 1, "from": "P1", "to": "C1", "style": "dribble"},
            {"step": 2, "from": "P1", "to": "GL", "style": "shoot"},
        ],
    }}
    annotate_path_positions(drill)
    p1, p2 = drill["diagram"]["paths"]
    assert (p1["fx"], p1["fy"]) == (2.0, 5.0)
    assert (p1["tx"], p1["ty"]) == (11.1, 5.0)  # cone is rounded, +1.1m overshoot
    # the shot originates from the cone P1 dribbled to, not the spawn point
    assert (p2["fx"], p2["fy"]) == (11.1, 5.0)  # shot starts where the dribble ended (past the cone)
    assert (p2["tx"], p2["ty"]) == (19.0, 7.5)


def test_annotate_ball_flight_does_not_move_player():
    from drill_post_processor import annotate_path_positions
    drill = {"diagram": {
        "elements": [
            {"type": "player", "x": 2.0, "y": 5.0, "label": "P1", "role": "worker"},
            {"type": "player", "x": 12.0, "y": 5.0, "label": "P2", "role": "server"},
        ],
        "paths": [
            {"step": 1, "from": "P1", "to": "P2", "style": "pass"},
            {"step": 2, "from": "P1", "to": "P2", "style": "run"},
        ],
    }}
    annotate_path_positions(drill)
    p1, p2 = drill["diagram"]["paths"]
    assert (p1["fx"], p1["fy"]) == (2.0, 5.0)  # pass leaves P1 in place
    assert (p2["fx"], p2["fy"]) == (2.0, 5.0)  # run starts from spawn too
    assert (p2["tx"], p2["ty"]) == (12.0, 5.0)


def test_reset_steps_tagged():
    from drill_post_processor import annotate_path_positions
    drill = {"diagram": {
        "elements": [
            {"type": "player", "x": 15, "y": 10, "label": "P1", "role": "worker"},
            {"type": "ball", "x": 15, "y": 10, "label": "B1"},
            {"type": "gate", "x": 29, "y": 8, "label": "G1"},
            {"type": "cone", "x": 21, "y": 10, "label": "C1"},
        ],
        "paths": [
            {"step": 1, "from": "P1", "to": "C1", "style": "dribble"},
            {"step": 2, "from": "P1", "to": "G1", "style": "shoot"},
            {"step": 3, "from": "P1", "to": "G1", "style": "run"},      # collect
            {"step": 4, "from": "P1", "to": "B1", "style": "dribble"},  # back to start
            {"step": 5, "from": "P1", "to": "C1", "style": "dribble"},
        ],
    }}
    annotate_path_positions(drill)
    tags = [bool(p.get("reset")) for p in drill["diagram"]["paths"]]
    assert tags == [False, False, True, True, False]


def test_crop_field_to_content_shrinks_oversized_stage():
    from drill_post_processor import crop_field_to_content
    drill = {"diagram": {"field": {"width": 52.5, "length": 68.0}, "elements": [
        {"type": "player", "x": 5.0, "y": 30.0, "label": "P1", "role": "worker"},
        {"type": "wall", "x": 12.0, "y": 30.0, "label": "W1"},
        {"type": "ball", "x": 5.0, "y": 30.0, "label": "B1"},
    ]}}
    crop_field_to_content(drill)
    f = drill["diagram"]["field"]
    assert f["width"] < 30 and f["length"] < 30
    assert min(e["x"] for e in drill["diagram"]["elements"]) >= 0


def test_crop_keeps_edge_goal_on_edge():
    from drill_post_processor import crop_field_to_content
    drill = {"diagram": {"field": {"width": 52.5, "length": 68.0}, "elements": [
        {"type": "player", "x": 40.0, "y": 34.0, "label": "P1", "role": "worker"},
        {"type": "goal", "x": 52.5, "y": 34.0, "label": "GL", "width": 7.32},
        {"type": "ball", "x": 40.0, "y": 34.0, "label": "B1"},
    ]}}
    crop_field_to_content(drill)
    f = drill["diagram"]["field"]
    gl = [e for e in drill["diagram"]["elements"] if e["type"] == "goal"][0]
    assert abs(gl["x"] - f["width"]) <= 0.01


def _carrier_run_drill():
    return {
        "name": "n", "description": "d", "setup": "s", "instructions": ["i"],
        "difficulty": 1, "category": "technical", "targetSkills": ["x"],
        "equipment": ["ball", "cones"],
        "diagram": {
            "field": {"width": 20, "length": 15},
            "elements": [
                {"type": "ball", "x": 5, "y": 7, "label": "B1"},
                {"type": "player", "x": 5, "y": 8, "label": "P1", "role": "worker"},
                {"type": "cone", "x": 12, "y": 7, "label": "C1"},
                {"type": "cone", "x": 16, "y": 7, "label": "C2"},
            ],
            "paths": [
                {"from": "P1", "to": "C1", "style": "dribble", "step": 1},
                {"from": "P1", "to": "C2", "style": "run", "step": 2},
            ],
        },
    }


def test_carrier_run_rewritten_to_dribble():
    drill, warnings = post_process_drill(_carrier_run_drill(), player_age=14)
    assert drill["diagram"]["paths"][1]["style"] == "dribble"
    assert any("rewrote as dribble" in w for w in warnings)


def test_ball_free_run_untouched():
    d = _carrier_run_drill()
    # shot leaves the ball at the gate target — the follow-up run is a real run
    d["diagram"]["elements"].append({"type": "gate", "x": 18, "y": 7, "label": "G1", "width": 2})
    d["diagram"]["paths"] = [
        {"from": "P1", "to": "C1", "style": "dribble", "step": 1},
        {"from": "P1", "to": "G1", "style": "shoot", "step": 2},
        {"from": "P1", "to": "G1", "style": "run", "step": 3},
    ]
    drill, _ = post_process_drill(d, player_age=14)
    assert drill["diagram"]["paths"][2]["style"] == "run"


def test_marker_targets_overshoot():
    """Movement THROUGH gates / AROUND cones bakes ~1m past the marker."""
    from drill_post_processor import annotate_path_positions
    d = {"diagram": {"field": {"width": 20, "length": 15}, "elements": [
        {"type": "player", "x": 2, "y": 7.5, "label": "P1"},
        {"type": "cone", "x": 10, "y": 7.5, "label": "C1"},
        {"type": "wall", "x": 18, "y": 7.5, "label": "W1"},
    ], "paths": [
        {"from": "P1", "to": "C1", "style": "dribble", "step": 1},
        {"from": "P1", "to": "W1", "style": "pass", "step": 2},
    ]}}
    annotate_path_positions(d)
    p1, p2 = d["diagram"]["paths"]
    assert p1["tx"] > 10.5  # past the cone, not on it
    assert p2["fx"] == p1["tx"]  # next action starts from the overshoot spot
    assert p2["tx"] == 18  # ball flight to a wall is NOT offset


def test_setup_touch_cone_pulled_close():
    """Model drew the cut cone 7m out — post-processor slides it to 3m."""
    d = {
        "name": "n", "description": "d", "setup": "s", "instructions": ["i"],
        "difficulty": 1, "category": "technical", "targetSkills": ["x"],
        "equipment": ["ball", "cones", "goals"],
        "diagram": {"field": {"width": 30, "length": 20}, "elements": [
            {"type": "player", "x": 4, "y": 10, "label": "P1", "role": "worker"},
            {"type": "ball", "x": 4, "y": 10, "label": "B1"},
            {"type": "cone", "x": 14, "y": 10, "label": "C1"},
            {"type": "cone", "x": 21, "y": 13, "label": "T1"},  # 7.6m cut
            {"type": "goal", "x": 29.5, "y": 10, "label": "GL", "width": 7.32},
        ], "paths": [
            {"from": "P1", "to": "C1", "style": "dribble", "step": 1},
            {"from": "P1", "to": "T1", "style": "dribble", "step": 2},
            {"from": "P1", "to": "GL", "style": "shoot", "step": 3},
        ]},
    }
    drill, warnings = post_process_drill(d, player_age=15)
    t1 = [e for e in drill["diagram"]["elements"] if e["label"] == "T1"][0]
    import math
    c1 = [e for e in drill["diagram"]["elements"] if e["label"] == "C1"][0]
    assert math.hypot(t1["x"] - c1["x"], t1["y"] - c1["y"]) <= 3.5
    assert any("pulled to 3m" in w for w in warnings)
