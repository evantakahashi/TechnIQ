"""Tests for category rule-pack lookup."""
import pytest
from category_rules import RULE_PACKS, get_rule_pack


def test_six_covered_categories():
    covered = {"Dribbling", "Passing", "Shooting", "First Touch", "Defending", "Speed & Agility"}
    assert covered.issubset(RULE_PACKS.keys())


def test_every_pack_has_required_fields():
    required = {"primary_action", "verb_keywords", "must_include",
                "must_avoid", "success_metric", "perception_action_cue"}
    for name, pack in RULE_PACKS.items():
        assert required.issubset(pack.keys()), f"{name!r} missing fields"
        assert isinstance(pack["verb_keywords"], list) and pack["verb_keywords"]
        assert isinstance(pack["must_include"], list) and pack["must_include"]
        assert isinstance(pack["must_avoid"], list) and pack["must_avoid"]


def test_get_rule_pack_exact_match():
    pack = get_rule_pack("Shooting")
    assert pack is not None
    assert "shoot" in pack["verb_keywords"] or any("shoot" in k for k in pack["verb_keywords"])


def test_get_rule_pack_case_insensitive():
    assert get_rule_pack("shooting") == get_rule_pack("Shooting")
    assert get_rule_pack("FIRST TOUCH") == get_rule_pack("First Touch")


def test_get_rule_pack_unknown_returns_none():
    assert get_rule_pack("Stamina") is None
    assert get_rule_pack("Positioning") is None
    assert get_rule_pack("") is None
    assert get_rule_pack("nonsense category") is None


def test_verb_keywords_are_lowercase():
    for name, pack in RULE_PACKS.items():
        for kw in pack["verb_keywords"]:
            assert kw == kw.lower(), f"{name!r} keyword {kw!r} not lowercase"
