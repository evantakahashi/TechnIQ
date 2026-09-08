"""Convert a user-rated GOLDEN drill JSON back into a DSL exemplar.

This closes the learning loop: drills Evan rates golden become few-shot
examples the prompt shows the model. Frozen + additive per the governance
decision — goldens never change, new ones only add.

Usage: ./venv/bin/python eval/golden_to_exemplar.py <drill.json> <archetype> <pressure>
"""
import json
import sys
from pathlib import Path

STYLE_TO_VERB = {
    "pass": "passes to", "dribble": "dribbles to", "run": "runs to",
    "shoot": "shoots at", "shot": "shoots at", "receive": "receives from",
    "throw": "throws to", "toss": "tosses to", "header": "heads to",
}
TOUCH_WORD = {1: "one-touch", 2: "two-touch"}


def drill_to_dsl(drill: dict) -> str:
    lines = []
    for e in drill["diagram"]["elements"]:
        kind = e["type"]
        base = f'{kind} {e["label"]} at ({round(e["x"], 1)}, {round(e["y"], 1)})'
        if e.get("width"):
            base += f' width {e["width"]}'
        if kind == "player" and e.get("role"):
            base += f' role "{e["role"]}"'
        if e.get("display_label"):
            base += f' label "{e["display_label"]}"'
        lines.append(base)
    n = 0
    for p in sorted(drill["diagram"]["paths"], key=lambda x: (x.get("step", 0), bool(x.get("alt")))):
        verb = STYLE_TO_VERB.get(p["style"], "runs to")
        suffix = f' {TOUCH_WORD[p["touches"]]}' if p.get("touches") in TOUCH_WORD else ""
        if p.get("alt"):
            lines.append(f'or: {p["from"]} {verb} {p["to"]}{suffix}')
        else:
            n += 1
            lines.append(f'step {n}: {p["from"]} {verb} {p["to"]}{suffix}')
    for c in drill.get("coaching_points") or drill.get("coachingPoints") or []:
        lines.append(f"point: {c}")
    for v in drill.get("variations") or []:
        text = v if isinstance(v, str) else v.get("description") or v.get("name")
        if text:
            lines.append(f"variation: {text}")
    return "\n".join(lines)


def main() -> None:
    drill_path, archetype, pressure = sys.argv[1], sys.argv[2], sys.argv[3]
    drill = json.load(open(drill_path))
    case = drill.get("_case") or {}
    exemplar = {
        "id": f"golden_{case.get('id', Path(drill_path).stem)}",
        "archetype": archetype,
        "pressure": pressure,
        "golden": True,
        "dsl": drill_to_dsl(drill),
        "notes": f"USER-RATED GOLDEN ({case.get('id')}). Frozen exemplar from the golden set.",
    }
    corpus_path = Path(__file__).resolve().parent.parent / "exemplars.json"
    corpus = json.load(open(corpus_path))
    if any(e["id"] == exemplar["id"] for e in corpus):
        print(f"{exemplar['id']} already in corpus — goldens are frozen, skipping")
        return
    corpus.append(exemplar)
    json.dump(corpus, open(corpus_path, "w"), indent=1)
    print(f"added {exemplar['id']} ({archetype}/{pressure}) to exemplars.json")


if __name__ == "__main__":
    main()
