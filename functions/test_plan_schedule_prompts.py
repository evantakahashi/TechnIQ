"""Tests for generate_training_plan's schedule guidance: weak spots + match-day rules.

Pure helpers in plan_schedule_prompts, plus one handler test that captures the prompt sent to a
fake Anthropic client (no real LLM call).
"""
from __future__ import annotations

import json
from datetime import date
from unittest.mock import patch

import pytest
from werkzeug.test import EnvironBuilder
from firebase_functions import https_fn

from plan_schedule_prompts import clean_weak_spots, match_day_guidance, parse_day, weak_spot_guidance


@pytest.fixture(autouse=True)
def emulator_env(monkeypatch):
    monkeypatch.setenv("FUNCTIONS_EMULATOR", "true")
    monkeypatch.setenv("ANTHROPIC_API_KEY", "test-key-not-real")


class TestParseDay:
    def test_iso_day(self):
        assert parse_day("2026-11-14") == date(2026, 11, 14)

    @pytest.mark.parametrize("value", [None, 20261114, "", "14/11/2026", "2026-13-01", "2026-11-14T10:00:00Z", ["2026-11-14"]])
    def test_invalid_is_none(self, value):
        assert parse_day(value) is None


class TestWeakSpots:
    def test_clean_dedupes_trims_and_caps(self):
        assert clean_weak_spots([" Passing ", "Passing", "", 3, "Weak Foot", "a", "b", "c", "d"]) == \
            ["Passing", "Weak Foot", "a", "b", "c"]

    def test_clean_non_list(self):
        assert clean_weak_spots("Passing") == []
        assert clean_weak_spots(None) == []

    def test_long_item_clipped(self):
        assert clean_weak_spots(["x" * 100]) == ["x" * 40]

    def test_guidance(self):
        assert weak_spot_guidance([]) == ""
        assert "Weak spots: Passing, Weak Foot" in weak_spot_guidance(["Passing", "Weak Foot"])


class TestMatchDayGuidance:
    START = date(2026, 11, 3)  # Tuesday

    def test_three_rules_with_weeks(self):
        text = match_day_guidance(date(2026, 11, 14), self.START, 4)  # Saturday, week 2
        assert "Next match: Saturday 2026-11-14 (week 2)" in text
        assert "Saturday 2026-11-14 (week 2) is the match: rest day" in text
        assert "The day before, Friday 2026-11-13 (week 2): one light Technical session, intensity 1-2, at most 30 minutes" in text
        assert "The day after, Sunday 2026-11-15 (week 2): Recovery only, intensity 1" in text
        assert "Intensity 4-5 only on days at least 2 days away from the match" in text
        assert "Plan starts Tuesday 2026-11-03" in text

    def test_week_boundary(self):
        # Start Tue 3 Nov: week 2 = Tue 10 – Mon 16; a Tuesday-17 match is week 3, the day before week 2.
        text = match_day_guidance(date(2026, 11, 17), self.START, 4)
        assert "Tuesday 2026-11-17 (week 3) is the match" in text
        assert "The day before, Monday 2026-11-16 (week 2)" in text

    def test_match_on_first_day_has_no_day_before(self):
        text = match_day_guidance(self.START, self.START, 4)
        assert "is the match" in text
        assert "The day before" not in text
        assert "The day after, Wednesday 2026-11-04 (week 1)" in text

    def test_match_on_last_day_has_no_day_after(self):
        text = match_day_guidance(date(2026, 11, 30), self.START, 4)  # last day of week 4
        assert "Monday 2026-11-30 (week 4) is the match" in text
        assert "The day after" not in text

    def test_outside_plan_is_empty(self):
        assert match_day_guidance(date(2026, 12, 25), self.START, 4) == ""
        assert match_day_guidance(date(2026, 10, 1), self.START, 4) == ""

    def test_missing_dates_empty(self):
        assert match_day_guidance(None, self.START, 4) == ""
        assert match_day_guidance(date(2026, 11, 14), None, 4) == ""


class _FakeMessages:
    def __init__(self, sink):
        self.sink = sink

    def create(self, **kwargs):
        self.sink.append(kwargs["messages"][0]["content"])
        plan = {
            "name": "P", "description": "d", "difficulty": "Intermediate", "category": "Technical",
            "weeks": [{"week_number": 1, "focus_area": "f", "days": [
                {"day_number": 1, "day_of_week": "Monday", "is_rest_day": False,
                 "sessions": [{"session_type": "Technical", "duration": 30, "intensity": 3,
                               "suggested_exercise_names": []}]}]}],
        }

        class _Block:
            text = json.dumps(plan)

        class _Response:
            content = [_Block()]

        return _Response()


class _FakeAnthropic:
    sink: list = []

    def __init__(self, api_key=None):
        self.messages = _FakeMessages(_FakeAnthropic.sink)


def _request(payload: dict) -> https_fn.Request:
    env = EnvironBuilder(method="POST", path="/generate_training_plan", data=json.dumps(payload).encode("utf-8"),
                         headers={"Content-Type": "application/json"}).get_environ()
    return https_fn.Request(env)


def _payload(**extra):
    base = {
        "user_id": "u1",
        "player_profile": {"age": 14, "position": "Forward", "experienceLevel": "Intermediate", "goals": []},
        "duration_weeks": 4,
        "difficulty": "Intermediate",
        "category": "Technical",
        "focus_areas": [],
    }
    base.update(extra)
    return base


def _prompt_for(payload):
    from main import generate_training_plan
    _FakeAnthropic.sink = []
    with patch("anthropic.Anthropic", _FakeAnthropic):
        resp = generate_training_plan(_request(payload))
    assert resp.status_code == 200
    body = json.loads(resp.get_data())
    assert body["weeks"][0]["days"][0]["sessions"][0]["session_type"] == "Technical"  # response shape untouched
    return _FakeAnthropic.sink[0]


def test_handler_adds_match_and_weak_spot_guidance():
    prompt = _prompt_for(_payload(next_match_date="2026-11-14", plan_start_date="2026-11-03",
                                  weak_spots=["Weak Foot", "Passing"]))
    assert "MATCH-DAY RULES" in prompt
    assert "Saturday 2026-11-14 (week 2) is the match" in prompt
    assert "Weak spots: Weak Foot, Passing" in prompt


def test_handler_ignores_invalid_dates():
    prompt = _prompt_for(_payload(next_match_date="next saturday", plan_start_date="2026-11-03"))
    assert "MATCH-DAY RULES" not in prompt


def test_handler_without_extras_unchanged():
    prompt = _prompt_for(_payload())
    assert "MATCH-DAY RULES" not in prompt
    assert "Weak spots" not in prompt
