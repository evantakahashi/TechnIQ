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

    _check_at_least_one_step(paths)
    _check_step_numbers_contiguous(paths)
    _check_step_targets_exist(elements, paths)
    _check_equipment_consistency(elements, equipment)
    _check_at_least_one_worker(elements)


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
