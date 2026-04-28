# Migrate All LLM Endpoints from OpenAI to Claude Sonnet

## Summary
Replace OpenAI (gpt-4-turbo / gpt-4) with Anthropic Claude Sonnet (claude-sonnet-4-6) across all 4 Firebase Function endpoints. Improves drill quality (realism, instruction-following) at similar or lower cost.

## Problem
Current gpt-4-turbo generates drills with:
- Players passing to cones instead of other players
- Nonsensical movement paths
- Missing wall elements in diagrams
- Drills that don't target the selected weakness
- Generic, unrealistic drill designs

## Solution
Swap to claude-sonnet-4-6 for better structured reasoning + add explicit realism constraints to drill prompts.

## Endpoints to Migrate

| Endpoint | Current Model | Calls per Request |
|----------|--------------|-------------------|
| `generate_custom_drill` | gpt-4-turbo (x4-6) | Scout, Coach, Writer, Referee + retries |
| `get_youtube_recommendations` | gpt-4 (via engine) | 1 |
| `get_advanced_recommendations` | gpt-4 | 1 |
| `generate_training_plan` | gpt-4-turbo (x2) | 2 |

## What Changes

### SDK Swap
- Remove `openai` from `functions/requirements.txt`
- Add `anthropic` to `functions/requirements.txt`
- Replace all `from openai import OpenAI` / `client.chat.completions.create()` with `from anthropic import Anthropic` / `client.messages.create()`

### API Format Change
OpenAI:
```python
client.chat.completions.create(
    model="gpt-4-turbo",
    messages=[
        {"role": "system", "content": "..."},
        {"role": "user", "content": "..."}
    ],
    max_tokens=500,
    temperature=0.3
)
response.choices[0].message.content
```

Anthropic:
```python
client.messages.create(
    model="claude-sonnet-4-6",
    system="...",
    messages=[
        {"role": "user", "content": "..."}
    ],
    max_tokens=500,
    temperature=0.3
)
response.content[0].text
```

### Environment Config
- Replace `OPENAI_API_KEY` with `ANTHROPIC_API_KEY` in `functions/.env.yaml`

### Prompt Realism Improvements (drill pipeline only)

**Writer prompt additions:**
- "Players can only pass to other players, NOT to cones or markers"
- "Every piece of equipment listed must appear as an element in the diagram"
- "Movement paths must have a clear soccer purpose — no random or unnecessary runs"
- "If a wall is in the equipment list, it MUST appear in the diagram elements"

**Referee prompt additions:**
- Add REALISM validation check: "Are players passing to other players (not cones)? Does every equipment item appear in the diagram? Do movement paths make physical/tactical sense?"

## What Stays the Same
- 4-phase pipeline structure (Scout -> Coach -> Writer <-> Referee)
- All prompt content (except realism additions above)
- Retry loop (3 attempts)
- `parse_llm_json()` helper
- Programmatic validation in `phase_referee`
- Temperature and max_tokens per phase
- All Firebase Auth checks
- iOS client code (unchanged — calls same HTTP endpoints)

## Cost Estimate
~$0.04-0.07 per drill (similar to current gpt-4-turbo cost)
