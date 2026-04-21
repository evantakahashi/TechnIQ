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
