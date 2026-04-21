"""Tests for exemplars loader + every exemplar parses+validates."""
import json
from pathlib import Path

import pytest
from archetype_picker import VALID_ARCHETYPES
from dsl_parser import parse_dsl
from drill_post_processor import post_process_drill
from drill_validator import validate_drill
from exemplars import EXEMPLARS, get_exemplars


def test_exemplars_file_loads():
    """Verify exemplars.json parses from disk independently."""
    exemplars_path = Path(__file__).with_name("exemplars.json")
    assert exemplars_path.exists()
    with exemplars_path.open("r", encoding="utf-8") as f:
        data = json.load(f)
    assert isinstance(data, list)
    assert len(data) > 0


def test_eight_entries():
    assert len(EXEMPLARS) == 8


def test_one_per_archetype():
    archetypes_with_exemplars = {e["archetype"] for e in EXEMPLARS}
    # Every archetype appears exactly once, and exactly matches valid set
    assert archetypes_with_exemplars == VALID_ARCHETYPES
    assert len(EXEMPLARS) == len(set(a["archetype"] for a in EXEMPLARS))


def test_every_exemplar_has_required_fields():
    for e in EXEMPLARS:
        assert set(e.keys()) >= {"id", "archetype", "dsl", "notes"}
        assert e["archetype"] in VALID_ARCHETYPES


def test_every_exemplar_id_is_unique():
    ids = [e["id"] for e in EXEMPLARS]
    assert len(ids) == len(set(ids))


@pytest.mark.parametrize("exemplar", [e for e in __import__("exemplars").EXEMPLARS], ids=lambda e: e["id"])
def test_exemplar_parses_post_processes_and_validates(exemplar):
    drill = parse_dsl(exemplar["dsl"])
    drill.setdefault("equipment", ["ball", "cones", "goals", "partner"])
    drill, _warnings = post_process_drill(drill, player_age=14)
    validate_drill(drill)


def test_get_exemplars_returns_matching_archetype():
    result = get_exemplars("cone_weave")
    assert len(result) >= 1
    assert all(e["archetype"] == "cone_weave" for e in result)


def test_get_exemplars_respects_limit():
    result = get_exemplars("cone_weave", n=1)
    assert len(result) == 1


def test_get_exemplars_unknown_archetype_returns_empty():
    assert get_exemplars("nonexistent_archetype") == []
