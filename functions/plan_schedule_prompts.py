"""Schedule guidance for generate_training_plan: weak spots and the match-day rules.

The app re-applies the match-day rules deterministically after saving (MatchDayRules.swift), so
this text only steers the model toward a plan that needs few changes. Plan dates follow the app:
week n covers the seven days from the plan start date + 7(n-1); a day named "Saturday" in week n
is the first Saturday inside that window.
"""
from __future__ import annotations

from datetime import date, datetime, timedelta
from typing import Any, List, Optional

WEEKDAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
MAX_WEAK_SPOTS = 5


def parse_day(value: Any) -> Optional[date]:
    """A 'yyyy-MM-dd' string as a date; anything else (wrong type, bad format) is None."""
    if not isinstance(value, str) or len(value) != 10:
        return None
    try:
        return datetime.strptime(value, "%Y-%m-%d").date()
    except ValueError:
        return None


def clean_weak_spots(value: Any) -> List[str]:
    """Short non-empty strings only, deduplicated, capped."""
    if not isinstance(value, list):
        return []
    out: List[str] = []
    for item in value:
        if not isinstance(item, str):
            continue
        text = item.strip()[:40]
        if text and text not in out:
            out.append(text)
        if len(out) >= MAX_WEAK_SPOTS:
            break
    return out


def _week_of(day: date, start: date) -> int:
    return (day - start).days // 7 + 1


def _label(day: date, start: date) -> str:
    return f"{WEEKDAYS[day.weekday()]} {day.isoformat()} (week {_week_of(day, start)})"


def match_day_guidance(next_match: Optional[date], plan_start: Optional[date], duration_weeks: int) -> str:
    """Prompt lines for the three match-day rules, or '' when the match is outside the plan."""
    if next_match is None or plan_start is None:
        return ""
    end = plan_start + timedelta(days=7 * max(duration_weeks, 1))
    before = next_match - timedelta(days=1)
    after = next_match + timedelta(days=1)
    in_plan = lambda d: plan_start <= d < end  # noqa: E731
    if not (in_plan(next_match) or in_plan(after)):
        return ""
    lines = [
        f"- Plan starts {WEEKDAYS[plan_start.weekday()]} {plan_start.isoformat()}; week n is the seven days from the start + 7(n-1).",
        f"- Next match: {_label(next_match, plan_start)}.",
        "MATCH-DAY RULES:",
    ]
    if in_plan(next_match):
        lines.append(f"- {_label(next_match, plan_start)} is the match: rest day (is_rest_day: true, sessions: []).")
    if in_plan(before):
        lines.append(f"- The day before, {_label(before, plan_start)}: one light Technical session, intensity 1-2, at most 30 minutes.")
    if in_plan(after):
        lines.append(f"- The day after, {_label(after, plan_start)}: Recovery only, intensity 1, at most 30 minutes.")
    lines.append("- Intensity 4-5 only on days at least 2 days away from the match.")
    return "\n".join(lines) + "\n"


def weak_spot_guidance(weak_spots: List[str]) -> str:
    if not weak_spots:
        return ""
    return f"- Weak spots: {', '.join(weak_spots)} (give them most of the technical work)\n"
