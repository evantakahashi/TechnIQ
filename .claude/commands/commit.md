# Commit and Push

1. Run `git status` and `git diff --staged` and `git diff` to see all changes
2. Run `git log --oneline -5` to match recent commit style
3. Stage relevant files individually (NEVER `git add -A` or `git add .`)
   - Skip: .env, credentials, GoogleService-Info.plist, *.backup, build artifacts
4. Auto-generate a concise commit message from the diff:
   - Use conventional prefix: feat/fix/refactor/chore/docs
   - One line, lowercase, no period, max 72 chars
   - Focus on WHAT changed, not HOW
   - Do NOT mention AI, Claude, or co-authors
5. Commit using heredoc format:
```bash
git commit -m "$(cat <<'EOF'
<message>
EOF
)"
```
6. Push: `git push origin main`
7. Run `git status` to verify clean tree
