"""Deterministic weakness+level → archetype lookup. Replaces Scout LLM phase."""
from typing import Final

VALID_ARCHETYPES: Final[set[str]] = {
    "cone_weave",
    "wall_passing",
    "gate_dribbling",
    "dribble_and_shoot",
    "relay_shuttle",
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

    ("Speed", "beginner"):     "relay_shuttle",
    ("Speed", "intermediate"): "relay_shuttle",
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


def pick_archetype(weakness: str, level: str) -> str:
    """Return archetype for (weakness, level) or FALLBACK_ARCHETYPE if unknown."""
    return ARCHETYPE_TABLE.get((weakness, level), FALLBACK_ARCHETYPE)
