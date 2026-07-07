---
name: deploy
description: Deploy Firebase Functions with safety checks
user-invocable: true
allowed-tools: Bash, Read, Grep
---

Before deploying:
1. Grep `functions/main.py` for `FUNCTIONS_EMULATOR` — the auth bypass must be gated on it and nothing else (`ALLOW_UNAUTHENTICATED` was removed 2026-07; warn if it reappears)
2. Check `functions/.env.yaml` exists locally (holds ANTHROPIC_API_KEY / YOUTUBE_API_KEY values)
3. Run backend tests first: `cd /Users/evantakahashi/TechnIQ/functions && ./venv/bin/python -m pytest -q --ignore=venv` — abort deploy on failures

Deploy:
```bash
cd /Users/evantakahashi/TechnIQ/functions && firebase deploy --only functions
```

Notes:
- `.env.yaml` is excluded from the upload bundle (firebase.json ignore + .gcloudignore). `firebase deploy` does NOT read `.env.yaml` for runtime env — if functions come up missing ANTHROPIC_API_KEY/YOUTUBE_API_KEY after deploy, set env explicitly: `gcloud functions deploy ... --env-vars-file .env.yaml`, or migrate values to `functions/.env` (dotenv, gitignored) which the Firebase CLI auto-loads, or use `firebase functions:secrets:set`.
- Deploying functions does not deploy Firestore rules/indexes; for those run `firebase deploy --only firestore` (validate rules first with the emulator if available).

Report success/failure. If deploy fails, show the relevant error lines.
