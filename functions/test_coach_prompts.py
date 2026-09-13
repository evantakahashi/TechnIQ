"""The coach prompts: library ids reach the model, today's plan drill is preferred, voice rules hold."""
from __future__ import annotations

from coach_prompts import (
    build_daily_coaching_prompt,
    build_weekly_review_prompt,
    coach_system,
    format_library,
    format_today,
)


def _profile():
    return {"age": 14, "position": "Striker", "experience": "intermediate", "dominant_foot": "Right",
            "goals": ["Improve Skills"], "weaknesses": ["Weak Foot", "Shooting"]}


def test_system_prompt_names_the_coach_and_sets_the_voice():
    system = coach_system("Marta", "You pick one drill a day.")
    assert system.startswith("You are Marta, the player's soccer coach")
    assert "No exclamation marks" in system
    assert coach_system("", "x").startswith("You are Coach,")
    assert coach_system("   ", "x").startswith("You are Coach,")


def test_library_lines_carry_ids_and_usage():
    text = format_library([
        {"id": "A1", "name": "Wall passing", "category": "Technical", "difficulty": 2, "minutes": 15, "skills": ["Passing", "First Touch"], "last_used_days_ago": 3},
        {"id": "", "name": "no id"},
        {"id": "B2", "name": "Sprints", "category": "Physical", "difficulty": 3, "minutes": 10, "skills": [], "last_used_days_ago": None},
    ])
    lines = text.split("\n")
    assert len(lines) == 2, "drills without an id are dropped"
    assert lines[0].startswith("- [A1] Wall passing · Technical · lvl 2 · 15 min · Passing, First Touch · used 3d ago")
    assert "never used" in lines[1]


def test_daily_prompt_prefers_todays_plan_drill_and_lists_ids():
    prompt = build_daily_coaching_prompt(
        player_profile=_profile(),
        recent_sessions=[{"date": "2026-09-11", "duration_minutes": 20, "overall_rating": 4, "exercises": [{"name": "Wall passing", "category": "Technical", "skills": ["Passing"], "rating": 4}]}],
        category_balance={"technical": 80, "physical": 10, "tactical": 10},
        active_plan={"name": "Striker Development", "week": 3, "progress": 0.31},
        streak_days=5,
        days_since_last=1,
        total_sessions=12,
        library=[{"id": "A1", "name": "Wall passing", "category": "Technical", "difficulty": 2, "minutes": 15, "skills": ["Passing"], "last_used_days_ago": 1}],
        today={"session_type": "Technical", "minutes": 30, "week": 3, "drills": [{"id": "A1", "name": "Wall passing"}]},
    )
    assert "Prefer today's plan drill" in prompt
    assert "[A1] Wall passing" in prompt
    assert "Today's plan session: Technical · 30 min · week 3 · drills: [A1] Wall passing" in prompt
    assert "Striker Development, week 3, 31% complete" in prompt
    assert '"cue"' in prompt and '"library_exercise_id"' in prompt
    assert "Weak Foot" in prompt


def test_daily_prompt_handles_rest_day_and_empty_library():
    prompt = build_daily_coaching_prompt(
        player_profile=_profile(), recent_sessions=[], category_balance={}, active_plan={},
        streak_days=0, days_since_last=999, total_sessions=0, library=[], today={"is_rest": True},
    )
    assert "Today is a rest day on the plan." in prompt
    assert "(empty)" in prompt
    assert "No sessions yet" in prompt
    assert format_today(None) == "No plan session today."


def test_weekly_review_prompt_carries_recap_and_asks_for_reasons():
    prompt = build_weekly_review_prompt(
        player_profile=_profile(), plan_name="Striker Development", week_number=3,
        week_summary="- Day 1: Technical, completed, rated 4/5\n", sessions_completed=3, total_sessions=4, avg_rating=3.7,
        recap={"done": 3, "planned": 4, "minutes": 75, "missed": 1, "effort": "3.7/5", "best_drill": "Wall passing"},
        next_week={"days": []},
    )
    assert "Recap the app already shows: 3/4 sessions, 75 min, 1 missed day(s), effort 3.7/5, best drill Wall passing." in prompt
    assert '"reason"' in prompt
    assert "A missed week means lighter, not harder." in prompt
