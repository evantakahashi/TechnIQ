"""Session cost ledger. Records every LLM call's tokens; warns on burn.

List prices $/Mtok (verify against provider pricing pages on change):
"""
import json
import time
from pathlib import Path

PRICES = {
    "claude-opus-4-8": (5.0, 25.0),
    "claude-sonnet-4-6": (3.0, 15.0),
    "claude-sonnet-5": (3.0, 15.0),
    "gpt-5.2": (1.75, 14.0),
}
LEDGER = Path("/private/tmp/claude-501/-Users-evantakahashi-TechnIQ/b08d8283-5ffa-4cc9-a162-1b68b76fde40/scratchpad/cost_ledger.jsonl")


def record(model: str, input_tokens: int, output_tokens: int, tag: str = "") -> float:
    pin, pout = PRICES.get(model, (5.0, 25.0))
    cost = (input_tokens * pin + output_tokens * pout) / 1e6
    with LEDGER.open("a") as f:
        f.write(json.dumps({"t": time.time(), "model": model, "in": input_tokens,
                            "out": output_tokens, "cost": round(cost, 5), "tag": tag}) + "\n")
    return cost


def total(provider_prefix: str = "") -> float:
    if not LEDGER.exists():
        return 0.0
    tot = 0.0
    for line in LEDGER.read_text().splitlines():
        r = json.loads(line)
        if r["model"].startswith(provider_prefix):
            tot += r["cost"]
    return round(tot, 3)


def report() -> str:
    return (f"anthropic ${total('claude'):.2f} | openai ${total('gpt'):.2f} "
            f"(ledger since it was added — earlier session spend not included)")
