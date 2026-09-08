"""
Deterministic post-processor for AI-generated drill diagrams.
Validates and fixes spatial issues, path consistency, equipment alignment.
Runs after Writer phase, before Referee phase. No LLM calls.
"""
import math
import logging
from typing import Dict, List, Tuple

logger = logging.getLogger(__name__)

# Valid targets for "pass" style paths
VALID_PASS_TARGETS = {"player", "server", "defender", "wall", "goal" , "gate"}

# Equipment → element type mapping
EQUIPMENT_TO_ELEMENT = {
    "ball": {"ball"},
    "cones": {"cone"},
    "goals": {"goal"},
    "wall": {"wall"},
    "partner": {"player", "server", "defender"},
    "hurdles": {"cone"},
    "ladder": {"cone"},
    "poles": {"cone"},
}

MIN_SPACING = 2.0  # meters
BOUNDS_PADDING = 1.0  # meters from edge

# Age group max cone spacing (meters)
AGE_MAX_CONE_SPACING = {
    8: 7,    # U8: max 7m between cones
    12: 10,  # U12: max 10m
    99: 15,  # U13+: max 15m
}

# Coach pattern_type → canonical archetype mapping
PATTERN_TO_ARCHETYPE = {
    "zigzag": "cone_weave",
    "linear": "cone_weave",
    "triangle": "triangle_passing",
    "diamond": "triangle_passing",
    "square": "triangle_passing",
    "wall_pass_sequence": "wall_passing",
    "channel": "server_executor",
    "overlap_run": "server_executor",
    "rondo_circle": "rondo",
    "gates": "gate_dribbling",
    "grid": "gate_dribbling",
    "free": None,  # No snapping for free-form
}

REQUIRED_FIELDS = ["name", "description", "setup", "instructions", "diagram",
                   "difficulty", "category", "targetSkills", "equipment"]


def map_pattern_to_archetype(pattern_type: str) -> str | None:
    """Map Coach phase pattern_type to canonical archetype name."""
    return PATTERN_TO_ARCHETYPE.get(pattern_type)


def post_process_drill(drill: Dict, player_age: int = 14) -> Tuple[Dict, List[str]]:
    """
    Validate and fix a drill's diagram. Returns (fixed_drill, warnings).

    Args:
        drill: The drill dict from the Writer phase
        player_age: Player's age for age-appropriate spacing validation

    Returns:
        Tuple of (fixed_drill_dict, list_of_warning_strings)

    Note: The input drill dict is mutated in place. The returned dict is the same object.
    """
    warnings: List[str] = []

    if not isinstance(player_age, int) or player_age <= 0:
        warnings.append(f"Invalid player_age '{player_age}' — defaulting to 14")
        player_age = 14

    diagram = drill.get("diagram", {})
    field = diagram.get("field", {"width": 20, "length": 15})
    elements = diagram.get("elements", [])
    paths = diagram.get("paths", [])
    equipment = drill.get("equipment", [])
    instructions = drill.get("instructions", [])

    width = field.get("width", 20)
    length = field.get("length", 15)

    # 0. Schema completeness
    schema_warnings = _check_schema(drill)
    warnings.extend(schema_warnings)

    # 1. Bounds clamping
    elements = _clamp_bounds(elements, width, length)

    # 2. Overlap resolution
    elements, overlap_warnings = _resolve_overlaps(elements, width, length)
    warnings.extend(overlap_warnings)

    # 3. Path validation (includes duplicate removal)
    paths, path_warnings = _validate_paths(paths, elements, instructions)
    warnings.extend(path_warnings)

    # 4. Equipment consistency
    equip_warnings = _check_equipment_consistency(equipment, elements)
    warnings.extend(equip_warnings)

    # 5. Age-appropriate spacing
    spacing_warnings = _check_age_spacing(elements, player_age)
    warnings.extend(spacing_warnings)

    # Write back
    drill["diagram"]["elements"] = elements
    drill["diagram"]["paths"] = paths

    return drill, warnings


def _check_schema(drill: Dict) -> List[str]:
    """Check for required top-level fields."""
    warnings = []
    for field in REQUIRED_FIELDS:
        if field not in drill:
            warnings.append(f"Missing required field: {field}")
    return warnings


def _clamp_bounds(elements: List[Dict], width: float, length: float) -> List[Dict]:
    """Clamp all element coordinates within field bounds with padding."""
    for el in elements:
        el["x"] = max(BOUNDS_PADDING, min(el.get("x", 0), width - BOUNDS_PADDING))
        el["y"] = max(BOUNDS_PADDING, min(el.get("y", 0), length - BOUNDS_PADDING))
    return elements


def _resolve_overlaps(elements: List[Dict], width: float, length: float) -> Tuple[List[Dict], List[str]]:
    """Nudge overlapping elements apart until all have >= MIN_SPACING."""
    warnings = []
    max_iterations = 50
    moved = False
    for _ in range(max_iterations):
        moved = False
        for i in range(len(elements)):
            for j in range(i + 1, len(elements)):
                # A ball belongs at a player's feet — never push them apart.
                kinds = {elements[i].get("type"), elements[j].get("type")}
                if kinds == {"ball", "player"}:
                    continue
                dx = elements[j]["x"] - elements[i]["x"]
                dy = elements[j]["y"] - elements[i]["y"]
                dist = math.sqrt(dx * dx + dy * dy)
                if dist < MIN_SPACING:
                    # Nudge apart along the vector between them
                    if dist == 0:
                        dx, dy = 1.0, 0.0
                        dist = 1.0
                    nudge = (MIN_SPACING - dist) / 2 + 0.1
                    nx = (dx / dist) * nudge
                    ny = (dy / dist) * nudge
                    elements[i]["x"] -= nx
                    elements[i]["y"] -= ny
                    elements[j]["x"] += nx
                    elements[j]["y"] += ny
                    # Re-clamp after nudge
                    for el in [elements[i], elements[j]]:
                        el["x"] = max(BOUNDS_PADDING, min(el["x"], width - BOUNDS_PADDING))
                        el["y"] = max(BOUNDS_PADDING, min(el["y"], length - BOUNDS_PADDING))
                    moved = True
        if not moved:
            break
    if moved:
        warnings.append(
            f"Overlap resolution did not converge after {max_iterations} iterations — "
            f"field may be too small for {len(elements)} elements"
        )
    return elements, warnings


def _validate_paths(
    paths: List[Dict], elements: List[Dict], instructions: List[str]
) -> Tuple[List[Dict], List[str]]:
    """Validate paths: references, pass targets, step alignment."""
    warnings = []
    label_set = {el.get("label") for el in elements}
    label_to_type = {el.get("label"): el.get("type") for el in elements}
    valid_paths = []
    seen_paths = set()

    for path in paths:
        # Duplicate removal
        path_key = (path.get("from"), path.get("to"), path.get("style"), path.get("step"))
        if path_key in seen_paths:
            continue
        seen_paths.add(path_key)
        from_label = path.get("from", "")
        to_label = path.get("to", "")

        # Check references exist
        if from_label not in label_set or to_label not in label_set:
            missing = []
            if from_label not in label_set:
                missing.append(from_label)
            if to_label not in label_set:
                missing.append(to_label)
            warnings.append(f"Removed path: label(s) {', '.join(missing)} not found in elements")
            continue

        # Check pass targets — invalid targets are removed
        if path.get("style") == "pass":
            target_type = label_to_type.get(to_label, "")
            if target_type not in VALID_PASS_TARGETS:
                warnings.append(
                    f"Invalid pass target: pass to {target_type} '{to_label}' — "
                    f"passes can only target player, server, defender, wall, goal, or a landing-zone gate"
                )
                continue

        valid_paths.append(path)

    # Renumber paths so step numbers stay contiguous after drops.
    # Preserves un-stepped paths (step=None). Validator requires [1..n].
    stepped = [p for p in valid_paths if p.get("step") is not None]
    stepped.sort(key=lambda p: p["step"])
    for new_step, path in enumerate(stepped, start=1):
        path["step"] = new_step

    # Check step-instruction alignment
    # Un-stepped paths (step=None) show on all steps, so they cover every instruction
    has_unstep_paths = any(p.get("step") is None for p in valid_paths)
    steps_with_paths = {p.get("step") for p in valid_paths if p.get("step") is not None}
    for i in range(1, len(instructions) + 1):
        if steps_with_paths and i not in steps_with_paths and not has_unstep_paths:
            warnings.append(f"Instruction step {i} has no matching diagram path")

    return valid_paths, warnings


def _check_age_spacing(elements: List[Dict], player_age: int) -> List[str]:
    """Warn if cone spacing exceeds age-appropriate maximum."""
    warnings = []
    # Determine max spacing for age
    max_spacing = 15  # default
    for age_limit, spacing in sorted(AGE_MAX_CONE_SPACING.items()):
        if player_age <= age_limit:
            max_spacing = spacing
            break

    cones = [el for el in elements if el.get("type") == "cone"]
    for i in range(len(cones)):
        for j in range(i + 1, len(cones)):
            dx = cones[j]["x"] - cones[i]["x"]
            dy = cones[j]["y"] - cones[i]["y"]
            dist = math.sqrt(dx * dx + dy * dy)
            if dist > max_spacing:
                warnings.append(
                    f"Cone spacing {dist:.1f}m between '{cones[i].get('label')}' and "
                    f"'{cones[j].get('label')}' exceeds {max_spacing}m max for age {player_age}"
                )
    return warnings


def _check_equipment_consistency(equipment: List[str], elements: List[Dict]) -> List[str]:
    """Check that every equipment item has a corresponding diagram element."""
    warnings = []
    element_types = {el.get("type") for el in elements}

    for item in equipment:
        if item == "none":
            continue
        expected_types = EQUIPMENT_TO_ELEMENT.get(item)
        if expected_types is None:
            continue  # Unknown equipment, skip
        if not expected_types.intersection(element_types):
            warnings.append(f"Equipment '{item}' missing from diagram — no {'/'.join(expected_types)} element found")

    return warnings


def ordered_for_reset(paths):
    return sorted(paths, key=lambda x: (x.get("step", 0), bool(x.get("alt"))))


def annotate_path_positions(drill: dict) -> None:
    """Bake real per-step coordinates onto each path (fx/fy/tx/ty).

    Labels alone lie once players move: "P1 shoots at G1" after "P1 dribbles
    to C1" happens FROM C1, but naive renderers draw from P1's spawn point.
    Simulate the sequence once here so every client just draws the numbers.
    """
    diagram = drill.get("diagram") or {}
    elements = diagram.get("elements") or []
    paths = diagram.get("paths") or []
    pos: dict = {}
    for e in elements:
        try:
            pos[e.get("label")] = {"x": float(e["x"]), "y": float(e["y"]),
                                   "player": e.get("type") == "player"}
        except (KeyError, TypeError, ValueError):
            continue
    for p in sorted(paths, key=lambda x: x.get("step", 0)):
        src, dst = pos.get(p.get("from")), pos.get(p.get("to"))
        if not src or not dst:
            continue
        p["fx"], p["fy"] = round(src["x"], 2), round(src["y"], 2)
        p["tx"], p["ty"] = round(dst["x"], 2), round(dst["y"], 2)
        # Movement relocates the mover; ball flights leave positions
        # unchanged. Alt branches are hypothetical — they never relocate.
        if p.get("alt"):
            continue
        if p.get("style") in ("run", "dribble") and src.get("player"):
            src["x"], src["y"] = dst["x"], dst["y"]

    # Reset tagging: collect/return legs exist for ball logic but are not
    # part of the practiced action — renderers hide them behind a fade.
    by_label = {e.get("label"): e for e in elements}
    ball_labels = {e.get("label") for e in elements if e.get("type") == "ball"}
    rest_at = None
    prev_reset = False
    for p in ordered_for_reset(paths):
        style, src, dst = p.get("style"), p.get("from"), p.get("to")
        dst_type = by_label.get(dst, {}).get("type")
        is_reset = False
        if style == "run" and (dst in ball_labels or dst == rest_at
                               or dst_type in ("goal", "gate") and dst == rest_at):
            is_reset = True
        elif style == "dribble" and prev_reset and dst_type == "player":
            is_reset = True  # return leg after collecting
        elif style == "dribble" and dst in ball_labels:
            is_reset = True  # dribble back to the start marker
        elif style == "receive" and prev_reset:
            is_reset = True  # handover completing the return
        if is_reset:
            p["reset"] = True
        prev_reset = is_reset
        if style in ("shoot", "shot") or (
                style in ("pass", "toss", "throw", "header")
                and dst_type in ("goal", "gate")):
            rest_at = dst
        elif is_reset and style == "run":
            rest_at = None

    # Concurrency: a run by a DIFFERENT actor that closes on the previous
    # step's actor or target plays simultaneously (duels: defender closes
    # while the attacker drives). Renderers animate sync steps together.
    ordered = sorted(paths, key=lambda x: x.get("step", 0))
    for i in range(1, len(ordered)):
        prev, cur = ordered[i - 1], ordered[i]
        if (cur.get("style") == "run"
                and cur.get("from") != prev.get("from")
                and cur.get("to") in (prev.get("from"), prev.get("to"))):
            cur["sync"] = True
        # Timed delivery: a pass/toss to a player whose previous step was that
        # player's run plays concurrently — the ball arrives as the run
        # completes (a cross met by the finisher's run, a through-ball).
        if (cur.get("style") in ("pass", "toss", "throw")
                and prev.get("style") == "run"
                and cur.get("to") == prev.get("from")
                and not prev.get("reset")):
            cur["sync"] = True


def crop_field_to_content(drill: Dict, margin: float = 8.0,
                          min_w: float = 15.0, min_l: float = 12.0) -> None:
    """Shrink an oversized field to the drill's content plus a margin.

    User review: tiny drills were staged on huge pitches ("a ton of green
    grass"). Crop toward the content bbox; if a goal sits on an original
    edge, crop TO that edge so it stays a goal-line goal.
    """
    diagram = drill.get("diagram") or {}
    field = diagram.get("field") or {}
    elements = diagram.get("elements") or []
    if not elements:
        return
    try:
        W, L = float(field["width"]), float(field["length"])
        xs = [float(e["x"]) for e in elements]
        ys = [float(e["y"]) for e in elements]
    except (KeyError, TypeError, ValueError):
        return
    goal_edges = set()
    for e in elements:
        if e.get("type") != "goal":
            continue
        gx, gy = float(e["x"]), float(e["y"])
        if gx <= 2.5: goal_edges.add("x0")
        if W - gx <= 2.5: goal_edges.add("x1")
        if gy <= 2.5: goal_edges.add("y0")
        if L - gy <= 2.5: goal_edges.add("y1")
    x0 = 0.0 if "x0" in goal_edges else max(0.0, min(xs) - margin)
    x1 = W if "x1" in goal_edges else min(W, max(xs) + margin)
    y0 = 0.0 if "y0" in goal_edges else max(0.0, min(ys) - margin)
    y1 = L if "y1" in goal_edges else min(L, max(ys) + margin)
    new_w, new_l = max(min_w, x1 - x0), max(min_l, y1 - y0)
    if new_w >= W - 1 and new_l >= L - 1:
        return  # nothing meaningful to crop
    x0 = min(x0, W - new_w); y0 = min(y0, L - new_l)
    for e in elements:
        e["x"] = round(float(e["x"]) - x0, 2)
        e["y"] = round(float(e["y"]) - y0, 2)
    field["width"] = round(new_w, 1)
    field["length"] = round(new_l, 1)
