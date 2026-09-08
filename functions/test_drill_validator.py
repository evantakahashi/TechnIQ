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
    drill["is_duel"] = True
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
        {"type": "ball", "x": 15, "y": 0, "label": "B1"},
    ]
    drill["diagram"]["paths"] = [
        {"from": "P2", "to": "P1", "style": "toss", "step": 1},
    ]
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


def test_lane_gate_crossed_by_pass_passes():
    drill = make_valid_drill()
    drill["equipment"].append("partner")
    drill["diagram"]["elements"] += [
        {"type": "ball", "x": -2, "y": 0, "label": "B1"},
        {"type": "player", "x": 10, "y": 0, "label": "P2", "role": "server"},
        {"type": "gate", "x": 4, "y": 0, "width": 2, "label": "G5"},  # on the P1-P2 lane
    ]
    drill["diagram"]["paths"].append({"from": "P1", "to": "P2", "style": "pass", "step": 2})
    validate_drill(drill)  # pass crosses the lane gate


def test_multiple_balls_raise():
    drill = make_valid_drill()
    drill["diagram"]["elements"] += [
        {"type": "ball", "x": -2, "y": 0, "label": "B1"},
        {"type": "ball", "x": 3, "y": 3, "label": "B2"},
    ]
    with pytest.raises(ValidationError, match="exactly ONE ball"):
        validate_drill(drill)


def test_dribble_then_receive_hands_over():
    drill = make_valid_drill()
    drill["equipment"].append("partner")
    drill["diagram"]["elements"] += [
        {"type": "ball", "x": -2, "y": 0, "label": "B1"},
        {"type": "player", "x": 8, "y": 0, "label": "P2", "role": "server"},
    ]
    drill["diagram"]["paths"] = [
        {"from": "P1", "to": "P2", "style": "dribble", "step": 1},
        {"from": "P2", "to": "P1", "style": "receive", "step": 2},  # explicit handover
        {"from": "P2", "to": "P1", "style": "pass", "step": 3},
    ]
    validate_drill(drill)


def test_duel_cone_rejected():
    drill = make_valid_drill()  # has a cone
    drill["is_duel"] = True
    drill["equipment"].append("partner")
    drill["diagram"]["elements"].append(
        {"type": "player", "x": 6, "y": 0, "label": "P2", "role": "server"}
    )
    with pytest.raises(ValidationError, match="no cones"):
        validate_drill(drill)


def test_duel_defender_behind_attacker_rejected():
    drill = {"diagram": {"field": {"width": 20, "length": 15}, "elements": [
        {"type": "player", "x": 10, "y": 7.5, "label": "A", "role": "server"},
        {"type": "player", "x": 16, "y": 7.5, "label": "D", "role": "worker"},
        {"type": "ball", "x": 10, "y": 7.5, "label": "B1"},
        {"type": "gate", "x": 2, "y": 4, "width": 2, "label": "G1"},
        {"type": "gate", "x": 2, "y": 11, "width": 2, "label": "G2"},
    ], "paths": [
        {"from": "A", "to": "D", "style": "dribble", "step": 1, "fx": 10.0, "fy": 7.5, "tx": 16.0, "ty": 7.5},
    ]}, "equipment": ["ball", "partner"], "coaching_points": [], "is_duel": True}
    with pytest.raises(ValidationError, match="BETWEEN the"):
        validate_drill(drill)


def test_coords_in_coaching_rejected():
    drill = make_valid_drill()
    drill["coaching_points"] = ["start on the ball at (5, 7.5) and drive"]
    with pytest.raises(ValidationError, match="raw coordinates"):
        validate_drill(drill)


def test_run_while_carrying_raises():
    drill = make_valid_drill()
    drill["diagram"]["elements"].append({"type": "ball", "x": -2, "y": 0, "label": "B1"})
    drill["diagram"]["paths"] = [
        {"from": "P1", "to": "C1", "style": "run", "step": 1},  # has ball at feet
    ]
    with pytest.raises(ValidationError, match="runs while carrying"):
        validate_drill(drill)


def test_zero_length_pass_raises():
    drill = make_valid_drill()
    drill["equipment"].append("partner")
    drill["diagram"]["elements"] += [
        {"type": "ball", "x": -2, "y": 0, "label": "B1"},
        {"type": "player", "x": 8, "y": 0, "label": "P2", "role": "server"},
    ]
    drill["diagram"]["paths"] = [
        {"from": "P1", "to": "P2", "style": "pass", "step": 1, "fx": 5.0, "fy": 0.0, "tx": 5.0, "ty": 0.0},
    ]
    with pytest.raises(ValidationError, match="under 1m"):
        validate_drill(drill)


def _solo_pass_drill(target):
    return {
        "diagram": {
            "field": {"width": 20, "length": 15},
            "elements": [
                target,
                {"type": "ball", "x": 5, "y": 7, "label": "B1"},
                {"type": "player", "x": 5, "y": 8, "label": "P1", "role": "worker"},
            ],
            "paths": [{"from": "P1", "to": target["label"], "style": "pass", "step": 1}],
        },
        "coaching_points": [],
        "equipment": ["ball"],
    }


def test_solo_pass_to_cone_raises():
    drill = _solo_pass_drill({"type": "cone", "x": 12, "y": 7, "label": "C1"})
    drill["equipment"].append("cones")
    with pytest.raises(ValidationError, match="nobody is there"):
        validate_drill(drill)


def test_solo_pass_to_wall_passes():
    drill = _solo_pass_drill({"type": "wall", "x": 12, "y": 7, "label": "W1"})
    drill["equipment"].append("wall")
    validate_drill(drill)


def test_solo_pass_through_gate_passes():
    # The user's own 4-gate first-touch spec: gates ARE solo pass targets.
    drill = _solo_pass_drill({"type": "gate", "x": 12, "y": 7, "label": "G1", "width": 2})
    drill["equipment"].append("cones")
    drill["diagram"]["paths"].append(
        {"from": "P1", "to": "G1", "style": "run", "step": 2})
    validate_drill(drill)
