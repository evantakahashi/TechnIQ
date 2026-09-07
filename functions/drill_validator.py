"""Structural integrity checks for drill diagrams. Runs after post_processor."""
from __future__ import annotations

from typing import Any

# Which element types each equipment string authorizes
EQUIPMENT_TO_ELEMENT_TYPES: dict[str, set[str]] = {
    "ball":    {"ball"},
    "cones":   {"cone"},
    "goals":   {"goal"},
    "wall":    {"wall"},
    "partner": {"player", "server", "defender"},
    "hurdles": {"cone"},
    "ladder":  {"cone"},
    "poles":   {"cone"},
}

# Element types that do not require equipment authorization
IMPLICIT_ELEMENT_TYPES: set[str] = {"player", "gate"}


def _element_types_for_equipment(item: str) -> set[str]:
    """Resolve one user/AI-supplied equipment string to authorized element types.

    Tolerates case, whitespace, singular/plural, and compound names
    ("Goal", "mini goals", "agility ladder") — exact-match lookups blocked
    real drills whenever the wording drifted from the canonical keys.
    """
    key = item.strip().lower()
    if key in EQUIPMENT_TO_ELEMENT_TYPES:
        return EQUIPMENT_TO_ELEMENT_TYPES[key]
    for variant in (key + "s", key.rstrip("s")):
        if variant in EQUIPMENT_TO_ELEMENT_TYPES:
            return EQUIPMENT_TO_ELEMENT_TYPES[variant]
    resolved: set[str] = set()
    for canonical, types in EQUIPMENT_TO_ELEMENT_TYPES.items():
        stem = canonical.rstrip("s")
        if stem and stem in key:
            resolved.update(types)
    return resolved


class ValidationError(ValueError):
    """Raised when a drill fails a structural integrity check."""


def validate_drill(drill: dict[str, Any]) -> None:
    """Raise ValidationError if the drill fails any of the 5 checks."""
    diagram = drill.get("diagram", {})
    elements: list[dict[str, Any]] = diagram.get("elements", [])
    paths: list[dict[str, Any]] = diagram.get("paths", [])
    equipment: list[str] = drill.get("equipment", [])
    field: dict[str, Any] = diagram.get("field", {})

    _check_at_least_one_step(paths)
    _check_step_numbers_contiguous(paths)
    _check_step_targets_exist(elements, paths)
    _check_equipment_consistency(elements, equipment)
    _check_at_least_one_worker(elements)
    _check_shot_targets(elements, paths)
    _check_goals_on_edge(elements, field)
    _check_gates_inside_goal_mouth(elements)
    _check_ball_continuity(elements, paths)
    _check_no_redundant_movement(paths)
    _check_duel_not_overscripted(elements, paths, bool(drill.get("is_duel")))
    _check_serve_distances(elements, paths)
    _check_header_volume(drill.get("coaching_points") or [])


def _check_at_least_one_step(paths: list[dict[str, Any]]) -> None:
    if not paths:
        raise ValidationError("drill must have at least one action step")


def _check_step_numbers_contiguous(paths: list[dict[str, Any]]) -> None:
    nums = sorted(p.get("step", 0) for p in paths)
    expected = list(range(1, len(nums) + 1))
    if nums != expected:
        raise ValidationError(
            f"step numbers must be contiguous from 1; got {nums}"
        )


def _check_step_targets_exist(
    elements: list[dict[str, Any]], paths: list[dict[str, Any]]
) -> None:
    ids = {e["label"] for e in elements}
    for p in paths:
        for key in ("from", "to"):
            if p.get(key) not in ids:
                raise ValidationError(
                    f"step {p.get('step')} references unknown element {p.get(key)!r}"
                )


def _check_equipment_consistency(
    elements: list[dict[str, Any]], equipment: list[str]
) -> None:
    allowed_types: set[str] = set(IMPLICIT_ELEMENT_TYPES)
    for item in equipment:
        allowed_types.update(_element_types_for_equipment(item))
    for el in elements:
        t = el.get("type")
        if t not in allowed_types:
            raise ValidationError(
                f"element type {t!r} not authorized by equipment {equipment}"
            )


def _check_at_least_one_worker(elements: list[dict[str, Any]]) -> None:
    for el in elements:
        if el.get("type") == "player" and el.get("role") == "worker":
            return
    raise ValidationError("drill must have at least one worker player")


def _check_goals_on_edge(
    elements: list[dict[str, Any]], field: dict[str, Any]
) -> None:
    """Goals floating mid-pitch look unscoreable in the diagram.

    Require every goal within 2.5m of a field edge so its mouth can face play.
    """
    try:
        width = float(field.get("width") or 0)
        length = float(field.get("length") or 0)
    except (TypeError, ValueError):
        return
    if width <= 0 or length <= 0:
        return
    for el in elements:
        if el.get("type") != "goal":
            continue
        try:
            x, y = float(el.get("x")), float(el.get("y"))
        except (TypeError, ValueError):
            continue
        if min(x, width - x, y, length - y) > 2.5:
            raise ValidationError(
                f"goal {el.get('label')!r} at ({x}, {y}) floats mid-field; "
                "place goals on a field edge so shots can face them"
            )


def _check_gates_inside_goal_mouth(elements: list[dict[str, Any]]) -> None:
    """Gates ON a goal's line must fit INSIDE the goal mouth.

    Coach review found corner-target gates placed ~1m outside the posts —
    "score through the gate" then means shooting wide. A gate is on the goal
    line when its perpendicular distance to the goal (the small axis) is
    ≤1.5m; its offset along the mouth must then fit within the goal width.
    Free-standing gates in front of goal (perpendicular > 1.5m) are exempt.
    """
    goals = [e for e in elements if e.get("type") == "goal"]
    if not goals:
        return
    for el in elements:
        if el.get("type") != "gate":
            continue
        try:
            gx, gy = float(el.get("x")), float(el.get("y"))
            gw = float(el.get("width") or 1.5)
        except (TypeError, ValueError):
            continue
        for goal in goals:
            try:
                ox, oy = float(goal.get("x")), float(goal.get("y"))
                ow = float(goal.get("width") or 7.32)
            except (TypeError, ValueError):
                continue
            dx, dy = abs(gx - ox), abs(gy - oy)
            perp, along = (dx, dy) if dx <= dy else (dy, dx)
            if perp > 1.5:
                continue  # gate in front of / away from the goal line
            if along + gw / 2 > ow / 2 + 0.1:
                raise ValidationError(
                    f"gate {el.get('label')!r} sits outside the goal mouth of "
                    f"{goal.get('label')!r} (offset {along:.1f}m + half-width "
                    f"{gw / 2:.1f}m exceeds goal half-width {ow / 2:.1f}m); "
                    "in-goal target gates must fit between the posts"
                )


def _check_ball_continuity(
    elements: list[dict[str, Any]], paths: list[dict[str, Any]]
) -> None:
    """Simulate ball possession across steps; reject impossible sequences.

    User review found drills where a player passes a ball they don't have,
    or keeps playing after a shot as if a fresh ball appeared. Model:
    - A player holds a ball if they start within 1.5m of a ball element, or
      within 2.5m at start (the post-processor separates overlapping
      elements by ~2m), acquire one by running to a ball / its rest spot, or
      by receiving a pass.
    - pass/dribble/shoot REQUIRE holding the ball. A shot/pass releases it
      (it rests at the target); running to that target re-collects it.
    - "receives from X" gives the receiver the ball if X holds one (or X is
      a wall/ball).
    """
    by_label = {e.get("label"): e for e in elements}
    ball_labels = [e.get("label") for e in elements if e.get("type") == "ball"]
    if not ball_labels:
        return  # no declared balls — nothing to track

    def near(a: dict, b: dict, r: float = 2.5) -> bool:
        try:
            return ((float(a["x"]) - float(b["x"])) ** 2
                    + (float(a["y"]) - float(b["y"])) ** 2) ** 0.5 <= r
        except (TypeError, ValueError, KeyError):
            return False

    unclaimed: set[str] = set(ball_labels)
    holder: str | None = None          # label of the player holding a ball
    resting_at: str | None = None      # element label where a live ball rests

    # Initial possession: a player standing on a ball starts with it.
    for e in elements:
        if e.get("type") != "player":
            continue
        for bl in list(unclaimed):
            if near(e, by_label[bl]):
                holder = e.get("label")
                unclaimed.discard(bl)
                break
        if holder:
            break

    for p in sorted(paths, key=lambda x: x.get("step", 0)):
        step, style = p.get("step"), p.get("style")
        src, dst = p.get("from"), p.get("to")
        needs_ball = style in ("pass", "dribble", "shoot", "shot", "throw", "toss", "header")

        if needs_ball and holder != src:
            # Acquisition on the move: standing on / moving through a ball spot.
            src_el, got = by_label.get(src), False
            if src_el is not None:
                for bl in list(unclaimed):
                    # 3.0m: a staged stack beside a server is within reach even
                    # after the post-processor's de-overlap spreading.
                    if near(src_el, by_label[bl], 3.0):
                        holder, got = src, True
                        unclaimed.discard(bl)
                        break
            if not got:
                where = f"the ball is with {holder}" if holder else (
                    f"the ball rests at {resting_at}" if resting_at
                    else "no ball is at their feet")
                verb = {"pass": "passes", "dribble": "dribbles",
                        "shoot": "shoots", "shot": "shoots"}.get(style, style)
                raise ValidationError(
                    f"step {step}: {src} {verb} but {where}; a player can "
                    "only pass/dribble/shoot a ball they have — collect one "
                    "first (run to a ball, or to where it came to rest)"
                )

        if style == "dribble":
            pass  # ball travels with the holder
        elif style in ("pass", "throw", "toss", "header"):
            dst_el = by_label.get(dst, {})
            if dst_el.get("type") == "player":
                holder = dst
            elif dst_el.get("type") == "wall":
                pass  # rebound — the ball comes straight back to the passer
            else:  # goal/gate — ball rests there until collected
                holder, resting_at = None, dst
        elif style in ("shoot", "shot"):
            if by_label.get(dst, {}).get("type") == "wall":
                pass  # wall rebounds to the striker
            else:
                holder, resting_at = None, dst
        elif style == "receive":
            # "src receives from dst": dst surrenders the ball to src.
            if holder == dst or by_label.get(dst, {}).get("type") in ("wall", "ball") \
               or resting_at == dst:
                holder, resting_at = src, None
        elif style == "run":
            dst_el = by_label.get(dst, {})
            if dst_el.get("type") == "ball" and dst in unclaimed:
                unclaimed.discard(dst)
                holder = src
            elif holder is None:
                # Collect the resting ball only when nobody holds one — with a
                # held ball in play, a run past the goal is just movement.
                rest_el = by_label.get(resting_at) if resting_at else None
                near_rest = rest_el is not None and dst_el and near(dst_el, rest_el, 2.0)
                if dst == resting_at or near_rest:
                    holder, resting_at = src, None


def _check_no_redundant_movement(paths: list[dict[str, Any]]) -> None:
    """Consecutive steps must not move the same actor to the same target."""
    prev: dict[str, Any] | None = None
    for p in sorted(paths, key=lambda x: x.get("step", 0)):
        if prev is not None and p.get("from") == prev.get("from") \
           and p.get("to") == prev.get("to") \
           and p.get("style") in ("run", "dribble") \
           and prev.get("style") in ("run", "dribble"):
            raise ValidationError(
                f"steps {prev.get('step')} and {p.get('step')} both move "
                f"{p.get('from')} to {p.get('to')} — redundant; combine them "
                "or send the player somewhere new"
            )
        prev = p


# What a shot may be aimed at. Without this, ball-only drills produced
# "P1 shoots at B5" — a player shooting at another ball.
SHOOTABLE_TARGET_TYPES: set[str] = {"goal", "gate", "wall"}


def _check_shot_targets(
    elements: list[dict[str, Any]], paths: list[dict[str, Any]]
) -> None:
    types_by_label = {e.get("label"): e.get("type") for e in elements}
    for p in paths:
        if p.get("style") in ("shoot", "shot"):
            target_type = types_by_label.get(p.get("to"))
            if target_type not in SHOOTABLE_TARGET_TYPES:
                raise ValidationError(
                    f"step {p.get('step')}: shot target {p.get('to')!r} is a "
                    f"{target_type or 'missing element'}; shots must aim at a "
                    "goal, gate, or wall"
                )


def _check_duel_not_overscripted(
    elements: list[dict[str, Any]], paths: list[dict[str, Any]],
    is_duel: bool = False,
) -> None:
    """Reactive duels — script only the serve and engage. Prompt guidance was
    ignored twice; enforce a hard cap. Defending requests mark the WORKER as
    the defender (no defender-role element), so the generator stamps is_duel.
    """
    has_defender = any(
        e.get("type") == "player" and e.get("role") == "defender"
        for e in elements
    )
    if (has_defender or is_duel) and len(paths) > 3:
        raise ValidationError(
            f"duel drills must show only positions and the attack direction — "
            f"max 3 steps, got {len(paths)}; put the rules, scoring and "
            "outcomes and decision rules in the coaching points instead"
        )


def _check_serve_distances(
    elements: list[dict[str, Any]], paths: list[dict[str, Any]]
) -> None:
    """Heading serves must be soft and short: tosses travel ≤8m."""
    by_label = {e.get("label"): e for e in elements}
    for p in paths:
        if p.get("style") != "toss":
            continue
        a, b = by_label.get(p.get("from")), by_label.get(p.get("to"))
        if not a or not b:
            continue
        try:
            d = ((float(a["x"]) - float(b["x"])) ** 2
                 + (float(a["y"]) - float(b["y"])) ** 2) ** 0.5
        except (TypeError, ValueError, KeyError):
            continue
        if d > 8.0:
            raise ValidationError(
                f"step {p.get('step')}: toss travels {d:.1f}m — heading "
                "serves must be soft underhand tosses from ≤8m; move the "
                "server closer"
            )


def _check_header_volume(coaching_points: list) -> None:
    """Cap prescribed heading volume for youth safety (≤15 per session)."""
    import re as _re
    for cp in coaching_points:
        text = str(cp).lower()
        if "head" not in text:
            continue
        total = None
        m = _re.search(r"(\d+)\s*(?:headers?|reps?)\s*(?:x|×|per set[, ]+)\s*(\d+)", text)
        if m:
            total = int(m.group(1)) * int(m.group(2))
        else:
            m = _re.search(r"(\d+)\s*headers?", text)
            if m:
                total = int(m.group(1))
        if total is not None and total > 15:
            raise ValidationError(
                f"coaching prescribes ~{total} headers — cap heading volume "
                "at 15 per session for youth safety (fewer reps, quality serves)"
            )
