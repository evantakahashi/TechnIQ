"""Exemplar loader + level/pressure filter with neighbor-archetype cascade."""
from __future__ import annotations

import json
import logging
from pathlib import Path
from typing import Any

_EXEMPLARS_PATH = Path(__file__).with_name("exemplars.json")
logger = logging.getLogger(__name__)

with _EXEMPLARS_PATH.open("r", encoding="utf-8") as _f:
    EXEMPLARS: list[dict[str, Any]] = json.load(_f)

# Pressure tiers allowed per level.
_LEVEL_PRESSURE_ALLOW: dict[str, set[str]] = {
    "beginner":     {"none", "passive"},
    "intermediate": {"passive", "active"},
    "advanced":     {"active"},
}

# Neighbor archetypes to try when primary archetype has no matching pressure.
# Order matters: first hit wins.
ARCHETYPE_NEIGHBORS: dict[str, list[str]] = {
    "cone_weave":        ["gate_dribbling", "1v1_plus_server"],
    "wall_passing":      ["triangle_passing", "rondo"],
    "gate_dribbling":    ["1v1_plus_server", "cone_weave"],
    "dribble_and_shoot": ["1v1_plus_server", "server_executor"],
    "server_executor":   ["1v1_plus_server", "rondo"],
    "triangle_passing":  ["rondo", "wall_passing"],
    "1v1_plus_server":   ["rondo", "gate_dribbling"],
    "rondo":             ["1v1_plus_server", "triangle_passing"],
}


def get_exemplars(
    archetype: str,
    level: str | None = None,
    n: int = 3,
) -> list[dict[str, Any]]:
    """Return up to n exemplars matching archetype (and level pressure, if given).

    Cascade when level-filtered primary archetype is empty:
      1. primary archetype + allowed pressures
      2. each neighbor archetype + allowed pressures (first hit wins)
      3. empty list — NO fallback to unfiltered (wrong-pressure) exemplars.
    """
    allowed = _LEVEL_PRESSURE_ALLOW.get(level) if level else None

    def _match(arch: str) -> list[dict[str, Any]]:
        hits = [e for e in EXEMPLARS if e.get("archetype") == arch]
        if allowed is None:
            return hits
        return [e for e in hits if e.get("pressure", "none") in allowed]

    primary = _match(archetype)
    if primary:
        return primary[:n]

    if allowed is None:
        return []  # no level filter and primary has nothing → nothing

    for neighbor in ARCHETYPE_NEIGHBORS.get(archetype, []):
        cascaded = _match(neighbor)
        if cascaded:
            logger.info("[exemplar-cascade] %s (level=%s) → neighbor %s (%d hits)",
                        archetype, level, neighbor, len(cascaded))
            return cascaded[:n]

    logger.info("[exemplar-cascade] %s (level=%s) → empty (no primary, no neighbor)",
                archetype, level)
    return []
