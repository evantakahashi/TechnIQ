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
