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
IMPLICIT_ELEMENT_TYPES: set[str] = {"player", "gate", "mannequin", "cone"}
# cone: a spot marker is always improvisable (shirt, bottle) — and gates,
# which ARE two cones, were already implicit. Walls/goals stay gated.


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
    _check_duel_not_overscripted(elements, paths, bool(drill.get("is_duel")))
    _check_ball_continuity(elements, paths, bool(drill.get("is_duel")))
    _check_no_redundant_movement(paths)
    _check_gates_played_through(elements, paths, bool(drill.get("is_duel")))
    _check_single_ball(elements)
    _check_duel_shape(elements, paths, bool(drill.get("is_duel")))
    _check_no_coords_in_coaching(drill.get("coaching_points") or [])
    _check_no_zero_length_ball_actions(paths)
    _check_solo_pass_targets(elements, paths)
    _check_receive_sources(elements, paths)
    _check_serve_distances(elements, paths)
    _check_header_volume(drill.get("coaching_points") or [])
    _check_wall_shot_distance(elements, paths)
    _check_setup_touch_before_shots(elements, paths)


def _check_wall_shot_distance(
    elements: list[dict[str, Any]], paths: list[dict[str, Any]]
) -> None:
    """Serving a wall from point-blank looks fake — give the rebound room.
    Applies to shots AND throws (the complaint reads the same either way)."""
    by_label = {e.get("label"): e for e in elements}
    for p in paths:
        if p.get("alt") or p.get("style") not in ("shoot", "shot", "throw"):
            continue
        if by_label.get(p.get("to"), {}).get("type") != "wall":
            continue
        fx, fy, tx, ty = p.get("fx"), p.get("fy"), p.get("tx"), p.get("ty")
        if None in (fx, fy, tx, ty):
            continue
        if ((fx - tx) ** 2 + (fy - ty) ** 2) ** 0.5 < 5.0:
            raise ValidationError(
                f"step {p.get('step')}: serving a wall from under 5m is "
                "unrealistic — move the server back so the rebound has room"
            )


def _check_setup_touch_before_shots(
    elements: list[dict[str, Any]], paths: list[dict[str, Any]]
) -> None:
    """Never shoot from on top of the approach: a strike at a goal/gate needs
    a short setup touch (≤4m dribble by the shooter) right before it — 'a
    sudden touch inside towards the left or right and finish'. First-time
    finishes off a pass/receive are exempt (that IS the touch).
    """
    if not any(e.get("type") == "goal" for e in elements):
        return  # finishing context only
    by_label = {e.get("label"): e for e in elements}
    ordered = [p for p in sorted(paths, key=lambda x: x.get("step", 0))
               if not p.get("alt")]
    for i, p in enumerate(ordered):
        if p.get("style") not in ("shoot", "shot"):
            continue
        if by_label.get(p.get("to"), {}).get("type") not in ("goal", "gate"):
            continue
        prev = ordered[i - 1] if i else None
        if prev is None:
            continue
        if prev.get("style") in ("pass", "receive", "toss", "throw"):
            continue  # first-time finish off a feed
        if prev.get("style") == "dribble" and by_label.get(prev.get("to"), {}) \
                .get("type") in ("player", "defender", "mannequin"):
            continue  # beat the man, then strike — the duel IS the setup
        if prev.get("style") == "dribble" and prev.get("from") == p.get("from"):
            fx, fy = prev.get("fx"), prev.get("fy")
            tx, ty = prev.get("tx"), prev.get("ty")
            if None in (fx, fy, tx, ty):
                continue  # no baked coords to measure (pre-annotate input)
            # 5.5m baked = a ≤4m cut + the ~1m marker overshoot the
            # post-processor adds; real approaches run 12m+.
            if ((fx - tx) ** 2 + (fy - ty) ** 2) ** 0.5 <= 5.5:
                continue  # short cut before the strike — the setup touch
        raise ValidationError(
            f"step {p.get('step')}: {p.get('from')} shoots straight off the "
            "approach — declare a touch cone 2-3m goal-side of the approach "
            "cone and add the cut: `dribbles to <approach>` then `dribbles to "
            "<touch cone>` (≤4m), THEN the shot"
        )


def _check_at_least_one_step(paths: list[dict[str, Any]]) -> None:
    if not paths:
        raise ValidationError("drill must have at least one action step")


def _check_step_numbers_contiguous(paths: list[dict[str, Any]]) -> None:
    nums = sorted(p.get("step", 0) for p in paths if not p.get("alt"))
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
    elements: list[dict[str, Any]], paths: list[dict[str, Any]],
    is_duel: bool = False,
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
        if p.get("alt"):
            continue  # hypothetical branch — no possession effect
        step, style = p.get("step"), p.get("style")
        src, dst = p.get("from"), p.get("to")
        needs_ball = style in ("pass", "dribble", "shoot", "shot", "throw", "toss", "header")

        if needs_ball and holder != src:
            # Acquisition on the move: standing on / moving through a ball spot.
            src_el, got = by_label.get(src), False
            if src_el is not None:
                # A server's staged stack is "beside them" by convention; the
                # post-processor's de-overlap can spread a tight cluster past
                # arm's reach, so servers get a stack radius. Workers must
                # still physically run to a ball.
                reach = 6.0 if src_el.get("role") == "server" else 3.0
                for bl in list(unclaimed):
                    if near(src_el, by_label[bl], reach):
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
            pass  # ball travels with the dribbler; handover needs "receives from"
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
            if holder == src:
                raise ValidationError(
                    f"step {step}: {src} runs while carrying the ball — a kid "
                    "reads 'runs to' as leaving the ball behind; use "
                    "'dribbles to' when the carrier moves"
                )
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
        if p.get("alt"):
            continue
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
    # Only the generator's context-aware flag decides duel-ness; a passive
    # defender obstacle (chip-over, shield-from) may appear in scripted drills.
    if is_duel and sum(1 for p in paths if not p.get("alt")) > 3:
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


BALL_ACTION_STYLES: set[str] = {"pass", "dribble", "shoot", "shot", "header", "toss", "throw"}


def _check_gates_played_through(
    elements: list[dict[str, Any]], paths: list[dict[str, Any]],
    is_duel: bool = False,
) -> None:
    """Every declared gate must have a ball routed INTO it by some step.

    Holdout review found the dominant novel failure: gates placed and named
    in the countable target ("8 of 10 through the gate") while no ball path
    ever ends there — the scored action is never depicted. Duels are exempt:
    their gates are live alternatives, only one branch is illustrated.
    """
    if is_duel:
        return
    by_label = {e.get("label"): e for e in elements}
    gates = [e for e in elements if e.get("type") == "gate"]
    if not gates:
        return
    played = {p.get("to") for p in paths if p.get("style") in BALL_ACTION_STYLES}

    def _seg_dist(a, b, c):
        ax, ay, bx, by, cx, cy = a["x"], a["y"], b["x"], b["y"], c["x"], c["y"]
        dx, dy = bx - ax, by - ay
        L2 = dx * dx + dy * dy
        if L2 == 0:
            return ((ax - cx) ** 2 + (ay - cy) ** 2) ** 0.5
        t = max(0.0, min(1.0, ((cx - ax) * dx + (cy - ay) * dy) / L2))
        px, py = ax + t * dx, ay + t * dy
        return ((px - cx) ** 2 + (py - cy) ** 2) ** 0.5

    for gate in gates:
        g = gate.get("label")
        if g in played:
            continue
        # Lane gate: a pass whose flight line crosses the gate counts as
        # playing it (gate BETWEEN passer and receiver — the standard
        # passing-accuracy pattern).
        gw = float(gate.get("width") or 1.5)
        crossed = False
        for p in paths:
            if p.get("style") not in ("pass", "throw", "toss"):
                continue
            # Judge the flight on baked step positions (players move) —
            # spawn coordinates lie about where the pass actually travels.
            if p.get("fx") is not None:
                a = {"x": p["fx"], "y": p["fy"]}
                b = {"x": p["tx"], "y": p["ty"]}
            else:
                a, b = by_label.get(p.get("from")), by_label.get(p.get("to"))
            if a and b and _seg_dist(a, b, gate) <= max(1.5, gw / 2 + 0.5):
                crossed = True
                break
        if not crossed:
            raise ValidationError(
                f"gate {g!r} is never played through — either route a rep "
                "into it (pass/shoot/dribble/head TO the gate label, or land a "
                "chip in it) or place it ON a passing lane so a pass crosses "
                "it; a scored target the ball never visits is decoration"
            )


def _check_single_ball(elements: list[dict[str, Any]]) -> None:
    """Exactly one drawn ball. Multiple ball glyphs confused reviewers and
    made animations ambiguous; supply belongs in coaching text."""
    balls = [e for e in elements if e.get("type") == "ball"]
    if len(balls) > 1:
        labels = [b.get("label") for b in balls]
        raise ValidationError(
            f"declare exactly ONE ball element (got {len(balls)}: {labels}); "
            "mention a supply stack in a coaching point instead, and script "
            "the collect-and-return between reps"
        )


def _check_duel_shape(
    elements: list[dict[str, Any]], paths: list[dict[str, Any]],
    is_duel: bool = False,
) -> None:
    """Duels illustrate an ENGAGEMENT: the drive goes AT the opponent.

    Review found a 'duel' whose attacker dribbled 14m to a decorative cone
    while both players converged on it. Rules: no cones in duels; the first
    scripted action is a dribble at the other player from a realistic
    engage distance (2-8m); any other dribble targets a gate.
    """
    if not is_duel:
        return
    n_players = sum(1 for e in elements if e.get("type") == "player")
    if n_players != 2:
        return  # rondos/pressing groups share the live-gates exemption only
    if any(e.get("type") == "cone" for e in elements):
        raise ValidationError(
            "duels use no cones — only the two players, one ball, and the "
            "target gates; remove the cones"
        )
    # The defender must actually defend: positioned between the attacker
    # and the gates at kickoff.
    gates = [e for e in elements if e.get("type") == "gate"]
    players = [e for e in elements if e.get("type") == "player"]
    balls = [e for e in elements if e.get("type") == "ball"]
    if gates and len(players) == 2 and balls:
        b = balls[0]
        att = min(players, key=lambda pl: (pl["x"] - b["x"]) ** 2 + (pl["y"] - b["y"]) ** 2)
        dfd = players[0] if players[1] is att else players[1]
        gx = sum(g["x"] for g in gates) / len(gates)
        gy = sum(g["y"] for g in gates) / len(gates)
        vx, vy = gx - att["x"], gy - att["y"]
        wx, wy = dfd["x"] - att["x"], dfd["y"] - att["y"]
        along = (vx * wx + vy * wy)
        gate_d2 = vx * vx + vy * vy
        if along <= 0 or along >= gate_d2:
            raise ValidationError(
                f"the defender ({dfd.get('label')}) must start BETWEEN the "
                f"attacker and the gates — that is what defending means; "
                "place them on the line from attacker to gates"
            )
    by_label = {e.get("label"): e for e in elements}
    ordered = sorted(paths, key=lambda x: x.get("step", 0))
    if ordered:
        first = ordered[0]
        tgt = by_label.get(first.get("to"), {})
        if first.get("style") != "dribble" or tgt.get("type") != "player":
            raise ValidationError(
                "a duel's first step must be the attacker dribbling AT the "
                "other player (the engage) — not to a cone, gate, or a run"
            )
        fx, fy, tx, ty = (first.get("fx"), first.get("fy"),
                          first.get("tx"), first.get("ty"))
        if None not in (fx, fy, tx, ty):
            d = ((fx - tx) ** 2 + (fy - ty) ** 2) ** 0.5
            if not (2.0 <= d <= 8.0):
                raise ValidationError(
                    f"duel engage distance is {d:.1f}m — start the attacker "
                    "2-8m from the defender so the drive is a real duel"
                )
    for p in ordered[1:]:
        if p.get("style") == "dribble"            and by_label.get(p.get("to"), {}).get("type") not in ("gate", "player"):
            raise ValidationError(
                "in a duel, dribbles go AT the opponent or THROUGH a gate — "
                f"step {p.get('step')} dribbles to a "
                f"{by_label.get(p.get('to'), {}).get('type')}"
            )


def _check_no_coords_in_coaching(coaching_points: list) -> None:
    """Coaching points are for kids — never leak raw coordinates."""
    import re as _re
    for cp in coaching_points:
        if _re.search(r"\(\s*\d+(?:\.\d+)?\s*,\s*\d+(?:\.\d+)?\s*\)", str(cp)):
            raise ValidationError(
                "coaching points must not contain raw coordinates like "
                "(5, 7.5) — describe positions in soccer language"
            )


def _check_no_zero_length_ball_actions(paths: list[dict[str, Any]]) -> None:
    """A pass/shot/toss of ~0 meters is a nonsense step (co-located actors)."""
    for p in paths:
        if p.get("alt") or p.get("style") not in ("pass", "shoot", "shot", "toss", "throw", "header"):
            continue
        if p.get("style") == "toss" and p.get("to") == p.get("from"):
            continue  # self-toss goes UP, not across — zero ground distance is the point
        fx, fy, tx, ty = p.get("fx"), p.get("fy"), p.get("tx"), p.get("ty")
        if None in (fx, fy, tx, ty):
            continue
        if ((fx - tx) ** 2 + (fy - ty) ** 2) ** 0.5 < 1.0:
            raise ValidationError(
                f"step {p.get('step')}: a {p.get('style')} of under 1m is a "
                "nonsense action — separate the players or drop the step"
            )


def _check_solo_pass_targets(
    elements: list[dict[str, Any]], paths: list[dict[str, Any]]
) -> None:
    """Solo drills: a pass needs a target that makes sense alone.

    User review: solo drills passing at cones ("no one is there") are
    unusable. With one player a pass goes against a wall (plays it back)
    or through a gate (a window you play through, then collect — the
    user's own 4-gate first-touch spec). Cones/mannequins are not
    receivers; shots/headers at targets are still fine.
    """
    players = [e for e in elements if e.get("type") == "player"]
    if len(players) != 1:
        return
    by_label = {e.get("label"): e for e in elements}
    for p in paths:
        if p.get("style") not in ("pass", "toss", "throw") or p.get("alt"):
            continue
        if p.get("to") == p.get("from"):
            continue  # self-toss is a legitimate solo serve
        tgt = by_label.get(p.get("to"), {}).get("type")
        if tgt not in ("wall", "gate"):
            raise ValidationError(
                f"step {p.get('step')}: solo drill passes to a {tgt} — "
                "nobody is there to receive it; solo passes go against a "
                "wall or through a gate (or redesign as dribble/shot reps)"
            )


def _check_receive_sources(
    elements: list[dict[str, Any]], paths: list[dict[str, Any]]
) -> None:
    """'X receives from Y': Y must be able to deliver — a ball can't pass itself."""
    by_label = {e.get("label"): e for e in elements}
    for p in paths:
        if p.get("style") != "receive":
            continue
        src = p.get("to")
        src_type = by_label.get(src, {}).get("type")
        if src_type not in ("player", "wall") and src != p.get("from"):
            raise ValidationError(
                f"step {p.get('step')}: receives from a {src_type} — the ball "
                "cannot pass itself; receive from a player or a wall rebound"
            )
