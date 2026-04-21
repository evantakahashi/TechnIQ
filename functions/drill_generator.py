"""Single-LLM-call orchestrator. Collapses Scout+Coach+Writer+Referee."""
from __future__ import annotations

from typing import Any, Callable

from archetype_picker import pick_archetype
from dsl_parser import DSLParseError, parse_dsl
from drill_post_processor import post_process_drill
from drill_validator import ValidationError, validate_drill
from exemplars import get_exemplars


MAX_ATTEMPTS = 2

SYSTEM_PROMPT = """\
You design soccer training drills. Your #1 job: make the player REPEATEDLY PRACTICE THE REQUESTED SKILL.
The archetype/examples below are a starting shape, NOT a template. Adapt or depart from them if a different
structure gives the player more reps of the skill.

Before writing DSL, reason briefly (to yourself, not in output):
  1. What exact action trains this skill? (e.g., "first touch under pressure" -> receive a ball while a defender closes)
  2. How do I force that action many times in ~10-15 minutes?
  3. Which example comes closest, and what do I need to CHANGE to fit this skill?

Then output ONLY valid DSL - no markdown, no prose, no code fences, no reasoning.

DSL grammar:
- Elements: `cone C1 at (x, y)`, `gate G1 at (x, y) width 2`, `ball B1 at (x, y)`,
  `goal GL at (x, y) width 7.32`, `player P1 at (x, y) role "worker"` (or `"server"`),
  optional `label "..."` on players.
- Actions: `step N: ID verb ID` where verb in {passes to, dribbles to, runs to, shoots at, receives from}
- Coaching points: `point: <freeform text>` - these must reinforce the requested skill.

Rules:
- Every step ID must refer to a declared element.
- Step numbers start at 1 and increase by 1.
- Use coordinates in meters. Keep the drill inside a 20m x 15m area.
- The drill must TRAIN THE REQUESTED SKILL, not generic ball-work.
"""

AGE_MAX_SPACING = {8: 7.0, 12: 10.0, 99: 15.0}


class DrillGenerationFailed(RuntimeError):
    """Raised when the LLM cannot produce a valid drill within MAX_ATTEMPTS."""


def generate_drill(
    request: dict[str, Any],
    llm_call: Callable[[str], str],
) -> dict[str, Any]:
    """Run the full pipeline. request keys:
        weakness (str), experience_level, player_age, position, equipment.
        Optional: skill_description (str), selected_weaknesses (list[{category, specific}]).
    llm_call is a function that takes a prompt and returns the raw LLM output.
    """
    weakness = request["weakness"]
    level = request["experience_level"]
    age = int(request["player_age"])
    position = request["position"]
    equipment: list[str] = list(request["equipment"])
    skill_description = (request.get("skill_description") or "").strip()
    selected_weaknesses = request.get("selected_weaknesses") or []

    archetype = pick_archetype(weakness, level)
    exemplars = get_exemplars(archetype, n=3)
    age_cap = _age_cap(age)

    errors: list[str] = []

    for _attempt in range(MAX_ATTEMPTS):
        prompt = _build_prompt(
            weakness=weakness,
            skill_description=skill_description,
            selected_weaknesses=selected_weaknesses,
            level=level,
            age=age,
            position=position,
            equipment=equipment,
            archetype=archetype,
            age_cap=age_cap,
            exemplars=exemplars,
            prior_errors=errors,
        )
        raw = llm_call(prompt)
        try:
            drill = parse_dsl(raw)
            drill["equipment"] = equipment
            drill, _warnings = post_process_drill(drill, player_age=age)
            validate_drill(drill)
            return drill
        except (DSLParseError, ValidationError) as e:
            errors.append(str(e))

    raise DrillGenerationFailed(f"Exhausted {MAX_ATTEMPTS} attempts: {errors}")


def _age_cap(age: int) -> float:
    for max_age, cap in sorted(AGE_MAX_SPACING.items()):
        if age <= max_age:
            return cap
    return AGE_MAX_SPACING[99]


def _format_focus(skill_description: str, weakness: str,
                  selected_weaknesses: list[dict[str, Any]]) -> str:
    """Pick the richest available signal as the LLM's training target."""
    if skill_description:
        return skill_description
    if selected_weaknesses:
        parts = [f"{w.get('category', '')} - {w.get('specific', '')}".strip(" -")
                 for w in selected_weaknesses if w]
        parts = [p for p in parts if p]
        if parts:
            return "; ".join(parts)
    return weakness


def _build_prompt(
    *,
    weakness: str,
    skill_description: str,
    selected_weaknesses: list[dict[str, Any]],
    level: str,
    age: int,
    position: str,
    equipment: list[str],
    archetype: str,
    age_cap: float,
    exemplars: list[dict[str, Any]],
    prior_errors: list[str],
) -> str:
    focus = _format_focus(skill_description, weakness, selected_weaknesses)

    lines = [SYSTEM_PROMPT, ""]
    if prior_errors:
        lines.append("PRIOR ATTEMPT ERRORS:")
        for err in prior_errors:
            lines.append(f"- {err}")
        lines.append("")
    lines += [
        "=" * 60,
        f"SKILL TO TRAIN (this is what matters most): {focus}",
        "=" * 60,
        "",
        f"Player: age {age} {position}, experience {level}",
    ]
    if selected_weaknesses:
        lines.append("Specific weaknesses flagged:")
        for w in selected_weaknesses:
            cat = w.get("category", "")
            spec = w.get("specific", "")
            lines.append(f"  - {cat}: {spec}" if cat or spec else "")
    lines += [
        f"Starting archetype (a shape to adapt, not copy): {archetype}",
        f"Constraints: max area 20x15m, max cone spacing {age_cap}m, equipment {equipment}",
        "",
        f"Reference drills (for DSL grammar and ideas - do NOT copy their layout):",
    ]
    for ex in exemplars:
        lines.append(ex["dsl"])
        lines.append("---")
    lines += [
        "",
        f"Design a drill that maximizes reps of: {focus}",
        "Adapt or depart from the references as needed. The drill's purpose is the skill, not the shape.",
        "Output DSL only.",
    ]
    return "\n".join(lines)
