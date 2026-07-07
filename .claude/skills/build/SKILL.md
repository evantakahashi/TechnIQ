---
name: build
description: Build TechnIQ for simulator and report errors concisely
user-invocable: true
allowed-tools: Bash
---

Run the Xcode build:

```bash
xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' SWIFT_ENABLE_EXPLICIT_MODULES=NO CLANG_ENABLE_EXPLICIT_MODULES=NO build 2>&1
```

The two `*_EXPLICIT_MODULES=NO` settings are REQUIRED on the command line (Xcode 26 explicitly-built modules can't precompile FirebaseFirestoreInternal's module map; project-level settings don't reach SPM package targets). Same applies to `test` and `archive` invocations.

After build completes:
- If SUCCESS: report "Build succeeded" with build time
- If FAILED: extract only actual errors (lines containing `: error:`). Ignore SourceKit false positives for Core Data types (Player, Exercise, TrainingSession, etc.) and Firebase modules ("Cannot find in scope" warnings that resolve at build time). List each real error with file:line and suggest fixes.
