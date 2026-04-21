"""Exemplar loader. exemplars.json is read once at import time."""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

_EXEMPLARS_PATH = Path(__file__).with_name("exemplars.json")

with _EXEMPLARS_PATH.open("r", encoding="utf-8") as _f:
    EXEMPLARS: list[dict[str, Any]] = json.load(_f)


def get_exemplars(archetype: str, n: int = 3) -> list[dict[str, Any]]:
    """Return up to n exemplars matching archetype."""
    return [e for e in EXEMPLARS if e["archetype"] == archetype][:n]
