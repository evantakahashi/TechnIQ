"""Single-LLM-call orchestrator. Collapses Scout+Coach+Writer+Referee."""
from __future__ import annotations

from typing import Any, Callable

from archetype_picker import pick_archetype
from category_rules import get_rule_pack
from dsl_parser import DSLParseError, parse_dsl
from drill_post_processor import post_process_drill
from drill_quality import score_drill_quality
from drill_validator import ValidationError, validate_drill
from exemplars import get_exemplars


MAX_ATTEMPTS = 4

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
  `goal GL at (x, y) width 7.32`, `player P1 at (x, y) role "worker"` (or `"server"` or `"defender"`),
  optional `label "..."` on players.
- Actions: `step N: ID verb ID` where verb in {passes to, dribbles to, runs to, shoots at, receives from}
- Coaching points: `point: <freeform text>` - these must reinforce the requested skill.

Rules:
- Every step ID must refer to a declared element.
- Step numbers start at 1 and increase by 1.
- Use coordinates in meters. Keep the drill inside a 20m x 15m area.
- The drill must TRAIN THE REQUESTED SKILL, not generic ball-work.
- Prioritize game-relevant reps: every step should move the worker toward or through the requested skill.
"""

AGE_MAX_SPACING = {8: 7.0, 12: 10.0, 99: 15.0}


class DrillGenerationFailed(RuntimeError):
    """Raised when the LLM cannot produce a valid drill within MAX_ATTEMPTS."""


class QualityError(RuntimeError):
    """Raised when a parsed drill fails the coaching-quality gate."""

    def __init__(self, reasons: list[str]):
        self.reasons = reasons
        super().__init__("; ".join(reasons))


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
    category = request.get("category") or "technical"
    number_of_players = int(request.get("number_of_players") or 2)
    field_size = request.get("field_size") or "small"
    recent_drill_names = request.get("recent_drill_names") or []
    playing_style = request.get("playing_style") or ""
    skill_goals = request.get("skill_goals") or []

    archetype = pick_archetype(weakness, level)
    exemplars = get_exemplars(archetype, level=level, n=3)
    rule_pack = get_rule_pack(weakness)
    age_cap = _age_cap(age)

    errors: list[tuple[str, str]] = []

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
            rule_pack=rule_pack,
            prior_errors=errors,
            category=category,
            number_of_players=number_of_players,
            field_size=field_size,
            recent_drill_names=recent_drill_names,
            playing_style=playing_style,
            skill_goals=skill_goals,
        )
        raw = llm_call(prompt)
        try:
            drill = parse_dsl(raw)
            drill["equipment"] = equipment
            drill, _warnings = post_process_drill(drill, player_age=age)
            validate_drill(drill)
            score, reasons = score_drill_quality(drill, rule_pack, level)
            c2_failed = any(r.startswith("C2:") for r in reasons)
            if score < 3 or (level != "beginner" and c2_failed):
                raise QualityError(reasons)
            return drill
        except (DSLParseError, ValidationError) as e:
            errors.append(("syntax", str(e)))
        except QualityError as e:
            errors.append(("quality", "; ".join(e.reasons)))

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


_PERIODIZATION_BY_LEVEL = {
    "beginner":     "Isolated practice: technical reps with 0 defenders OK. Focus on clean mechanics.",
    "intermediate": "Analytical practice: passive pressure — a server participates and constrains choices. Moderate decision load.",
    "advanced":     "Global practice: active pressure — a defender closes, real decisions required, game-realistic transitions.",
}

_ELITE_REQUIREMENTS = """\
For intermediate/advanced, the drill MUST include ALL of:
- Active resistance: a server who passes, a defender who closes, or a trigger that forces a decision.
- Directionality: a clear objective end (goal, gate, or line) and a reset state.
- Scanning: the worker must look away from the ball at some point (e.g., reads a visual cue from the server before the next action).
"""


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
    rule_pack: dict[str, Any] | None,
    prior_errors: list[tuple[str, str]],
    category: str = "technical",
    number_of_players: int = 2,
    field_size: str = "small",
    recent_drill_names: list[str] | None = None,
    playing_style: str = "",
    skill_goals: list[str] | None = None,
) -> str:
    focus = _format_focus(skill_description, weakness, selected_weaknesses)

    lines = [SYSTEM_PROMPT, ""]

    # Periodization banner
    peri = _PERIODIZATION_BY_LEVEL.get(level, _PERIODIZATION_BY_LEVEL["intermediate"])
    lines += ["PRACTICE TYPE BY LEVEL:", f"- {level} → {peri}", ""]

    # Elite requirements for intermediate/advanced
    if level in ("intermediate", "advanced"):
        lines += [_ELITE_REQUIREMENTS, ""]

    # Category rule pack (only when covered)
    if rule_pack is not None:
        lines += [
            f"SKILL-SPECIFIC COACHING REQUIREMENTS ({weakness}):",
            f"Primary action the drill must force: {rule_pack['primary_action']}",
            f"Must include: {', '.join(rule_pack['must_include'])}",
            f"Must avoid: {', '.join(rule_pack['must_avoid'])}",
            f"Success metric: {rule_pack['success_metric']}",
            f"Perception-action cue: {rule_pack['perception_action_cue']}",
            "",
        ]

    # Prior attempt errors (typed as syntax|quality)
    if prior_errors:
        lines.append("PRIOR ATTEMPT ERRORS:")
        for tag, msg in prior_errors:
            if tag == "quality":
                lines.append(f"- [quality] PRIOR ATTEMPT WAS VALID DSL BUT NOT A USEFUL PRACTICE: {msg}")
            else:
                lines.append(f"- [{tag}] {msg}")
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
            if cat or spec:
                lines.append(f"  - {cat}: {spec}")
    lines += [
        f"Starting archetype (a shape to adapt, not copy): {archetype}",
        f"Constraints: max area 20x15m, max cone spacing {age_cap}m, equipment {equipment}",
        "",
    ]

    # Exemplar block — or graceful degradation
    if exemplars:
        lines.append("Reference drills (for DSL grammar and ideas - do NOT copy their layout):")
        for ex in exemplars:
            lines.append(ex["dsl"])
            lines.append("---")
    else:
        lines.append(
            "No matching reference drill for this pressure level. "
            "Design from first principles using the skill-specific requirements and elite rules above."
        )

    lines += [
        "",
        f"Design a drill that maximizes game-relevant reps of: {focus}",
        "Adapt or depart from the references as needed. The drill's purpose is the skill, not the shape.",
        "Output DSL only.",
    ]
    return "\n".join(lines)
