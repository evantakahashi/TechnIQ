"""On-demand regression eval (the grill decisions: on-demand command; any
golden regression blocks deploy).

For every case in golden/labels.json:
  - regenerate through the live pipeline (same code path as production)
  - validators must pass (generation succeeding at all is gate #1)
  - geometry rubric must not drop >5 points below the recorded score
Golden-labeled cases failing EITHER check exit non-zero -> do not deploy.

Usage: cd functions && ./venv/bin/python eval/run_eval.py [--only case-id]
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import yaml  # noqa: E402
from anthropic import Anthropic  # noqa: E402
from drill_generator import generate_drill  # noqa: E402
from eval.rubric import score_geometry  # noqa: E402

ROOT = Path(__file__).resolve().parent
LABELS = json.load(open(ROOT / "golden" / "labels.json"))

with open(Path(__file__).resolve().parent.parent / ".env.yaml") as f:
    KEY = yaml.safe_load(f)["ANTHROPIC_API_KEY"]
client = Anthropic(api_key=KEY)


def llm(prompt: str) -> str:
    r = client.messages.create(model="claude-opus-4-8", max_tokens=1600,
                               messages=[{"role": "user", "content": prompt}])
    return r.content[0].text


def main() -> None:
    only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else None
    failures = []
    for case in LABELS["cases"]:
        cid = case["id"]
        if only and cid != only:
            continue
        try:
            drill = generate_drill(dict(case["request"]), llm)
        except Exception as e:  # noqa: BLE001
            status = "GENERATION FAILED"
            print(f"{cid:<18} {status}: {str(e)[:90]}")
            if case.get("verdict") == "golden":
                failures.append((cid, status))
            continue
        _, score = score_geometry(drill)
        floor = case.get("rubric_floor", 0)
        ok = score >= floor - 5
        print(f"{cid:<18} rubric {score:>3} (floor {floor}) {'OK' if ok else 'REGRESSION'}")
        if case.get("verdict") == "golden" and not ok:
            failures.append((cid, f"rubric {score} < floor {floor}-5"))
    if failures:
        print(f"\nBLOCK DEPLOY — golden regressions: {failures}")
        sys.exit(1)
    print("\nAll golden gates passed.")


if __name__ == "__main__":
    main()
