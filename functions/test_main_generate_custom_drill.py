"""Tests for generate_custom_drill handler — focuses on field passthrough.

Patches drill_generator.generate_drill to capture the request dict the handler
forwards. No real LLM calls.
"""
from __future__ import annotations

import json
import os
from unittest.mock import patch

import pytest
from werkzeug.test import EnvironBuilder
from firebase_functions import https_fn


@pytest.fixture(autouse=True)
def emulator_env(monkeypatch):
    # Auth bypass is now gated on the Functions emulator flag, not a deployable env var.
    monkeypatch.setenv("FUNCTIONS_EMULATOR", "true")
    monkeypatch.setenv("ANTHROPIC_API_KEY", "test-key-not-real")


def _make_request(payload: dict) -> https_fn.Request:
    body = json.dumps(payload).encode("utf-8")
    env = EnvironBuilder(
        method="POST",
        path="/generate_custom_drill",
        data=body,
        headers={"Content-Type": "application/json"},
    ).get_environ()
    return https_fn.Request(env)


_FAKE_DRILL = {
    "diagram": {
        "elements": [{"type": "player", "label": "P1", "role": "worker", "x": 5.0, "y": 5.0}],
        "paths": [{"step": 1, "from": "P1", "to": "P1", "style": "dribble"}],
    },
    "coaching_points": ["dribble close", "scan up"],
    "equipment": ["ball"],
}


def _capture_request_dict():
    """Return (capture_list, fake_generate). capture_list[0] holds the dict."""
    captured: list[dict] = []

    def fake_generate(req_dict, llm_call):
        captured.append(req_dict)
        return dict(_FAKE_DRILL)

    return captured, fake_generate


def test_handler_forwards_number_of_players():
    from main import generate_custom_drill

    captured, fake = _capture_request_dict()
    payload = {
        "user_id": "u1",
        "player_profile": {"age": 14, "position": "midfielder", "experienceLevel": "intermediate"},
        "requirements": {
            "skill_description": "test",
            "equipment": ["ball", "cones"],
            "number_of_players": 1,
            "selected_weaknesses": [{"category": "Passing"}],
        },
    }
    with patch("drill_generator.generate_drill", fake):
        resp = generate_custom_drill(_make_request(payload))
    assert resp.status_code == 200
    assert captured[0]["number_of_players"] == 1


def test_handler_forwards_field_size():
    from main import generate_custom_drill

    captured, fake = _capture_request_dict()
    payload = {
        "user_id": "u1",
        "player_profile": {"age": 14, "position": "midfielder", "experienceLevel": "intermediate"},
        "field_size": "large",
        "requirements": {
            "skill_description": "test",
            "equipment": ["ball"],
            "selected_weaknesses": [{"category": "Passing"}],
        },
    }
    with patch("drill_generator.generate_drill", fake):
        generate_custom_drill(_make_request(payload))
    assert captured[0]["field_size"] == "large"


def test_handler_forwards_category():
    from main import generate_custom_drill

    captured, fake = _capture_request_dict()
    payload = {
        "user_id": "u1",
        "player_profile": {"age": 14, "position": "midfielder", "experienceLevel": "intermediate"},
        "requirements": {
            "skill_description": "test",
            "category": "tactical",
            "equipment": ["ball"],
            "selected_weaknesses": [{"category": "Defending"}],
        },
    }
    with patch("drill_generator.generate_drill", fake):
        generate_custom_drill(_make_request(payload))
    assert captured[0]["category"] == "tactical"


def test_handler_forwards_recent_drill_names():
    from main import generate_custom_drill

    captured, fake = _capture_request_dict()
    payload = {
        "user_id": "u1",
        "player_profile": {"age": 14, "position": "midfielder", "experienceLevel": "intermediate"},
        "requirements": {
            "skill_description": "test",
            "equipment": ["ball"],
            "recent_drill_names": ["Cone Weave A", "Triangle Pass"],
            "selected_weaknesses": [{"category": "Dribbling"}],
        },
    }
    with patch("drill_generator.generate_drill", fake):
        generate_custom_drill(_make_request(payload))
    assert captured[0]["recent_drill_names"] == ["Cone Weave A", "Triangle Pass"]


def test_handler_forwards_player_flavor():
    """playingStyle and skillGoals from profile flow through (renamed to snake_case)."""
    from main import generate_custom_drill

    captured, fake = _capture_request_dict()
    payload = {
        "user_id": "u1",
        "player_profile": {
            "age": 14,
            "position": "midfielder",
            "experienceLevel": "intermediate",
            "playingStyle": "attacking",
            "skillGoals": ["improve weak foot", "increase pace"],
        },
        "requirements": {
            "skill_description": "test",
            "equipment": ["ball"],
            "selected_weaknesses": [{"category": "Passing"}],
        },
    }
    with patch("drill_generator.generate_drill", fake):
        generate_custom_drill(_make_request(payload))
    assert captured[0]["playing_style"] == "attacking"
    assert captured[0]["skill_goals"] == ["improve weak foot", "increase pace"]


def test_handler_uses_requirements_difficulty_for_level():
    """When requirements.difficulty is set, it overrides profile.experienceLevel."""
    from main import generate_custom_drill

    captured, fake = _capture_request_dict()
    payload = {
        "user_id": "u1",
        "player_profile": {"age": 14, "position": "midfielder", "experienceLevel": "beginner"},
        "requirements": {
            "skill_description": "test",
            "difficulty": "advanced",
            "equipment": ["ball"],
            "selected_weaknesses": [{"category": "Dribbling"}],
        },
    }
    with patch("drill_generator.generate_drill", fake):
        generate_custom_drill(_make_request(payload))
    assert captured[0]["experience_level"] == "advanced"


def test_handler_falls_back_to_profile_level():
    """When requirements.difficulty is missing, falls back to profile.experienceLevel."""
    from main import generate_custom_drill

    captured, fake = _capture_request_dict()
    payload = {
        "user_id": "u1",
        "player_profile": {"age": 14, "position": "midfielder", "experienceLevel": "advanced"},
        "requirements": {
            "skill_description": "test",
            "equipment": ["ball"],
            "selected_weaknesses": [{"category": "Passing"}],
        },
    }
    with patch("drill_generator.generate_drill", fake):
        generate_custom_drill(_make_request(payload))
    assert captured[0]["experience_level"] == "advanced"


def test_handler_defaults_number_of_players_to_2():
    """Missing number_of_players defaults to 2 (worker + partner)."""
    from main import generate_custom_drill

    captured, fake = _capture_request_dict()
    payload = {
        "user_id": "u1",
        "player_profile": {"age": 14, "position": "midfielder", "experienceLevel": "intermediate"},
        "requirements": {
            "skill_description": "test",
            "equipment": ["ball"],
            "selected_weaknesses": [{"category": "Passing"}],
        },
    }
    with patch("drill_generator.generate_drill", fake):
        generate_custom_drill(_make_request(payload))
    assert captured[0]["number_of_players"] == 2


def test_handler_solo_request_passes_through_to_quality_gate():
    """Solo request → generate_drill receives number_of_players=1 → C2 uses solo carve-out.

    We mock generate_drill to return a known drill but verify the request dict
    forwarded matches what would let the solo carve-out activate.
    """
    from main import generate_custom_drill

    captured, fake = _capture_request_dict()
    payload = {
        "user_id": "u1",
        "player_profile": {"age": 16, "position": "winger", "experienceLevel": "advanced"},
        "field_size": "medium",
        "requirements": {
            "skill_description": "solo dribbling under time pressure",
            "difficulty": "advanced",
            "category": "technical",
            "equipment": ["ball", "cones"],
            "number_of_players": 1,
            "selected_weaknesses": [{"category": "Dribbling"}],
        },
    }
    with patch("drill_generator.generate_drill", fake):
        resp = generate_custom_drill(_make_request(payload))
    assert resp.status_code == 200
    forwarded = captured[0]
    assert forwarded["number_of_players"] == 1
    assert forwarded["experience_level"] == "advanced"
    assert forwarded["field_size"] == "medium"
    assert forwarded["category"] == "technical"


def test_handler_response_preserves_drill_shape():
    """Response wraps drill in {"drill": ..., "generated_at": ...} with camelCase keys."""
    from main import generate_custom_drill

    _, fake = _capture_request_dict()
    payload = {
        "user_id": "u1",
        "player_profile": {"age": 14, "position": "midfielder", "experienceLevel": "intermediate"},
        "requirements": {
            "skill_description": "test",
            "equipment": ["ball"],
            "selected_weaknesses": [{"category": "Passing"}],
        },
    }
    with patch("drill_generator.generate_drill", fake):
        resp = generate_custom_drill(_make_request(payload))
    body = json.loads(resp.get_data(as_text=True))
    assert "drill" in body
    drill = body["drill"]
    assert "coachingPoints" in drill  # camelCase
    assert "coaching_points" not in drill  # no leak
    assert "estimatedDuration" in drill
    assert isinstance(drill["estimatedDuration"], int)


class TestResponseSynthesis:
    def test_display_name_trims_and_titles(self):
        from main import _drill_display_name
        assert _drill_display_name("sharper one touch passing with a partner") == "Sharper One Touch Passing With A Partner"
        assert _drill_display_name("dribbling") == "Dribbling Drill"

    def test_instructions_from_paths(self):
        from main import _synthesize_instructions
        drill = {"diagram": {"elements": [
            {"label": "P1", "type": "player", "role": "worker", "x": 1, "y": 1},
            {"label": "P2", "type": "player", "role": "server", "x": 5, "y": 5}],
            "paths": [{"step": 1, "from": "P1", "to": "P2", "style": "pass"}]}}
        out = _synthesize_instructions(drill)
        assert out == ["P1 (worker) passes to P2."]

    def test_shoot_style_renders_shoots_at(self):
        from main import _synthesize_instructions
        drill = {"diagram": {"elements": [
            {"label": "P1", "type": "player", "role": "worker", "x": 1, "y": 1},
            {"label": "GL", "type": "goal", "x": 10, "y": 5}],
            "paths": [{"step": 1, "from": "P1", "to": "GL", "style": "shoot"}]}}
        assert _synthesize_instructions(drill) == ["P1 (worker) shoots at GL."]

    def test_skill_tags_from_description(self):
        from main import _skill_tags_from_description
        assert _skill_tags_from_description("weak foot finishing accuracy") == ["Weak Foot", "Shooting Accuracy"]
        assert _skill_tags_from_description("crossing and finishing combination") == ["Shooting Accuracy", "Crossing"]
        assert _skill_tags_from_description("goalkeeper reaction saves off a wall") == ["Goalkeeping"]
        assert _skill_tags_from_description("defending 1v1 without diving in") == ["Defending"]
        assert _skill_tags_from_description("sharper one touch passing") == ["Passing Accuracy"]
        assert _skill_tags_from_description("something totally unrelated") == ["Ball Control"]

    def test_setup_summary_counts(self):
        from main import _synthesize_setup
        drill = {"diagram": {"elements": [
            {"label": "P1", "type": "player"}, {"label": "C1", "type": "cone"},
            {"label": "C2", "type": "cone"}, {"label": "B1", "type": "ball"}]}}
        s = _synthesize_setup(drill)
        assert "1 player" in s and "2 cones" in s and "1 ball" in s


def test_professional_level_maps_to_advanced():
    captured = {}
    def fake_llm(prompt):
        captured['prompt'] = prompt
        raise RuntimeError("stop")
    import drill_generator as dg
    try:
        dg.generate_drill({"weakness": "shooting", "experience_level": "Professional",
                           "player_age": 17, "position": "Forward", "equipment": ["ball", "goals"]}, fake_llm)
    except Exception:
        pass
    assert 'advanced' in captured.get('prompt', '').lower()
    assert 'professional' not in captured.get('prompt', '').lower()
