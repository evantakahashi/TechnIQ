"""Coaching-quality validator. Runs after DSL + structural validation."""
from __future__ import annotations

import re
from typing import Any

# Short phrases that add no coaching value on their own.
GENERIC_COACHING_BLACKLIST: frozenset[str] = frozenset({
    "work hard", "give 100%", "give 100 percent", "do your best",
    "try your best", "good effort", "focus up", "concentrate",
    "stay alert", "have fun", "keep going", "you got this",
})

# Verbs that mark a coaching point as football-specific (for generic realism floor).
_FOOTBALL_VERBS: frozenset[str] = frozenset({
    "receive", "pass", "shoot", "dribble", "defend", "turn", "close",
    "press", "scan", "switch", "cushion", "strike", "curl", "drive",
    "cut", "feint", "block", "tackle", "intercept", "recover",
    "accelerate", "sprint", "burst", "finish", "jockey", "carry",
})

# Stopwords to strip when mining keywords from success_metric for C3.
_STOPWORDS: frozenset[str] = frozenset({
    "the", "and", "for", "with", "from", "into", "onto", "within",
    "each", "all", "any", "some", "that", "this", "these", "those",
    "than", "then", "their", "they", "have", "been", "being",
})


def score_drill_quality(
    drill: dict[str, Any],
    rule_pack: dict[str, Any] | None,
    level: str,
) -> tuple[int, list[str]]:
    """Return (checks_passed, reasons_for_failures). Max score = 4.

    Threshold: score >= 3. Additionally, for level != 'beginner', C2 is
    mandatory (caller should reject if C2 fails even when score >= 3).
    Caller enforces the mandatory-C2 rule via the reasons list.
    """
    reasons: list[str] = []

    elements: list[dict[str, Any]] = drill.get("diagram", {}).get("elements", [])
    paths:    list[dict[str, Any]] = drill.get("diagram", {}).get("paths", [])
    coaching: list[str]            = drill.get("coaching_points", [])

    c1_ok = _c1_forces_primary_action(drill, rule_pack, level)
    c2_ok = _c2_structural_realism(elements, paths, coaching, level)
    c3_ok = _c3_coaching_points_on_target(coaching, rule_pack, level)
    c4_ok = _c4_rep_density(paths)

    if not c1_ok:
        reasons.append("C1: drill does not surface the primary action (no verb_keyword in steps or coaching)")
    if not c2_ok:
        reasons.append("C2: structural realism failed (need ≥2 players, outcome object, pressure source, and repeating element)")
    if not c3_ok:
        reasons.append("C3: coaching points too thin or off-target (need ≥2, ≥1 on-skill or non-generic)")
    if not c4_ok:
        reasons.append("C4: not enough reps (need ≥5 steps OR one element appearing on ≥3 path endpoints)")

    score = sum((c1_ok, c2_ok, c3_ok, c4_ok))
    return score, reasons


# ---- check predicates ----

def _c1_forces_primary_action(
    drill: dict[str, Any],
    rule_pack: dict[str, Any] | None,
    level: str,
) -> bool:
    if rule_pack is None:
        return True
    keywords = [k.lower() for k in rule_pack.get("verb_keywords", [])]
    if not keywords:
        return True
    haystack_parts: list[str] = []
    for p in drill.get("diagram", {}).get("paths", []):
        haystack_parts.append(str(p.get("style", "")).lower())
    for cp in drill.get("coaching_points", []):
        haystack_parts.append(str(cp).lower())
    haystack = " ".join(haystack_parts)
    return any(k in haystack for k in keywords)


def _c2_structural_realism(
    elements: list[dict[str, Any]],
    paths: list[dict[str, Any]],
    coaching: list[str],
    level: str,
) -> bool:
    if level == "beginner":
        return True

    player_roles = [
        e.get("role", "") for e in elements
        if e.get("type") == "player" and e.get("role") in {"worker", "server", "defender"}
    ]
    if len(player_roles) < 2:
        return False

    has_outcome_element = any(e.get("type") in {"goal", "gate"} for e in elements)
    outcome_terms_in_cp = any(
        any(term in cp.lower() for term in ("line", "gate", "goal", "zone"))
        for cp in coaching
    )
    if not (has_outcome_element or outcome_terms_in_cp):
        return False

    has_defender = any(
        e.get("type") == "player" and e.get("role") == "defender" for e in elements
    )
    server_labels = {
        lbl for e in elements
        if e.get("type") == "player" and e.get("role") == "server"
        and (lbl := e.get("label")) is not None
    }
    server_step_counts: dict[str, set[int]] = {sl: set() for sl in server_labels}
    for p in paths:
        step = p.get("step")
        if step is None:
            continue
        for key in ("from", "to"):
            lbl = p.get(key)
            if lbl in server_labels:
                server_step_counts[lbl].add(step)
    server_active = any(len(s) >= 2 for s in server_step_counts.values())
    if not (has_defender or server_active):
        return False

    el_step_counts: dict[str, set[int]] = {}
    for p in paths:
        step = p.get("step")
        if step is None:
            continue
        for key in ("from", "to"):
            lbl = p.get(key)
            if lbl:
                el_step_counts.setdefault(lbl, set()).add(step)
    if not any(len(s) >= 2 for s in el_step_counts.values()):
        return False

    return True


def _c3_coaching_points_on_target(
    coaching: list[str],
    rule_pack: dict[str, Any] | None,
    level: str,
) -> bool:
    if len(coaching) < 2:
        return False

    if rule_pack is None:
        if level == "beginner":
            return True
        return any(_is_non_generic(cp) for cp in coaching)

    keywords = {k.lower() for k in rule_pack.get("verb_keywords", [])}
    metric_words = _significant_words(rule_pack.get("success_metric", ""))

    joined = " ".join(cp.lower() for cp in coaching)
    if any(k in joined for k in keywords):
        return True
    if any(w in joined for w in metric_words):
        return True
    return False


def _c4_rep_density(paths: list[dict[str, Any]]) -> bool:
    if len(paths) >= 5:
        return True
    el_counts: dict[str, int] = {}
    for p in paths:
        for key in ("from", "to"):
            lbl = p.get(key)
            if lbl:
                el_counts[lbl] = el_counts.get(lbl, 0) + 1
    return any(c >= 3 for c in el_counts.values())


# ---- helpers ----

def _is_non_generic(point: str) -> bool:
    lower = point.lower().strip()
    if any(phrase in lower for phrase in GENERIC_COACHING_BLACKLIST):
        return False
    words = set(re.findall(r"[a-z]+", lower))
    return bool(words & _FOOTBALL_VERBS)


def _significant_words(text: str) -> set[str]:
    words = re.findall(r"[a-z]+", (text or "").lower())
    return {w for w in words if len(w) >= 5 and w not in _STOPWORDS}
