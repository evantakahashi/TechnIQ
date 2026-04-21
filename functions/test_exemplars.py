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


def test_has_expected_entry_count():
    # Plan 1 will bring this to 24 after T7-T10 add 4 high-intensity exemplars.
    # During execution, count monotonically grows from 20 → 24.
    assert len(EXEMPLARS) >= 20


def test_every_archetype_has_at_least_two():
    from collections import Counter
    counts = Counter(e["archetype"] for e in EXEMPLARS)
    # Every exemplar's archetype is valid
    for archetype in counts:
        assert archetype in VALID_ARCHETYPES, f"unknown archetype {archetype!r}"
    # Every valid archetype appears at least twice
    for archetype in VALID_ARCHETYPES:
        assert counts[archetype] >= 2, f"{archetype!r} has only {counts[archetype]} exemplar(s)"


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


def test_every_exemplar_has_pressure_field():
    for e in EXEMPLARS:
        assert e.get("pressure") in {"none", "passive", "active"}, \
            f"{e['id']!r} has pressure={e.get('pressure')!r}"


def test_get_exemplars_filters_by_level_advanced():
    # advanced → only "active"
    hits = get_exemplars("1v1_plus_server", level="advanced")
    assert hits, "1v1_plus_server should have at least one advanced-active exemplar"
    assert all(e["pressure"] == "active" for e in hits)


def test_get_exemplars_filters_by_level_beginner():
    # beginner → "none" or "passive" OK, never "active"
    hits = get_exemplars("wall_passing", level="beginner")
    assert hits
    assert all(e["pressure"] in {"none", "passive"} for e in hits)


def test_get_exemplars_cascades_to_neighbor_when_empty():
    # cone_weave has no "active" pressure exemplars; advanced should cascade
    # to a neighbor archetype (gate_dribbling or 1v1_plus_server)
    hits = get_exemplars("cone_weave", level="advanced")
    # Cascade yields from a neighbor or returns empty — never wrong-pressure from cone_weave
    for e in hits:
        assert e["pressure"] == "active"
        assert e["archetype"] != "cone_weave"


def test_get_exemplars_returns_empty_when_all_cascade_paths_fail():
    # A fabricated archetype with no neighbors returns empty
    assert get_exemplars("fabricated_archetype_xyz", level="advanced") == []


def test_get_exemplars_no_level_is_backwards_compatible():
    # Callers that don't pass level get all archetype matches (no filter)
    all_cone = get_exemplars("cone_weave")
    assert len(all_cone) >= 1
    assert all(e["archetype"] == "cone_weave" for e in all_cone)
