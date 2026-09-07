"""Deterministic weakness+level → archetype lookup. Replaces Scout LLM phase."""
from typing import Final

VALID_ARCHETYPES: Final[set[str]] = {
    "cone_weave",
    "wall_passing",
    "gate_dribbling",
    "dribble_and_shoot",
    "server_executor",
    "triangle_passing",
    "1v1_plus_server",
    "rondo",
}

FALLBACK_ARCHETYPE: Final[str] = "cone_weave"

# (weakness_label_from_onboarding, experience_level) -> archetype
ARCHETYPE_TABLE: Final[dict[tuple[str, str], str]] = {
    ("Under Pressure", "beginner"):     "gate_dribbling",
    ("Under Pressure", "intermediate"): "rondo",
    ("Under Pressure", "advanced"):     "rondo",

    ("Finishing", "beginner"):     "dribble_and_shoot",
    ("Finishing", "intermediate"): "dribble_and_shoot",
    ("Finishing", "advanced"):     "1v1_plus_server",

    ("Ball Control", "beginner"):     "cone_weave",
    ("Ball Control", "intermediate"): "gate_dribbling",
    ("Ball Control", "advanced"):     "1v1_plus_server",

    ("Passing", "beginner"):     "wall_passing",
    ("Passing", "intermediate"): "triangle_passing",
    ("Passing", "advanced"):     "rondo",

    ("Dribbling", "beginner"):     "cone_weave",
    ("Dribbling", "intermediate"): "gate_dribbling",
    ("Dribbling", "advanced"):     "1v1_plus_server",

    ("Speed", "beginner"):     "cone_weave",
    ("Speed", "intermediate"): "server_executor",
    ("Speed", "advanced"):     "server_executor",

    ("Crossing", "beginner"):     "server_executor",
    ("Crossing", "intermediate"): "server_executor",
    ("Crossing", "advanced"):     "server_executor",

    ("First Touch", "beginner"):     "wall_passing",
    ("First Touch", "intermediate"): "wall_passing",
    ("First Touch", "advanced"):     "rondo",

    ("Shooting", "beginner"):     "dribble_and_shoot",
    ("Shooting", "intermediate"): "dribble_and_shoot",
    ("Shooting", "advanced"):     "1v1_plus_server",
}


# Real labels drift from table keys ("Shooting Accuracy", "Weak Foot", "Quick
# Feet"...). Exact tuple lookup sent finishing requests to cone_weave.
_WEAKNESS_ALIASES: Final[dict[str, str]] = {
    "shooting accuracy": "Shooting", "weak foot": "Shooting", "striking": "Shooting",
    "finishing": "Finishing",
    "passing accuracy": "Passing", "one touch": "Passing",
    "dribbling skills": "Dribbling", "close control": "Dribbling",
    "ball control": "Ball Control",
    "first touch": "First Touch", "receiving": "First Touch",
    "speed & agility": "Speed", "quick feet": "Speed", "agility": "Speed",
    "under pressure": "Under Pressure",
    "crossing": "Crossing",
}

# Archetypes that need a partner, remapped for solo (1-player) requests.
_SOLO_REMAP: Final[dict[str, str]] = {
    "1v1_plus_server": "dribble_and_shoot",
    "rondo": "wall_passing",
    "triangle_passing": "wall_passing",
    "server_executor": "dribble_and_shoot",
}


def _canonical_weakness(weakness: str) -> str:
    needle = (weakness or "").strip().lower()
    for alias, name in _WEAKNESS_ALIASES.items():
        if alias == needle or alias in needle:
            return name
    return weakness


def pick_archetype(weakness: str, level: str, number_of_players: int = 2) -> str:
    """Archetype for (weakness, level), alias-tolerant and player-count aware."""
    key = _canonical_weakness(weakness)
    archetype = ARCHETYPE_TABLE.get((key, level), FALLBACK_ARCHETYPE)
    if number_of_players == 1:
        archetype = _SOLO_REMAP.get(archetype, archetype)
    return archetype
