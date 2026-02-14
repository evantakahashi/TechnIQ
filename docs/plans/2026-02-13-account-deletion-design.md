# Account Deletion Design

## Problem
No way to delete an account. Required for App Store compliance (Apple mandates account deletion if you offer account creation).

## Solution

### Firebase Function: `delete_account`
- Auth required (Firebase token)
- Anonymize community posts: set authorName → "Deleted User", authorID → "deleted", clear profile image
- Delete all user-scoped Firestore docs: `users/{uid}/*`, `playerProfiles/{uid}`, `players/{uid}`, `mlRecommendations/{uid}`, `playerGoals/{uid}`, `recommendationFeedback/{uid}`, `cloudSyncStatus/{uid}`
- Delete Firebase Auth user via Admin SDK
- Idempotent — retrying after partial deletion is safe

### Client Flow
- "Delete Account" button in SettingsView under new "Account" section
- Two-step confirmation: Alert 1 warns, Alert 2 requires typing "DELETE"
- Calls `AuthenticationManager.deleteAccount()` which hits the Firebase Function
- On success: delete local Core Data Player entities, clear UserDefaults, sign out
- On failure: show error alert with retry option
- Retry with exponential backoff on the HTTP call

### File Changes
- Modify: `functions/main.py` — add `delete_account` endpoint
- Modify: `TechnIQ/AuthenticationManager.swift` — add `deleteAccount() async throws`
- Modify: `TechnIQ/SettingsView.swift` — add Account section, delete button, two-step alerts, loading state

## Unresolved Questions
None.
