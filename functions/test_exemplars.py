"""Tests for exemplars loader + every exemplar parses+validates."""
import pytest
from archetype_picker import VALID_ARCHETYPES
from dsl_parser import parse_dsl
from drill_post_processor import post_process_drill
from drill_validator import validate_drill
from exemplars import EXEMPLARS, get_exemplars


def test_exemplars_list_non_empty():
    assert len(EXEMPLARS) >= 9


def test_each_archetype_has_at_least_one_exemplar():
    archetypes_with_exemplars = {e["archetype"] for e in EXEMPLARS}
    assert VALID_ARCHETYPES.issubset(archetypes_with_exemplars)


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
