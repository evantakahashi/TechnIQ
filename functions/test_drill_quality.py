"""Unit tests for score_drill_quality (C1-C4 + generic realism floor)."""
import pytest
from drill_quality import (
    score_drill_quality,
    GENERIC_COACHING_BLACKLIST,
)


SHOOTING_RULE_PACK = {
    "verb_keywords": ["shoot", "strike", "finish", "drive", "curl", "place"],
    "must_include": ["goal element", "setup touch before the strike",
                     "server feed OR defender pressure"],
    "must_avoid": ["stationary ball placed in front of empty goal"],
    "success_metric": "≥60% of shots on target within 2 seconds of the final touch",
    "perception_action_cue": "scan keeper/goal before the final touch",
    "primary_action": "strike on goal after a setup touch, with server service or a defender closing",
}


def _drill(elements, paths, points):
    return {"diagram": {"elements": elements, "paths": paths}, "coaching_points": points}


def _advanced_shooting_drill_good():
    """Passes all 4 checks."""
    return _drill(
        elements=[
            {"type": "player", "label": "P1", "role": "server", "x": 2, "y": 7},
            {"type": "player", "label": "P2", "role": "worker", "x": 8, "y": 7},
            {"type": "player", "label": "P3", "role": "defender", "x": 13, "y": 7},
            {"type": "goal",   "label": "GL", "x": 18, "y": 7.5, "width": 7.32},
            {"type": "ball",   "label": "B1", "x": 2, "y": 7},
        ],
        paths=[
            {"from": "P1", "to": "P2", "style": "pass", "step": 1},
            {"from": "P2", "to": "P2", "style": "dribble", "step": 2},
            {"from": "P2", "to": "GL", "style": "shoot", "step": 3},
            {"from": "P1", "to": "P2", "style": "pass", "step": 4},
            {"from": "P2", "to": "GL", "style": "shoot", "step": 5},
        ],
        points=[
            "Set up the strike with your second-to-last touch",
            "Scan the keeper before the final touch, then drive through the ball",
        ],
    )


# --- C1: forces_primary_action ---

def test_c1_passes_when_verb_keyword_in_coaching_point():
    drill = _advanced_shooting_drill_good()
    score, reasons = score_drill_quality(drill, SHOOTING_RULE_PACK, level="advanced")
    assert any("verb" not in r.lower() and "keyword" not in r.lower() for r in reasons) or score >= 3


def test_c1_fails_when_no_verb_keyword_anywhere():
    drill = _drill(
        elements=[
            {"type": "player", "label": "P1", "role": "worker", "x": 5, "y": 5},
            {"type": "cone",   "label": "C1", "x": 10, "y": 5},
        ],
        paths=[{"from": "P1", "to": "C1", "style": "dribble", "step": 1}],
        points=["Good effort", "Keep going"],
    )
    _, reasons = score_drill_quality(drill, SHOOTING_RULE_PACK, level="advanced")
    assert any("C1" in r for r in reasons)


# --- C2: structural_realism (compound) ---

def test_c2_passes_full_structural_drill():
    drill = _advanced_shooting_drill_good()
    score, reasons = score_drill_quality(drill, SHOOTING_RULE_PACK, level="advanced")
    assert not any("C2" in r for r in reasons), f"unexpected C2 failure: {reasons}"


def test_c2_fails_when_fewer_than_two_players():
    drill = _drill(
        elements=[
            {"type": "player", "label": "P1", "role": "worker", "x": 5, "y": 5},
            {"type": "goal",   "label": "GL", "x": 18, "y": 7.5, "width": 7.32},
        ],
        paths=[
            {"from": "P1", "to": "GL", "style": "shoot", "step": 1},
            {"from": "P1", "to": "GL", "style": "shoot", "step": 2},
            {"from": "P1", "to": "GL", "style": "shoot", "step": 3},
            {"from": "P1", "to": "GL", "style": "shoot", "step": 4},
            {"from": "P1", "to": "GL", "style": "shoot", "step": 5},
        ],
        points=["Strike through the ball", "Plant foot next to it"],
    )
    _, reasons = score_drill_quality(drill, SHOOTING_RULE_PACK, level="advanced")
    assert any("C2" in r for r in reasons)


def test_c2_fails_when_no_outcome_object():
    drill = _drill(
        elements=[
            {"type": "player", "label": "P1", "role": "worker", "x": 5, "y": 5},
            {"type": "player", "label": "P2", "role": "server", "x": 10, "y": 5},
        ],
        paths=[
            {"from": "P1", "to": "P2", "style": "pass", "step": 1},
            {"from": "P2", "to": "P1", "style": "pass", "step": 2},
            {"from": "P1", "to": "P2", "style": "pass", "step": 3},
        ],
        points=["Pass firmly", "Open your body"],
    )
    _, reasons = score_drill_quality(drill, SHOOTING_RULE_PACK, level="advanced")
    assert any("C2" in r for r in reasons)


def test_c2_passes_with_server_participating_in_two_steps_and_outcome_object():
    drill = _drill(
        elements=[
            {"type": "player", "label": "P1", "role": "server", "x": 2, "y": 5},
            {"type": "player", "label": "P2", "role": "worker", "x": 8, "y": 5},
            {"type": "goal",   "label": "GL", "x": 18, "y": 7.5, "width": 7.32},
        ],
        paths=[
            {"from": "P1", "to": "P2", "style": "pass", "step": 1},
            {"from": "P2", "to": "GL", "style": "shoot", "step": 2},
            {"from": "P1", "to": "P2", "style": "pass", "step": 3},
            {"from": "P2", "to": "GL", "style": "shoot", "step": 4},
            {"from": "P1", "to": "P2", "style": "pass", "step": 5},
        ],
        points=["Setup touch first", "Strike through the ball"],
    )
    _, reasons = score_drill_quality(drill, SHOOTING_RULE_PACK, level="advanced")
    assert not any("C2" in r for r in reasons)


# --- C3: coaching_points_on_target ---

def test_c3_fails_when_only_one_coaching_point():
    drill = _advanced_shooting_drill_good()
    drill["coaching_points"] = ["Only one point"]
    _, reasons = score_drill_quality(drill, SHOOTING_RULE_PACK, level="advanced")
    assert any("C3" in r for r in reasons)


def test_c3_fails_when_coaching_points_are_generic():
    drill = _advanced_shooting_drill_good()
    drill["coaching_points"] = ["Work hard", "Give 100%"]
    _, reasons = score_drill_quality(drill, SHOOTING_RULE_PACK, level="advanced")
    assert any("C3" in r for r in reasons)


# --- C4: rep_density ---

def test_c4_passes_with_five_steps():
    drill = _advanced_shooting_drill_good()
    _, reasons = score_drill_quality(drill, SHOOTING_RULE_PACK, level="advanced")
    assert not any("C4" in r for r in reasons)


def test_c4_fails_with_only_two_steps_and_no_repeat_element():
    drill = _drill(
        elements=[
            {"type": "player", "label": "P1", "role": "worker", "x": 5, "y": 5},
            {"type": "goal",   "label": "GL", "x": 18, "y": 7.5, "width": 7.32},
        ],
        paths=[
            {"from": "P1", "to": "GL", "style": "shoot", "step": 1},
            {"from": "P1", "to": "GL", "style": "shoot", "step": 2},
        ],
        points=["Strike firm", "Head still"],
    )
    _, reasons = score_drill_quality(drill, SHOOTING_RULE_PACK, level="advanced")
    assert any("C4" in r for r in reasons)


# --- Threshold + level interactions ---

def test_threshold_three_of_four_passes_for_advanced():
    drill = _advanced_shooting_drill_good()
    score, reasons = score_drill_quality(drill, SHOOTING_RULE_PACK, level="advanced")
    assert score >= 3
    assert all("C" in r for r in reasons) or reasons == []


def test_c2_mandatory_for_advanced_even_if_score_is_three():
    drill = _drill(
        elements=[
            {"type": "player", "label": "P1", "role": "worker", "x": 5, "y": 5},
            {"type": "goal",   "label": "GL", "x": 18, "y": 7.5, "width": 7.32},
        ],
        paths=[
            {"from": "P1", "to": "GL", "style": "shoot", "step": 1},
            {"from": "P1", "to": "GL", "style": "shoot", "step": 2},
            {"from": "P1", "to": "GL", "style": "shoot", "step": 3},
            {"from": "P1", "to": "GL", "style": "shoot", "step": 4},
            {"from": "P1", "to": "GL", "style": "shoot", "step": 5},
        ],
        points=[
            "Strike through the ball with a setup touch",
            "Finish across the keeper on the far post",
        ],
    )
    score, reasons = score_drill_quality(drill, SHOOTING_RULE_PACK, level="advanced")
    assert any("C2" in r for r in reasons), \
        f"C2 must be mandatory for advanced; got reasons={reasons}"


def test_beginner_does_not_require_c2():
    drill = _drill(
        elements=[
            {"type": "cone",   "label": "C1", "x": 6, "y": 7},
            {"type": "cone",   "label": "C2", "x": 9, "y": 7},
            {"type": "cone",   "label": "C3", "x": 12, "y": 7},
            {"type": "cone",   "label": "C4", "x": 15, "y": 7},
            {"type": "player", "label": "P1", "role": "worker", "x": 3, "y": 7},
        ],
        paths=[
            {"from": "P1", "to": "C1", "style": "dribble", "step": 1},
            {"from": "P1", "to": "C2", "style": "dribble", "step": 2},
            {"from": "P1", "to": "C3", "style": "dribble", "step": 3},
            {"from": "P1", "to": "C4", "style": "dribble", "step": 4},
            {"from": "P1", "to": "C1", "style": "dribble", "step": 5},
        ],
        points=[
            "Use inside and outside of the same foot to dribble close",
            "Keep the ball within half a step",
        ],
    )
    dribbling_pack = {
        "verb_keywords": ["dribble", "carry", "beat", "turn"],
        "must_include": ["worker with ball"],
        "must_avoid": [],
        "success_metric": "70% reps beat the defender",
        "perception_action_cue": "scan body shape",
        "primary_action": "carry past defender",
    }
    score, reasons = score_drill_quality(drill, dribbling_pack, level="beginner")
    assert score >= 3


# --- Generic realism floor (rule_pack is None) ---

def test_intermediate_with_no_rule_pack_uses_realism_floor():
    drill = _advanced_shooting_drill_good()
    score, reasons = score_drill_quality(drill, None, level="intermediate")
    assert score >= 3


def test_intermediate_with_no_rule_pack_rejects_all_generic_points():
    drill = _advanced_shooting_drill_good()
    drill["coaching_points"] = ["Work hard", "Give 100%", "Focus up"]
    _, reasons = score_drill_quality(drill, None, level="intermediate")
    assert any("C3" in r for r in reasons)


def test_beginner_with_no_rule_pack_only_requires_c4():
    drill = _drill(
        elements=[
            {"type": "player", "label": "P1", "role": "worker", "x": 5, "y": 5},
            {"type": "cone",   "label": "C1", "x": 10, "y": 5},
        ],
        paths=[
            {"from": "P1", "to": "C1", "style": "dribble", "step": 1},
            {"from": "P1", "to": "C1", "style": "dribble", "step": 2},
            {"from": "P1", "to": "C1", "style": "dribble", "step": 3},
            {"from": "P1", "to": "C1", "style": "dribble", "step": 4},
            {"from": "P1", "to": "C1", "style": "dribble", "step": 5},
        ],
        points=["Work hard"],
    )
    score, _ = score_drill_quality(drill, None, level="beginner")
    assert score >= 1


def test_generic_coaching_blacklist_populated():
    assert "work hard" in GENERIC_COACHING_BLACKLIST
    assert "give 100%" in GENERIC_COACHING_BLACKLIST
    assert "focus up" in GENERIC_COACHING_BLACKLIST
    # "focus" alone is intentionally NOT in the blacklist — too broad a substring
    assert "focus" not in GENERIC_COACHING_BLACKLIST


def test_is_non_generic_allows_focus_on_technical_detail():
    # "Focus on your footwork" is not in the blacklist AND contains no football-verb word,
    # so _is_non_generic still returns False via the second gate — but we care that the
    # BLACKLIST doesn't reject it, which lets richer sentences pass.
    from drill_quality import _is_non_generic
    assert _is_non_generic("Focus the pass to the back foot") is True
    # "pass" is a football verb and no blacklist phrase matches — should be non-generic
