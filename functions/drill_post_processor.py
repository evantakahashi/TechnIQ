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
VALID_PASS_TARGETS = {"player", "server", "defender", "wall", "goal"}

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
    """
    warnings: List[str] = []
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
    elements = _resolve_overlaps(elements, width, length)

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


def _resolve_overlaps(elements: List[Dict], width: float, length: float) -> List[Dict]:
    """Nudge overlapping elements apart until all have >= MIN_SPACING."""
    max_iterations = 50
    for _ in range(max_iterations):
        moved = False
        for i in range(len(elements)):
            for j in range(i + 1, len(elements)):
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
    return elements


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

        # Check pass targets
        if path.get("style") == "pass":
            target_type = label_to_type.get(to_label, "")
            if target_type not in VALID_PASS_TARGETS:
                warnings.append(
                    f"Invalid pass target: pass to {target_type} '{to_label}' — "
                    f"passes can only target player, server, defender, wall, or goal"
                )

        valid_paths.append(path)

    # Check step-instruction alignment
    steps_with_paths = {p.get("step") for p in valid_paths if p.get("step") is not None}
    for i in range(1, len(instructions) + 1):
        if steps_with_paths and i not in steps_with_paths:
            warnings.append(f"Instruction step {i} has no matching diagram path")

    # Check for orphan steps (path step > number of instructions)
    for path in valid_paths:
        step = path.get("step")
        if step is not None and step > len(instructions):
            warnings.append(f"Path step {step} exceeds instruction count ({len(instructions)})")

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
