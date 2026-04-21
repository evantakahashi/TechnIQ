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
You design soccer training drills. Output ONLY valid DSL — no markdown, no prose, no code fences.

DSL grammar:
- Elements: `cone C1 at (x, y)`, `gate G1 at (x, y) width 2`, `ball B1 at (x, y)`,
  `goal GL at (x, y) width 7.32`, `player P1 at (x, y) role "worker"` (or `"server"`),
  optional `label "..."` on players.
- Actions: `step N: ID verb ID` where verb ∈ {passes to, dribbles to, runs to, shoots at, receives from}
- Coaching points: `point: <freeform text>`

Rules:
- Every step ID must refer to a declared element.
- Step numbers start at 1 and increase by 1.
- Use coordinates in meters. Keep the drill inside a 20m × 15m area.
"""

AGE_MAX_SPACING = {8: 7.0, 12: 10.0, 99: 15.0}


class DrillGenerationFailed(RuntimeError):
    """Raised when the LLM cannot produce a valid drill within MAX_ATTEMPTS."""


def generate_drill(
    request: dict[str, Any],
    llm_call: Callable[[str], str],
) -> dict[str, Any]:
    """Run the full pipeline. request keys:
        weakness, experience_level, player_age, position, equipment.
    llm_call is a function that takes a prompt and returns the raw LLM output.
    """
    weakness = request["weakness"]
    level = request["experience_level"]
    age = int(request["player_age"])
    position = request["position"]
    equipment: list[str] = list(request["equipment"])

    archetype = pick_archetype(weakness, level)
    exemplars = get_exemplars(archetype, n=3)
    age_cap = _age_cap(age)

    errors: list[str] = []

    for _attempt in range(MAX_ATTEMPTS):
        prompt = _build_prompt(
            weakness=weakness,
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


def _build_prompt(
    *,
    weakness: str,
    level: str,
    age: int,
    position: str,
    equipment: list[str],
    archetype: str,
    age_cap: float,
    exemplars: list[dict[str, Any]],
    prior_errors: list[str],
) -> str:
    lines = [SYSTEM_PROMPT, ""]
    if prior_errors:
        lines.append("PRIOR ATTEMPT ERRORS:")
        for err in prior_errors:
            lines.append(f"- {err}")
        lines.append("")
    lines += [
        f"Player: age {age} {position}, experience {level}",
        f"Weakness to train: {weakness}",
        f"Archetype: {archetype}",
        f"Constraints: max area 20x15m, max cone spacing {age_cap}m, equipment {equipment}",
        "",
        f"Examples of good {archetype} drills:",
    ]
    for ex in exemplars:
        lines.append(ex["dsl"])
        lines.append("---")
    lines += [
        "",
        "Now design a drill in the same style for the player above.",
        "Output DSL only.",
    ]
    return "\n".join(lines)
