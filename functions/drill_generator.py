"""Single-LLM-call orchestrator. Collapses Scout+Coach+Writer+Referee."""
from __future__ import annotations

from typing import Any, Callable

from archetype_picker import pick_archetype
from category_rules import get_rule_pack
from dsl_parser import DSLParseError, parse_dsl
from drill_post_processor import post_process_drill, annotate_path_positions
from drill_quality import score_drill_quality
from drill_validator import ValidationError, validate_drill
from exemplars import get_exemplars


MAX_ATTEMPTS = 5

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
  `goal GL at (x, y) width 7.32`, `wall W1 at (x, y) width 5` (use ONLY when "wall" is in equipment),
  `player P1 at (x, y) role "worker"` (or `"server"` or `"defender"`),
  optional `label "..."` on players.
- Actions: `step N: ID verb ID` where verb in {passes to, dribbles to, runs to, shoots at, receives from, throws to, tosses to, heads to}
- `throws to` = hand distribution (goalkeepers); `tosses to` = soft underhand serve (heading/volley work); `heads to` = aerial header at a goal/gate/player. Use these for GK and heading drills — never fake them with foot passes.
- Valid `passes to` targets: player, server, defender, wall, goal, or a GATE used as a landing zone (chips/through-balls arrive there). Never pass to a cone or ball.
- Valid `shoots at` targets: goal, gate, wall ONLY — never a ball, cone, or player. If no goal is in the equipment, declare a gate and shoot through it.
- Coaching points: `point: <freeform text>` - these must reinforce the requested skill.

Rules:
- Every step ID must refer to a declared element.
- Step numbers start at 1 and increase by 1.
- Use coordinates in meters. Keep the drill inside the field dimensions specified below.
- The drill must TRAIN THE REQUESTED SKILL, not generic ball-work.
- Prioritize game-relevant reps: every step should move the worker toward or through the requested skill.

Geometry (draw it like a real pitch — a coach will see this diagram):
- Goals sit ON a field edge (within 2.5m), mouth facing play. Never float a goal mid-pitch.
- A 7.32m goal's mouth spans its center ±3.66m. In-goal target gates must sit INSIDE that span (e.g. gate centers at goal center ±2.2m) — a gate outside the posts means "aim wide".
- A target gate sits ON the line of the action it measures: a passing gate goes BETWEEN passer and receiver so the pass must split it, not beside the lane.
- Defensive clearances/headers are aimed AWAY from the defender's own goal — clearance targets go upfield or wide, never between the defender and the goal they protect.
- Targets must be REACHABLE: never place a gate or goal behind a wall or outside the play direction. Finishes happen at the END of a forward rep toward the target — never backward through the course just completed.
- Cones never return the ball. A rebound needs a wall; a served ball needs a server or a self-serve (toss it up yourself).
- Walls return GROUND balls at matching pace — never claim a wall serves bouncing or lofted balls; for aerial/bouncing receives use self-toss or a server.
- With a server: script the full cycle — serve, action, collect, return (`runs to` the resting ball, `dribbles to` the server, server `receives from` them) — then the next serve. Two scripted cycles is enough; coaching says it repeats.
- Shooting positions sit 8-18m from the goal (3-8m only for beginner mini-goal finishing). Never place a shot 0-3m from the goal line.
- Crosses are delivered from WIDE positions near the SAME end line as the goal, not from the opposite half or opposite corner.
- Never route a dribble or run path through the goalmouth or through other cones/elements — go around.
- Defenders start goal-side of the attacker they are defending, within pressing distance (2-6m).
- Every element you declare must be used by at least one step or serve an obvious purpose (gate to dribble through, cone marking a turn). No decoration.
- Only declare a ladder/hurdle pattern if you actually use tight cone spacing (0.75-1.5m gaps) for it.

BALL TRACKING (steps are a story a kid follows literally — the ball must be traceable):
- A player can only pass/dribble/shoot a ball AT THEIR FEET. Start the worker on a ball, or make their first step "runs to <ball>".
- A pass moves the ball to the receiver; a shot leaves the ball at the target. After a shot, the next ball action requires collecting a ball first (run to the next ball, or to where it went).
- Never write "runs to X" then "dribbles to X" for the same player and target — one movement per intent.
- Never have a player pass to someone who already has the ball.
- Reactive duels (1v1 defending, pressing): script only the SETUP (serve, engage) in steps — 4-6 steps max — and put the outcomes and decision rules in the coaching points. Do not choreograph both players' every move; a duel has many endings.
- Duels are GAMES WITH RULES, not choreography: at most 2-3 steps. Step 1 is ALWAYS the attacker dribbling AT the opponent from 2-8m (the engage); an optional step 2 shows one break toward a gate. The defender starts BETWEEN the attacker and the gates (that's what defending means). No cones in duels — two players, one ball, the gates. Coaching states HOW IT WORKS: objective, what counts as a win for each side, when to swap ('swap after 3 attacks').
- NEVER write raw coordinates like (5, 7.5) in coaching points — kids read those; use soccer language ('start on the halfway line').
- Heading serves come from UPFIELD of the defender (in front, goal-side of the SERVER), never from the defender's own-goal side.

TWO-PHASE SKILLS (receive-then-play-forward, control-then-escape, save-then-distribute):
- DRAW PHASE TWO. If the skill ends with playing through a target, at least half the reps must show a ball path INTO that target — a gate named in the scoring that no ball ever visits is a broken drill.
- One live ball per drill: a server never feeds a second ball until the first is dead and collected.
- Role math must work: 'pressing as a pair' needs 2 pressers + a carrier (3) — with fewer players, redefine the drill honestly.

SESSION SHAPE (a drill is a repeatable block, not one pretty sequence):
- 8-16 steps that form a REPEATING cycle: the worker does the skill, resets, does it again. Reuse the same targets across steps.
- ONE BALL ON THE PITCH: declare exactly ONE ball element, at the feet of whoever starts with it. Extra supply balls are NEVER drawn — mention a stack in a coaching point if useful. Every cycle scripts the collect-and-return: after a shot/cross, someone runs to the ball and works it back (that jog is the rest). Use `receives from` to hand the ball over.
- ACCURACY skills: the finish must beat a TARGET, not just enter a goal — place 1-2 gates inside the goal (e.g. bottom corners) or a cone target, and require reps through it.
- 6-9 coaching points. The FIRST is the warm-up. Exactly one states a countable target ("8 of 10 through the gate"). One states set/rep volume and the rest pattern ("5 strikes per set, 4 sets; collecting balls is the rest"). One is a progression or regression ("hit 8/10 → move 2m back; miss 5 → bigger gate").
- If the skill names a foot or surface (weak foot, outside of boot), force it with geometry and a rule ("only weak-foot finishes count"), not just advice.

Safety (non-negotiable, applies to every drill):
- Match intensity and complexity to the player's age and level; never prescribe adult training loads to young players.
- Begin the coaching points with a 2-3 minute warm-up cue (light jogging + dynamic movement and easy ball touches) before any intense or high-skill work.
- For players under 13 (U13), avoid dangerous or high-impact movements and physical contact — no slide tackles, collisions, or heading drills.
- Heading drills (13+): cap volume at 10-15 headers per session, soft underhand serves from ≤8m — never long lofted service for repeated heading.
- Include at least one safe-technique cue (e.g., cushion the ball, land softly, keep the knee tracking over the toe) among the coaching points.
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
    # Normalize once for the whole pipeline: app sends "Beginner", rules compare lowercase.
    level = str(request["experience_level"] or "intermediate").strip().lower()
    if level in ("professional", "pro", "elite", "expert"):
        level = "advanced"  # rule packs/exemplars/quality gates speak beginner/intermediate/advanced
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

    archetype = pick_archetype(weakness, level, number_of_players)
    exemplars = get_exemplars(archetype, level=level, n=3, number_of_players=number_of_players)
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
        width, length = _FIELD_SIZE_DIMS.get(field_size, _FIELD_SIZE_DIMS["small"])
        raw = llm_call(prompt)
        try:
            drill = parse_dsl(raw)
            drill["diagram"]["field"] = {"width": width, "length": length}
            drill["equipment"] = equipment
            drill["category"] = category
            blob = f"{skill_description} {weakness}".lower()
            drill["is_duel"] = ("1v1" in blob) or ("pressing" in blob) or (
                category == "tactical" and number_of_players in (2, 3)
                and "head" not in blob
            )
            drill, _warnings = post_process_drill(drill, player_age=age)
            annotate_path_positions(drill)
            validate_drill(drill)
            score, reasons = score_drill_quality(drill, rule_pack, level,
                                                 number_of_players=number_of_players)
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

_FIELD_SIZE_DIMS = {
    "small":  (20, 15),
    "medium": (30, 20),
    "large":  (50, 30),
}

_ELITE_REQUIREMENTS = """\
For intermediate/advanced, the drill MUST include ALL of:
- Active resistance: a server who passes, a defender who closes, or a trigger that forces a decision.
- Directionality: a clear objective end (goal, gate, or line) and a reset state.
- Scanning: the worker must look away from the ball at some point (e.g., reads a visual cue from the server before the next action).
"""

# Solo variant — the standard block demands servers/defenders, which directly
# contradicts a 1-player request and made the model flail between retries.
_ELITE_REQUIREMENTS_SOLO = """\
For intermediate/advanced SOLO drills, the drill MUST include ALL of:
- Constraint pressure (replaces human resistance): a time cap per rep, a limited-touch rule, or an approach angle forced by cone/gate placement.
- Directionality: a clear objective end (goal or gate) and a stated reset — how the player collects the next ball and restarts.
- Scanning: a look-up moment built into each rep (e.g., glance at the target zone between the last touch and the strike).
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
    recent_drill_names = recent_drill_names or []
    skill_goals = skill_goals or []
    width, length = _FIELD_SIZE_DIMS.get(field_size, _FIELD_SIZE_DIMS["small"])

    lines = [SYSTEM_PROMPT, ""]

    # Periodization banner
    peri = _PERIODIZATION_BY_LEVEL.get(level, _PERIODIZATION_BY_LEVEL["intermediate"])
    lines += ["PRACTICE TYPE BY LEVEL:", f"- {level} → {peri}", ""]

    # Elite requirements for intermediate/advanced (solo-aware)
    if level in ("intermediate", "advanced"):
        block = _ELITE_REQUIREMENTS_SOLO if number_of_players == 1 else _ELITE_REQUIREMENTS
        lines += [block, ""]

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
        lines.append("PRIOR ATTEMPT ERRORS — FIX THESE EXACTLY:")
        for tag, msg in prior_errors:
            if tag == "quality":
                lines.append(f"- [quality] PRIOR ATTEMPT WAS VALID DSL BUT NOT A USEFUL PRACTICE: {msg}")
                if "measurable success metric" in msg:
                    lines.append(
                        "  FIX: add ONE coaching point stating a countable target, e.g. "
                        "'Target: 8 of 10 strikes on frame', '10 clean reps in a row', or "
                        "'complete 3 sets of 12'. Use a number + a unit."
                    )
                if "outcome element" in msg:
                    lines.append(
                        "  FIX: include a goal or gate element the worker finishes into, "
                        "and end at least one path there (shoots at / passes to)."
                    )
                if "rep loop" in msg:
                    lines.append(
                        "  FIX: make the worker repeat the action — reuse the same element "
                        "across at least two numbered steps so it clearly loops."
                    )
            else:
                lines.append(f"- [{tag}] {msg}")
                if "a player can only pass/dribble/shoot" in msg:
                    lines.append(
                        "  FIX: walk the ONE ball like a movie scene. To regain it after a "
                        "shot/cross: '<player> runs to <where it rests>'. To hand it to a "
                        "teammate: '<carrier> dribbles to <teammate>' THEN '<teammate> "
                        "receives from <carrier>' — without the receives step the carrier "
                        "still has it. A server can only serve after receiving it back."
                    )
                if "never played through" in msg:
                    lines.append(
                        "  FIX: end each rep AT the named gate — the last ball action of the "
                        "cycle is 'passes to <gate>' / 'shoots at <gate>' / 'dribbles to <gate>'. "
                        "If the gate is only a live option (duel), remove it from scoring or the diagram."
                    )
                if "redundant" in msg:
                    lines.append(
                        "  FIX: one movement per intent — merge the duplicate steps or send "
                        "the player to a different element."
                    )
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
    # Player count directive
    if number_of_players == 1:
        # Name only obstacles the equipment actually authorizes (+ gates, always legal).
        solo_obstacles = [item for item in ("cones", "walls") if any(item.rstrip("s") in e.lower() for e in equipment)]
        solo_obstacles.append("gates")
        player_directive = (
            "PLAYER COUNT: Use exactly 1 player (the worker). "
            "This is a SOLO drill — no partners (no server, no defender). "
            "If the requested skill inherently needs an opponent or server (e.g. 'under pressure', 'receiving'), "
            "train the closest solo-trainable version, say so honestly in the description, and add a coaching point "
            "that the full version needs a partner. Never pretend cones apply pressure. "
            f"Use static obstacles ({', '.join(solo_obstacles)}) and a measurable success target instead of human pressure."
        )
    elif number_of_players == 2:
        player_directive = "PLAYER COUNT: Use exactly 2 players (worker + 1 partner serving as server or defender)."
    elif number_of_players <= 4:
        player_directive = f"PLAYER COUNT: Use exactly {number_of_players} players (worker + {number_of_players - 1} partners)."
    else:
        player_directive = f"PLAYER COUNT: Use exactly {number_of_players} players — small-sided team drill."
    lines += [player_directive, ""]

    # Drill category context
    lines += [f"DRILL CATEGORY: {category}", ""]

    # Recent drill names — variety
    if recent_drill_names:
        lines += [
            "RECENT DRILLS (make this structurally distinct from these — different shape/pattern):",
        ] + [f"  - {n}" for n in recent_drill_names] + [""]

    # Player flavor — non-binding context
    if playing_style or skill_goals:
        flavor = ["PLAYER STYLE / GOALS (use to tailor coaching cues, not to constrain shape):"]
        if playing_style:
            flavor.append(f"  - Style: {playing_style}")
        if skill_goals:
            flavor.append(f"  - Goals: {', '.join(skill_goals)}")
        lines += flavor + [""]

    lines += [
        f"Starting archetype (a shape to adapt, not copy): {archetype}",
        f"Constraints: max area {width}x{length}m, max cone spacing {age_cap}m, equipment {equipment}",
        f"COORDINATES: the field spans x 0-{width} (attacking direction) and y 0-{length}. Origin (0,0) is a corner; attack toward the x={width} line.",
        "Equipment is what's AVAILABLE, not a checklist — use only the pieces the drill actually needs. A great drill with just a ball beats a cluttered one that forces every item in.",
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

    # Final checklist — recency wins: restate the constraints that failures
    # showed get lost when they only appear mid-prompt.
    solo_line = (
        "solo: every rep flows into the next — one-ball collect-and-return loop "
        "(or optional pre-placed supply); NO server/defender elements"
        if number_of_players == 1
        else f"exactly {number_of_players} players"
    )
    lines += [
        "",
        f"Design a drill that maximizes game-relevant reps of: {focus}",
        "Adapt or depart from the references as needed. The drill's purpose is the skill, not the shape.",
        "",
        "FINAL CHECK before you output:",
        f"- {solo_line}",
        "- 8-16 steps forming a repeating cycle; every declared element used",
        "- goals ON a field edge; shots 8-18m; accuracy skills finish through a target gate",
        "- 6-9 coaching points: warm-up FIRST, one countable target, one set/rep+rest line, one progression",
        "Output DSL only.",
    ]
    return "\n".join(lines)
