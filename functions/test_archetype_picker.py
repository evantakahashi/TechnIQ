"""Tests for archetype_picker."""
import pytest
from archetype_picker import pick_archetype, ARCHETYPE_TABLE, VALID_ARCHETYPES


def test_pick_archetype_under_pressure_beginner_returns_gate_dribbling():
    assert pick_archetype("Under Pressure", "beginner") == "gate_dribbling"


def test_pick_archetype_under_pressure_advanced_returns_rondo():
    assert pick_archetype("Under Pressure", "advanced") == "rondo"


def test_pick_archetype_finishing_beginner_returns_dribble_and_shoot():
    assert pick_archetype("Finishing", "beginner") == "dribble_and_shoot"


def test_pick_archetype_unknown_weakness_falls_back_to_cone_weave():
    assert pick_archetype("Completely Made Up Weakness", "beginner") == "cone_weave"


def test_pick_archetype_unknown_level_falls_back_to_cone_weave():
    assert pick_archetype("Under Pressure", "galactic-overlord") == "cone_weave"


def test_every_table_value_is_a_valid_archetype():
    for archetype in ARCHETYPE_TABLE.values():
        assert archetype in VALID_ARCHETYPES, f"{archetype} is not a valid archetype"


def test_valid_archetypes_contains_all_nine():
    expected = {
        "cone_weave", "wall_passing", "gate_dribbling", "dribble_and_shoot",
        "relay_shuttle", "server_executor", "triangle_passing",
        "1v1_plus_server", "rondo",
    }
    assert VALID_ARCHETYPES == expected
