"""Tests for drill_validator."""
import pytest
from drill_validator import validate_drill, ValidationError


def make_valid_drill():
    return {
        "diagram": {
            "field": {"width": 20, "length": 15},
            "elements": [
                {"type": "cone", "x": 0, "y": 0, "label": "C1"},
                {"type": "player", "x": -2, "y": 0, "label": "P1", "role": "worker"},
            ],
            "paths": [
                {"from": "P1", "to": "C1", "style": "dribble", "step": 1},
            ],
        },
        "coaching_points": [],
        "equipment": ["ball", "cones"],
    }


def test_valid_drill_passes():
    validate_drill(make_valid_drill())  # no exception


def test_missing_element_target_raises():
    drill = make_valid_drill()
    drill["diagram"]["paths"][0]["to"] = "GHOST"
    with pytest.raises(ValidationError, match="references unknown element"):
        validate_drill(drill)


def test_missing_element_source_raises():
    drill = make_valid_drill()
    drill["diagram"]["paths"][0]["from"] = "GHOST"
    with pytest.raises(ValidationError, match="references unknown element"):
        validate_drill(drill)


def test_non_contiguous_step_raises():
    drill = make_valid_drill()
    drill["diagram"]["paths"].append(
        {"from": "P1", "to": "C1", "style": "dribble", "step": 3}
    )
    with pytest.raises(ValidationError, match="step numbers"):
        validate_drill(drill)


def test_goal_mid_field_raises():
    drill = make_valid_drill()
    drill["diagram"]["elements"].append({"type": "goal", "x": 10, "y": 7, "label": "GL"})
    drill["equipment"].append("goals")
    with pytest.raises(ValidationError, match="floats mid-field"):
        validate_drill(drill)


def test_goal_on_edge_passes():
    drill = make_valid_drill()
    drill["diagram"]["elements"].append({"type": "goal", "x": 19, "y": 7, "label": "GL"})
    drill["equipment"].append("goals")
    validate_drill(drill)  # no exception


def test_shot_at_ball_raises():
    drill = make_valid_drill()
    drill["diagram"]["elements"].append({"type": "ball", "x": 5, "y": 5, "label": "B5"})
    drill["diagram"]["paths"].append(
        {"from": "P1", "to": "B5", "style": "shoot", "step": 2}
    )
    with pytest.raises(ValidationError, match="shots must aim at a goal, gate, or wall"):
        validate_drill(drill)


def test_shot_at_gate_passes():
    drill = make_valid_drill()
    drill["diagram"]["elements"].append({"type": "gate", "x": 10, "y": 5, "label": "G1"})
    drill["diagram"]["paths"].append(
        {"from": "P1", "to": "G1", "style": "shoot", "step": 2}
    )
    validate_drill(drill)  # no exception


def test_equipment_mismatch_raises():
    drill = make_valid_drill()
    drill["diagram"]["elements"].append(
        {"type": "goal", "x": 10, "y": 0, "label": "GL"}
    )
    with pytest.raises(ValidationError, match="equipment"):
        validate_drill(drill)


def test_no_worker_raises():
    drill = make_valid_drill()
    drill["diagram"]["elements"][1]["role"] = "server"
    with pytest.raises(ValidationError, match="worker"):
        validate_drill(drill)


def test_no_steps_raises():
    drill = make_valid_drill()
    drill["diagram"]["paths"] = []
    with pytest.raises(ValidationError, match="at least one"):
        validate_drill(drill)


def test_server_plus_worker_passes():
    drill = make_valid_drill()
    drill["diagram"]["elements"].append(
        {"type": "player", "x": 5, "y": 0, "label": "P2", "role": "server"}
    )
    validate_drill(drill)  # still has P1 as worker


def test_player_without_role_does_not_count_as_worker():
    drill = make_valid_drill()
    # remove role from the only player
    del drill["diagram"]["elements"][1]["role"]
    with pytest.raises(ValidationError, match="worker"):
        validate_drill(drill)


class TestEquipmentNormalization:
    """Equipment strings from users/AI drift from canonical keys — lookups must tolerate it."""

    def _drill_with_goal(self, equipment):
        return {
            "equipment": equipment,
            "diagram": {
                "field": {"width": 20, "length": 15},
                "elements": [
                    {"label": "P1", "type": "player", "role": "worker", "x": 5, "y": 5},
                    {"label": "B1", "type": "ball", "x": 6, "y": 5},
                    {"label": "G1", "type": "goal", "x": 10, "y": 14},
                ],
                "paths": [{"step": 1, "from": "P1", "to": "G1", "type": "shot"}],
            },
        }

    def test_singular_goal_authorizes_goal_element(self):
        validate_drill(self._drill_with_goal(["ball", "goal"]))

    def test_capitalized_and_padded(self):
        validate_drill(self._drill_with_goal(["Ball", " Goals "]))

    def test_compound_name(self):
        validate_drill(self._drill_with_goal(["ball", "mini goal"]))

    def test_unrelated_equipment_still_rejected(self):
        import pytest as _pytest
        from drill_validator import ValidationError
        with _pytest.raises(ValidationError):
            validate_drill(self._drill_with_goal(["ball", "cones"]))


def test_gate_outside_goal_mouth_raises():
    drill = make_valid_drill()
    drill["equipment"].append("goals")
    drill["diagram"]["elements"] += [
        {"type": "goal", "x": 19, "y": 7.5, "width": 7.32, "label": "GL"},
        # goal mouth spans y 3.84-11.16; gate at y=13 is outside the posts
        {"type": "gate", "x": 19, "y": 13, "width": 1.2, "label": "G1"},
    ]
    with pytest.raises(ValidationError, match="outside the goal mouth"):
        validate_drill(drill)


def test_gate_inside_goal_mouth_passes():
    drill = make_valid_drill()
    drill["equipment"].append("goals")
    drill["diagram"]["elements"] += [
        {"type": "goal", "x": 19, "y": 7.5, "width": 7.32, "label": "GL"},
        {"type": "gate", "x": 19, "y": 9.7, "width": 1.2, "label": "G1"},
        {"type": "ball", "x": -2, "y": 0, "label": "B1"},
    ]
    drill["diagram"]["paths"].append({"from": "P1", "to": "G1", "style": "shoot", "step": 2})
    validate_drill(drill)  # no exception


def test_free_standing_gate_far_from_goal_passes():
    drill = make_valid_drill()
    drill["equipment"].append("goals")
    drill["diagram"]["elements"] += [
        {"type": "goal", "x": 19, "y": 7.5, "width": 7.32, "label": "GL"},
        {"type": "gate", "x": 5, "y": 5, "width": 2, "label": "G2"},
        {"type": "ball", "x": -2, "y": 0, "label": "B1"},
    ]
    drill["diagram"]["paths"].append({"from": "P1", "to": "G2", "style": "dribble", "step": 2})
    validate_drill(drill)  # dribbling gate elsewhere is fine


def test_wall_rebound_keeps_possession():
    drill = make_valid_drill()
    drill["equipment"].append("wall")
    drill["diagram"]["elements"] += [
        {"type": "ball", "x": -2, "y": 0, "label": "B1"},
        {"type": "wall", "x": 8, "y": 0, "label": "W1"},
    ]
    drill["diagram"]["paths"] = [
        {"from": "P1", "to": "W1", "style": "pass", "step": 1},
        {"from": "P1", "to": "W1", "style": "pass", "step": 2},
        {"from": "P1", "to": "C1", "style": "dribble", "step": 3},
    ]
    validate_drill(drill)  # rebounds keep the ball at P1's feet


def test_throw_and_header_continuity():
    drill = make_valid_drill()
    drill["equipment"] += ["wall", "goals"]
    drill["diagram"]["elements"] += [
        {"type": "ball", "x": -2, "y": 0, "label": "B1"},
        {"type": "wall", "x": 8, "y": 0, "label": "W1"},
        {"type": "goal", "x": 19, "y": 7, "label": "GL"},
    ]
    drill["diagram"]["paths"] = [
        {"from": "P1", "to": "W1", "style": "throw", "step": 1},   # rebound back
        {"from": "P1", "to": "GL", "style": "header", "step": 2},  # rests at GL
        {"from": "P1", "to": "GL", "style": "run", "step": 3},     # collect
        {"from": "P1", "to": "C1", "style": "dribble", "step": 4},
    ]
    validate_drill(drill)


def test_header_without_ball_raises():
    drill = make_valid_drill()
    drill["equipment"].append("goals")
    drill["diagram"]["elements"] += [
        {"type": "ball", "x": 15, "y": 12, "label": "B1"},
        {"type": "goal", "x": 19, "y": 7, "label": "GL"},
    ]
    drill["diagram"]["paths"] = [
        {"from": "P1", "to": "GL", "style": "header", "step": 1},
    ]
    with pytest.raises(ValidationError, match="can only pass/dribble/shoot"):
        validate_drill(drill)


def test_duel_overscripted_raises():
    drill = make_valid_drill()
    drill["equipment"].append("partner")
    drill["diagram"]["elements"].append(
        {"type": "player", "x": 8, "y": 4, "label": "P2", "role": "defender"}
    )
    drill["diagram"]["paths"] = [
        {"from": "P1", "to": "C1", "style": "dribble", "step": i + 1}
        if i % 2 == 0 else
        {"from": "P2", "to": "P1", "style": "run", "step": i + 1}
        for i in range(8)
    ]
    with pytest.raises(ValidationError, match="max 3 steps"):
        validate_drill(drill)


def test_long_toss_raises():
    drill = make_valid_drill()
    drill["equipment"].append("partner")
    drill["diagram"]["elements"] += [
        {"type": "player", "x": 15, "y": 0, "label": "P2", "role": "server"},
        {"type": "ball", "x": -2, "y": 0, "label": "B0"},
        {"type": "ball", "x": 15, "y": 0, "label": "B1"},
    ]
    drill["diagram"]["paths"].append(
        {"from": "P2", "to": "P1", "style": "toss", "step": 2}
    )
    with pytest.raises(ValidationError, match="soft underhand tosses"):
        validate_drill(drill)


def test_header_volume_cap_raises():
    drill = make_valid_drill()
    drill["coaching_points"] = ["10 headers x 3 sets — attack the ball"]
    with pytest.raises(ValidationError, match="cap heading volume"):
        validate_drill(drill)


def test_decorative_gate_raises():
    drill = make_valid_drill()
    drill["diagram"]["elements"].append({"type": "gate", "x": 15, "y": 5, "label": "G9"})
    with pytest.raises(ValidationError, match="never played through"):
        validate_drill(drill)


def test_played_gate_passes():
    drill = make_valid_drill()
    drill["diagram"]["elements"] += [
        {"type": "ball", "x": -2, "y": 0, "label": "B1"},
        {"type": "gate", "x": 15, "y": 5, "label": "G9"},
    ]
    drill["diagram"]["paths"].append({"from": "P1", "to": "G9", "style": "dribble", "step": 2})
    validate_drill(drill)
