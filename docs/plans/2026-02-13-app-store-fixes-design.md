# App Store Readiness Fixes Design

## Problem
App assessed at ~45% App Store readiness. Six issues need fixing: no-op ToS button, no privacy policy, no crash reporting, near-zero accessibility, missing AI rate limiting, no Sign in with Apple.

## Fixes

### 1. ToS + Privacy Policy (Firebase Hosting)
- Static HTML pages deployed to `techniq-b9a27.web.app/privacy-policy` and `/terms-of-service`
- AuthenticationView ToS button opens terms URL via `UIApplication.shared.open()`
- Add Privacy Policy link next to it
- Add "Legal" section in SettingsView with both links
- Placeholder legal text (user replaces with real content)

### 2. Crashlytics
- Add `FirebaseCrashlytics` SPM dependency
- Enable collection in `TechnIQApp.swift` init
- Set `crashlytics().setUserID(uid)` on auth state change
- Minimal integration — non-fatal logging deferred

### 3. Accessibility (Critical Path Only)
- ~10 key views using existing `AccessibilityModifiers.swift` framework
- Auth, Dashboard, TodaysTraining, ActiveTraining, ExerciseLibrary, Settings, ActivePlan, EnhancedProfile, SessionComplete, AvatarCustomization
- Labels on interactive elements, hints on non-obvious actions

### 4. CloudMLService Rate Limiting
- `lastRequestTime` dictionary keyed by endpoint
- 30-second cooldown between identical requests (mirrors CloudSyncManager pattern)
- Throws descriptive error for UI to display

### 5. Sign in with Apple
- `ASAuthorizationAppleIDProvider` flow in AuthenticationManager
- Firebase credential from Apple ID token
- Unified sign-in/sign-up (Apple's standard)
- Button in AuthenticationView alongside Google
- Store display name from Apple's first-time response

## File Changes

### Create
- `hosting/privacy-policy.html`
- `hosting/terms-of-service.html`
- `hosting/firebase.json` (hosting config)

### Modify
- `TechnIQ.xcodeproj` — add Crashlytics SPM dependency
- `TechnIQApp.swift` — Crashlytics init
- `AuthenticationManager.swift` — setUserID on auth, signInWithApple()
- `AuthenticationView.swift` — ToS link, Privacy link, Apple sign-in button
- `SettingsView.swift` — Legal section
- `CloudMLService.swift` — rate limiting
- ~10 views — accessibility labels

## Unresolved Questions
None.
