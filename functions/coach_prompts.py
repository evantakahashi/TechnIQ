"""Prompt builders for the coach endpoints (daily pick, weekly review).

Pure functions so the voice and the JSON contract can be unit-tested without an LLM.
Voice rules live in one place: the coach speaks as "I", the player is "you", short
sentences, no exclamation marks, no emoji, and every claim points at a number the
player can see in the app.
"""
from __future__ import annotations

import json
from typing import Any, Dict, List, Optional

MAX_LIBRARY = 40
MAX_SESSIONS = 10

VOICE_RULES = (
    "Voice: you are the player's coach. Speak as \"I\" to \"you\". Short sentences. "
    "No exclamation marks, no emoji, no hype. Every claim cites something the player can see "
    "(a rating, a date, a count). British or American spelling is fine; be consistent."
)


def coach_system(coach_name: str, role_line: str) -> str:
    name = (coach_name or "Coach").strip()[:40] or "Coach"
    return f"You are {name}, the player's soccer coach inside the TechnIQ app. {role_line} {VOICE_RULES}"


def _clean_str(value: Any, limit: int = 80) -> str:
    return str(value or "").strip()[:limit]


def format_library(library: List[Dict[str, Any]]) -> str:
    """One line per drill the coach may pick from, ids included."""
    lines = []
    for drill in (library or [])[:MAX_LIBRARY]:
        drill_id = _clean_str(drill.get("id"), 64)
        if not drill_id:
            continue
        skills = ", ".join(_clean_str(s, 30) for s in (drill.get("skills") or [])[:4])
        last = drill.get("last_used_days_ago")
        last_text = "never used" if last is None else f"used {int(last)}d ago"
        lines.append(
            f"- [{drill_id}] {_clean_str(drill.get('name'))} · {_clean_str(drill.get('category'), 20)} · "
            f"lvl {int(drill.get('difficulty') or 0)} · {int(drill.get('minutes') or 0)} min · {skills or 'no tags'} · {last_text}"
        )
    return "\n".join(lines)


def format_today(today: Optional[Dict[str, Any]]) -> str:
    if not today:
        return "No plan session today."
    if today.get("is_rest"):
        return "Today is a rest day on the plan."
    drills = today.get("drills") or []
    names = "; ".join(f"[{_clean_str(d.get('id'), 64)}] {_clean_str(d.get('name'))}" for d in drills[:6]) or "no drills attached yet"
    return (
        f"Today's plan session: {_clean_str(today.get('session_type'), 20) or 'Training'} · "
        f"{int(today.get('minutes') or 0)} min · week {int(today.get('week') or 0)} · drills: {names}"
    )


def format_sessions(recent_sessions: List[Dict[str, Any]]) -> str:
    text = ""
    for session in (recent_sessions or [])[:MAX_SESSIONS]:
        text += f"- {session.get('date', '?')}: {session.get('duration_minutes', 0)}min, rated {session.get('overall_rating', 0)}/5\n"
        for ex in session.get("exercises", [])[:6]:
            text += f"  - {ex.get('name', '?')} ({ex.get('category', '?')}): skills={ex.get('skills', [])}, rated {ex.get('rating', 0)}/5\n"
    return text


def build_daily_coaching_prompt(
    *,
    player_profile: Dict[str, Any],
    recent_sessions: List[Dict[str, Any]],
    category_balance: Dict[str, Any],
    active_plan: Dict[str, Any],
    streak_days: int,
    days_since_last: int,
    total_sessions: int,
    library: List[Dict[str, Any]],
    today: Optional[Dict[str, Any]],
) -> str:
    balance_text = (
        f"Technical: {category_balance.get('technical', 0)}%, Physical: {category_balance.get('physical', 0)}%, "
        f"Tactical: {category_balance.get('tactical', 0)}%"
    )
    plan_text = ""
    if active_plan:
        plan_text = (
            f"Active plan: {active_plan.get('name', 'Unknown')}, week {active_plan.get('week', '?')}, "
            f"{float(active_plan.get('progress', 0)) * 100:.0f}% complete"
        )
    streak_text = f"Current streak: {streak_days} days. Days since last session: {days_since_last}. Total sessions: {total_sessions}."
    library_text = format_library(library) or "(empty)"

    return f"""Pick today's drill for this player and say why in one line.

Player: Age {player_profile.get('age', '?')}, {player_profile.get('position', '?')}, {player_profile.get('experience', 'intermediate')} level
Dominant foot: {player_profile.get('dominant_foot', 'unknown')}
Goals: {', '.join(player_profile.get('goals', []))}
Weak spots they named: {', '.join(player_profile.get('weaknesses', []))}

Recent sessions (newest first):
{format_sessions(recent_sessions) or 'No sessions yet'}

Category balance: {balance_text}
{plan_text}
{streak_text}

{format_today(today)}

Their library (pick by id):
{library_text}

Rules:
1. Prefer today's plan drill. Pick a different library drill only when the numbers argue for it (a rating that dropped, a weak spot untouched for 10+ days, a category under 15%). Say so in the reasoning.
2. Set is_from_library true and library_exercise_id to an id from the list. Only if the library has nothing for the focus area, set is_from_library false and describe a drill in one line; the app will build it.
3. focus_area is one of the player's skills (Passing, Shooting, First Touch, Dribbling, Defending, Positioning, Speed & Agility, Stamina, Weak Foot, Aerial Ability).
4. reasoning: one sentence to the player, citing a number. cue: one coaching cue, imperative, at most 12 words.
5. additional_tips: 0–2 short tips. insights: 0–2, each with a number. streak_message only when streak > 3.

Return ONLY valid JSON:
{{"focus_area": "Passing", "reasoning": "Your passing ratings dropped from 3.6 to 2.8 this week, so we go back to the wall today.", "cue": "Open your hips before the second touch.", "recommended_drill": {{"name": "Two-touch wall passing", "description": "One sentence", "category": "technical", "difficulty": 2, "duration": 15, "steps": ["Step 1", "Step 2"], "equipment": ["ball", "wall"], "target_skills": ["passing", "first touch"], "is_from_library": true, "library_exercise_id": "<id from the list or null>"}}, "additional_tips": ["Tip"], "streak_message": null, "insights": [{{"title": "Title", "description": "Description with a number", "type": "celebration|recommendation|warning|pattern", "priority": 7, "actionable": null}}]}}"""


def build_weekly_review_prompt(
    *,
    player_profile: Dict[str, Any],
    plan_name: str,
    week_number: int,
    week_summary: str,
    sessions_completed: int,
    total_sessions: int,
    avg_rating: float,
    recap: Optional[Dict[str, Any]],
    next_week: Dict[str, Any],
) -> str:
    recap_text = ""
    if recap:
        recap_text = (
            f"Recap the app already shows: {recap.get('done', 0)}/{recap.get('planned', 0)} sessions, "
            f"{recap.get('minutes', 0)} min, {recap.get('missed', 0)} missed day(s), effort {recap.get('effort', 'n/a')}"
            + (f", best drill {recap.get('best_drill')}" if recap.get("best_drill") else "")
            + "."
        )
    return f"""Review this training week and propose changes for next week.

Player: Age {player_profile.get('age', '?')}, {player_profile.get('position', '?')}, {player_profile.get('experience', 'intermediate')}
Plan: {plan_name}
Week {week_number}: {sessions_completed}/{total_sessions} sessions, avg rating {avg_rating:.1f}/5
{recap_text}

Week details:
{week_summary or 'No data'}

Next week as currently planned:
{json.dumps(next_week, indent=2)}

Rules:
1. summary: two sentences to the player. What held up, what to change. Cite a number.
2. Propose 0–3 adaptations. Each is one of: add_session, modify_difficulty, remove_session, swap_exercise.
3. Each adaptation carries a reason: one sentence with the number that argues for it. No reason, no change.
4. Be conservative. A missed week means lighter, not harder.

Return ONLY valid JSON:
{{"summary": "Two sentences.", "adaptations": [{{"type": "modify_difficulty", "day": 2, "session_index": 0, "description": "Dribbling from level 3 to 4", "reason": "You rated all three dribbling drills 5/5.", "old_difficulty": 3, "new_difficulty": 4, "drill": null}}]}}"""
