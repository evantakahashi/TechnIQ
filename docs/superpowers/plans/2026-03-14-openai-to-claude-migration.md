# OpenAI to Claude Sonnet Migration Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace all OpenAI LLM calls across Firebase Functions with Anthropic Claude Sonnet to improve drill quality and instruction-following.

**Architecture:** Swap SDK (`openai` → `anthropic`), update all API call patterns (`client.chat.completions.create` → `client.messages.create`), add realism constraints to drill prompts. 5 endpoints + 1 helper class to migrate.

**Tech Stack:** Python, Anthropic SDK, Firebase Functions

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `functions/requirements.txt` | Modify | Swap `openai` → `anthropic` |
| `functions/main.py` | Modify | Migrate 4 endpoints + drill pipeline (5 functions) |
| `functions/ml/llm_query_generator.py` | Modify | Migrate YouTube query generator |
| `functions/.env.yaml` | Modify (manual) | Add `ANTHROPIC_API_KEY`, keep `OPENAI_API_KEY` until verified |

## OpenAI → Anthropic API Pattern

Every migration follows this pattern:

**Before (OpenAI):**
```python
from openai import OpenAI
client = OpenAI(api_key=openai_api_key)
response = client.chat.completions.create(
    model="gpt-4-turbo",
    messages=[
        {"role": "system", "content": "system prompt"},
        {"role": "user", "content": "user prompt"}
    ],
    max_tokens=500,
    temperature=0.3
)
result = response.choices[0].message.content
```

**After (Anthropic):**
```python
from anthropic import Anthropic
client = Anthropic(api_key=anthropic_api_key)
response = client.messages.create(
    model="claude-sonnet-4-6",
    system="system prompt",
    messages=[
        {"role": "user", "content": "user prompt"}
    ],
    max_tokens=500,
    temperature=0.3
)
result = response.content[0].text
```

---

## Chunk 1: SDK + Drill Pipeline

### Task 1: Update requirements.txt

**Files:**
- Modify: `functions/requirements.txt`

- [ ] **Step 1: Replace openai with anthropic**

```
firebase-functions
firebase-admin
google-api-python-client
anthropic
requests
```

- [ ] **Step 2: Commit**

```bash
git add functions/requirements.txt
git commit -m "chore: replace openai with anthropic in requirements"
```

---

### Task 2: Migrate drill pipeline (generate_custom_drill)

**Files:**
- Modify: `functions/main.py`

This is the most important migration — the drill quality is the core problem.

- [ ] **Step 1: Update generate_custom_drill endpoint (lines ~262-269)**

Replace:
```python
openai_api_key = os.environ.get('OPENAI_API_KEY')
if not openai_api_key:
    return https_fn.Response("OpenAI API key not configured", status=500)
drill_data = generate_drill_pipeline(player_profile, requirements, session_context, drill_feedback, field_size, openai_api_key)
```
With:
```python
anthropic_api_key = os.environ.get('ANTHROPIC_API_KEY')
if not anthropic_api_key:
    return https_fn.Response("Anthropic API key not configured", status=500)
drill_data = generate_drill_pipeline(player_profile, requirements, session_context, drill_feedback, field_size, anthropic_api_key)
```

Also update the response `"algorithm"` field from `"openai_custom_drill_generation"` to `"claude_custom_drill_generation"`.

- [ ] **Step 2: Update generate_drill_pipeline function signature and client init**

Replace:
```python
def generate_drill_pipeline(player_profile: Dict, requirements: Dict, session_context: Dict, drill_feedback: list, field_size: str, openai_api_key: str) -> Dict:
    """4-phase agentic drill generation: Scout → Coach → Writer ⇄ Referee"""
    from openai import OpenAI
    client = OpenAI(api_key=openai_api_key)
```
With:
```python
def generate_drill_pipeline(player_profile: Dict, requirements: Dict, session_context: Dict, drill_feedback: list, field_size: str, anthropic_api_key: str) -> Dict:
    """4-phase agentic drill generation: Scout → Coach → Writer ⇄ Referee"""
    from anthropic import Anthropic
    client = Anthropic(api_key=anthropic_api_key)
```

- [ ] **Step 3: Migrate phase_scout**

Replace the `client.chat.completions.create(...)` call and response parsing:

```python
response = client.messages.create(
    model="claude-sonnet-4-6",
    system="You are a soccer performance analyst. Identify the player's #1 weakness from their data and recommend a creative, specific drill archetype. Prioritize structured weakness selections, then explicit requests, then match data, then session ratings. Be inventive — avoid generic drills.",
    messages=[
        {"role": "user", "content": prompt}
    ],
    max_tokens=500,
    temperature=0.3
)
return parse_llm_json(response.content[0].text)
```

- [ ] **Step 4: Migrate phase_coach**

Same pattern — replace the API call:

```python
response = client.messages.create(
    model="claude-sonnet-4-6",
    system="You are a soccer drill architect. Design practical spatial layouts that directly address the identified weakness. Only use equipment the player has. Keep coordinates within field dimensions.",
    messages=[
        {"role": "user", "content": prompt}
    ],
    max_tokens=600,
    temperature=0.4
)
return parse_llm_json(response.content[0].text)
```

- [ ] **Step 5: Migrate phase_writer + add realism constraints**

Replace the API call:

```python
response = client.messages.create(
    model="claude-sonnet-4-6",
    system="You are an expert soccer coach. Write complete, creative, practical drills from blueprints. Each instruction must be ONE clear action with an imperative verb. Keep all coordinates within field dimensions. Every diagram path MUST include a step integer linking to its instruction. Be inventive and specific — avoid generic drills.",
    messages=[
        {"role": "user", "content": prompt}
    ],
    max_tokens=1500,
    temperature=0.7
)
return parse_llm_json(response.content[0].text)
```

Also add these realism constraints to the Writer prompt string (append before the "Return ONLY valid JSON:" line):

```python
PHYSICAL REALISM RULES (CRITICAL):
- Players can ONLY pass to other players, NEVER to cones, markers, or empty space
- Every piece of equipment in the equipment list MUST appear as an element in the diagram
- If "wall" is in equipment, it MUST appear as a diagram element with type "wall"
- Movement paths must have a clear soccer purpose — no random or unnecessary runs
- Cones mark positions/gates, they do NOT receive passes or act as players
- If the drill requires multiple players, assign clear roles (attacker, defender, server)
```

- [ ] **Step 6: Migrate phase_referee + add realism check**

Replace the API call:

```python
response = client.messages.create(
    model="claude-sonnet-4-6",
    system="You are a soccer drill safety and logic checker. Be strict but fair. Only flag genuine issues that would make the drill confusing, unsafe, or ineffective. Score 85+ means production-ready.",
    messages=[
        {"role": "user", "content": prompt}
    ],
    max_tokens=800,
    temperature=0.1
)
result = parse_llm_json(response.content[0].text)
```

Also add this to the Referee prompt's validation checklist (after item 7):

```
8. REALISM: Are players passing to other players (not cones/markers)? Does every equipment item appear in the diagram? Do movement paths make physical and tactical sense?
```

- [ ] **Step 7: Commit**

```bash
git add functions/main.py
git commit -m "feat: migrate drill pipeline to Claude Sonnet + add realism constraints"
```

---

## Chunk 2: Remaining Endpoints

### Task 3: Migrate get_advanced_recommendations

**Files:**
- Modify: `functions/main.py`

- [ ] **Step 1: Find the get_advanced_recommendations function**

Search for `def get_advanced_recommendations` — it uses `gpt-4` with a single LLM call.

- [ ] **Step 2: Replace OpenAI client init and API call**

Replace `OPENAI_API_KEY` env var lookup with `ANTHROPIC_API_KEY`.
Replace `from openai import OpenAI` / `client = OpenAI(...)` with `from anthropic import Anthropic` / `client = Anthropic(...)`.
Replace the `client.chat.completions.create(...)` call following the standard pattern.
Replace `response.choices[0].message.content` with `response.content[0].text`.

- [ ] **Step 3: Commit**

```bash
git add functions/main.py
git commit -m "feat: migrate get_advanced_recommendations to Claude Sonnet"
```

---

### Task 4: Migrate generate_training_plan

**Files:**
- Modify: `functions/main.py`

- [ ] **Step 1: Find generate_training_plan function**

It uses `gpt-4` with `max_tokens=4000`. Keep the same max_tokens for Claude.

- [ ] **Step 2: Replace OpenAI client init and API call**

Same pattern as Task 3. Note this endpoint has a large `max_tokens=4000` — keep that.

- [ ] **Step 3: Commit**

```bash
git add functions/main.py
git commit -m "feat: migrate generate_training_plan to Claude Sonnet"
```

---

### Task 5: Migrate get_daily_coaching

**Files:**
- Modify: `functions/main.py`

- [ ] **Step 1: Find get_daily_coaching function**

Uses `gpt-4-turbo` with `max_tokens=1200`, `temperature=0.4`.

- [ ] **Step 2: Replace OpenAI client init and API call**

Same pattern. Keep `max_tokens=1200` and `temperature=0.4`.

- [ ] **Step 3: Commit**

```bash
git add functions/main.py
git commit -m "feat: migrate get_daily_coaching to Claude Sonnet"
```

---

### Task 6: Migrate LLMQueryGenerator (YouTube)

**Files:**
- Modify: `functions/ml/llm_query_generator.py`
- Modify: `functions/ml/youtube_recommendations.py`
- Modify: `functions/main.py` (the get_youtube_recommendations endpoint)

- [ ] **Step 1: Update LLMQueryGenerator class**

In `functions/ml/llm_query_generator.py`, replace the class:

```python
class LLMQueryGenerator:
    """Generate personalized YouTube search queries using Anthropic's Claude"""

    def __init__(self, anthropic_api_key: Optional[str] = None):
        self.client = None

        if anthropic_api_key:
            try:
                from anthropic import Anthropic
                self.client = Anthropic(api_key=anthropic_api_key)
                logger.info("🤖 LLM Query Generator initialized with Anthropic")
            except ImportError:
                logger.warning("⚠️ Anthropic library not available")
            except Exception as e:
                logger.warning(f"⚠️ Failed to initialize Anthropic client: {e}")
        else:
            logger.info("🔄 LLM Query Generator running without LLM (fallback mode)")
```

- [ ] **Step 2: Update generate_search_queries API call**

Replace the OpenAI API call:

```python
response = self.client.messages.create(
    model="claude-sonnet-4-6",
    system="You are an expert soccer coach and YouTube content strategist. Generate highly specific, effective YouTube search queries that will find the best training videos for soccer players.",
    messages=[
        {"role": "user", "content": prompt}
    ],
    temperature=0.7,
    max_tokens=300
)
content = response.content[0].text.strip()
```

- [ ] **Step 3: Update youtube_recommendations.py parameter names**

In `functions/ml/youtube_recommendations.py`, rename `openai_api_key` to `anthropic_api_key` in:
- `YouTubeMLEngine.__init__` parameter
- `create_youtube_ml_engine` function parameter
- The `LLMQueryGenerator(...)` init call

- [ ] **Step 4: Update get_youtube_recommendations endpoint in main.py**

Replace `openai_api_key = os.environ.get('OPENAI_API_KEY')` with `anthropic_api_key = os.environ.get('ANTHROPIC_API_KEY')`.
Update the `create_youtube_ml_engine(youtube_api_key, openai_api_key)` call to use `anthropic_api_key`.
Update related log messages.

- [ ] **Step 5: Commit**

```bash
git add functions/ml/llm_query_generator.py functions/ml/youtube_recommendations.py functions/main.py
git commit -m "feat: migrate YouTube query generator to Claude Sonnet"
```

---

## Chunk 3: Cleanup + Verification

### Task 7: Clean up remaining OpenAI references

**Files:**
- Modify: `functions/main.py`

- [ ] **Step 1: Search for any remaining OpenAI references**

Search for `openai`, `OpenAI`, `OPENAI`, `gpt-` in all files under `functions/`. Remove or update any remaining references (log messages, comments, etc.).

- [ ] **Step 2: Verify no import of openai remains**

Grep for `from openai` or `import openai` — should find zero matches.

- [ ] **Step 3: Commit**

```bash
git add -A functions/
git commit -m "chore: clean up remaining OpenAI references"
```

---

### Task 8: Manual steps (NOT automated)

These require manual action by the developer:

- [ ] **Step 1: Get Anthropic API key**

Go to https://console.anthropic.com/ → API Keys → Create key.

- [ ] **Step 2: Add to .env.yaml**

In `functions/.env.yaml`, add:
```yaml
ANTHROPIC_API_KEY: "sk-ant-..."
```

Keep `OPENAI_API_KEY` temporarily until migration is verified.

- [ ] **Step 3: Install dependencies locally**

```bash
cd functions && pip install -r requirements.txt
```

- [ ] **Step 4: Deploy and test**

```bash
cd functions && firebase deploy --only functions
```

Test each endpoint manually. Once verified, remove `OPENAI_API_KEY` from `.env.yaml`.
