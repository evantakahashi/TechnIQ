---
name: deploy
description: Deploy Firebase Functions with safety checks
user-invocable: true
allowed-tools: Bash, Read, Grep
---

Before deploying:
1. Grep `functions/main.py` for `ALLOW_UNAUTHENTICATED` — warn if set to `true` in code (env var for local testing only)
2. Check `functions/.env.yaml` exists (required for deploy)

Deploy:
```bash
cd /Users/evantakahashi/Desktop/TechnIQ/functions && firebase deploy --only functions
```

Report success/failure. If deploy fails, show the relevant error lines.
