"""Local CLI for iterating on drill generation without deploying to Firebase.

Usage (from functions/):
    python -m tools.try_drill --skill "improve first touch under pressure"
    python -m tools.try_drill --weakness "Finishing" --level intermediate --render
    python -m tools.try_drill --skill "weak-foot volleys" --selected "Shooting:Volleys" --render

Reads ANTHROPIC_API_KEY from functions/.env.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

# Make `functions/` importable when run via `python -m tools.try_drill`
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from dotenv import load_dotenv  # noqa: E402
import os  # noqa: E402

from drill_generator import generate_drill, DrillGenerationFailed  # noqa: E402


def _parse_selected(raw: str | None) -> list[dict[str, str]]:
    if not raw:
        return []
    out = []
    for part in raw.split(","):
        part = part.strip()
        if not part:
            continue
        if ":" in part:
            cat, spec = part.split(":", 1)
            out.append({"category": cat.strip(), "specific": spec.strip()})
        else:
            out.append({"category": part, "specific": part})
    return out


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--skill", default="", help="Free-text skill description (takes priority)")
    p.add_argument("--weakness", default="Ball Control",
                   help="Weakness label for archetype lookup (e.g., Finishing, First Touch)")
    p.add_argument("--selected", default="",
                   help="Comma-separated Category:Specific pairs, e.g. 'Shooting:Volleys,First Touch:Bouncing balls'")
    p.add_argument("--level", default="intermediate",
                   choices=["beginner", "intermediate", "advanced"])
    p.add_argument("--age", type=int, default=14)
    p.add_argument("--position", default="midfielder")
    p.add_argument("--equipment", default="ball,cones,goals,partner")
    p.add_argument("--model", default="claude-sonnet-4-6")
    p.add_argument("--max-tokens", type=int, default=1500)
    p.add_argument("--render", action="store_true",
                   help="Render PNG to /tmp after generation")
    p.add_argument("--out-dir", type=Path, default=Path("/tmp"))
    p.add_argument("--show-prompt", action="store_true",
                   help="Print the prompt that was sent to the LLM")
    args = p.parse_args()

    env_path = Path(__file__).resolve().parent.parent / ".env"
    load_dotenv(env_path)
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        print(f"ANTHROPIC_API_KEY not set (looked in {env_path})", file=sys.stderr)
        return 1

    from anthropic import Anthropic
    client = Anthropic(api_key=api_key)

    sent_prompt: list[str] = []

    def llm_call(prompt: str) -> str:
        sent_prompt.append(prompt)
        msg = client.messages.create(
            model=args.model,
            max_tokens=args.max_tokens,
            messages=[{"role": "user", "content": prompt}],
        )
        return msg.content[0].text

    request = {
        "weakness": args.weakness,
        "experience_level": args.level,
        "player_age": args.age,
        "position": args.position,
        "equipment": [e.strip() for e in args.equipment.split(",") if e.strip()],
        "skill_description": args.skill,
        "selected_weaknesses": _parse_selected(args.selected),
    }

    print(f"=== Request ===")
    print(json.dumps(request, indent=2))
    print()

    try:
        drill = generate_drill(request, llm_call=llm_call)
    except DrillGenerationFailed as e:
        print(f"FAILED: {e}", file=sys.stderr)
        if sent_prompt and args.show_prompt:
            print("\n=== Last prompt ===", file=sys.stderr)
            print(sent_prompt[-1], file=sys.stderr)
        return 2

    if args.show_prompt:
        print("=== Prompt ===")
        print(sent_prompt[0])
        print()

    print("=== Drill ===")
    print(json.dumps(drill, indent=2))

    if args.render:
        try:
            from tools.render_exemplar import _render_png
        except ImportError as e:
            print(f"Cannot render: {e}", file=sys.stderr)
            return 3
        slug = (args.skill or args.weakness).replace(" ", "_")[:40] or "drill"
        png_path = args.out_dir / f"try_drill_{slug}.png"
        _render_png(drill, png_path, exemplar_id=slug, archetype=drill.get("archetype", ""))
        print(f"\nWrote {png_path}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
