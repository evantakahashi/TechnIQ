# TechnIQ App Store Deployment Checklist

**Last Updated:** July 6, 2026 (rewritten from `docs/audits/2026-07-06-full-audit.md`)

Status: closer to submission-ready than the prior (Nov-2025) checklist implied. The two hard
blockers are the **missing app icon** and the **SDK privacy-manifest bump**; everything else is
metadata prep or non-blocking polish. Compliance items previously flagged (encryption key,
dangling SceneDelegate, iPad screenshots) are resolved in this pass.

---

## ✅ Done / Verified

### Guideline compliance
- [x] **Sign in with Apple** — implemented (`AuthenticationManager.swift`), entitlement present (satisfies 4.8)
- [x] **In-app account deletion** — Settings → token-verified `delete_account` Function (satisfies 5.1.1(v))
- [x] **UGC moderation** — community report/block support (satisfies 1.2)
- [x] **Functions auth enforced** — all HTTPS endpoints require Firebase Auth in production
- [x] **No push mismatch** — entitlements contain no `aps-environment`
- [x] **No unused permission prompts** — app uses no camera/photo/location/notification APIs, so no usage-description strings are needed (verified)
- [x] **UserDefaults required-reason** — CA92.1 declared in `PrivacyInfo.xcprivacy`, matches usage

### Configuration (fixed in this pass)
- [x] **Export compliance** — `ITSAppUsesNonExemptEncryption = false` added to `Info.plist` (stops the TestFlight "Missing Compliance" prompt; app uses only standard HTTPS)
- [x] **Dangling SceneDelegate removed** — deleted the `UISceneConfigurations`/`UISceneDelegateClassName` block from `Info.plist` (pure SwiftUI app; class never existed)
- [x] **iPhone-only for v1.0** — `TARGETED_DEVICE_FAMILY = 1` (removes mandatory iPad 13" screenshots; iPad still runs it in compatibility mode)
- [x] **Version** — 1.0 (build 1)
- [x] **Launch screen** — configured (`UILaunchScreen`)

### Code quality
- [x] **Debug logging gated** — all 283 `print()` calls are inside `#if DEBUG` (count was previously mis-stated as 187)
- [x] **No force-unwrap/`try!`/`as!` landmines** — 0 `try!`, 0 `as!` in the app target

---

## 🚫 Blockers — must fix before a successful upload

- [x] **App icon (1024×1024 PNG, no alpha)** — DONE 2026-07-07: generated stadium-night kickoff-circle icon at `AppIcon.appiconset/AppIcon.png` (replace with brand asset anytime; keep filename or update Contents.json).
- [x] **Bump SDKs for privacy manifests** — DONE 2026-07-07: `firebase-ios-sdk` → 11.15.0 (upToNextMajor 11.0.0), `GoogleSignIn-iOS` → 8.0.0 (upToNextMajor 8.0.0); pruned 14 unused linked products (all Analytics variants, AppCheck, Database, Storage, Performance, MLModelDownloader, Combine/-Swift shims). Retest auth/Google/Apple sign-in on device before submitting.
- [ ] **Archive from the command line ONLY** — Xcode 26's explicitly-built modules cannot compile `FirebaseFirestoreInternal` (broken generated module map), and the required overrides don't reach SPM targets from project settings, so GUI Product▸Archive fails. Use:
  `xcodebuild -project TechnIQ.xcodeproj -scheme TechnIQ -destination 'generic/platform=iOS' SWIFT_ENABLE_EXPLICIT_MODULES=NO CLANG_ENABLE_EXPLICIT_MODULES=NO archive -archivePath build/TechnIQ.xcarchive` (then Organizer or `xcodebuild -exportArchive`). Drop the flags when Firebase/Apple fix the module map.

---

## 📸 Screenshots & App Store Connect metadata

- [ ] **Screenshots** — 6.9" iPhone (iPhone 16/17 Pro Max class) is the current **mandatory** size; 5.5" is no longer accepted-as-required. Capture 3–5 per required size. (No iPad 13" needed now that the app is iPhone-only.)
- [ ] **Hosted Privacy Policy URL** — `PRIVACY_POLICY.md` exists but is not hosted; host it (e.g. GitHub Pages) and use the permanent URL.
- [ ] **Support URL** (required) and Marketing URL (optional — the 40k-sub YouTube channel is a strong marketing URL)
- [ ] **Listing copy** — App name (≤30), subtitle (≤30), description (≤4000), keywords (≤100), promo text (≤170)
- [ ] **Privacy nutrition labels** — must match actual collection (see privacy-manifest item below)
- [ ] **Age rating** questionnaire (expected 4+)
- [ ] **App Review notes + demo account** — reviewers can't use their own Google account; seed an email/password demo login. Call out that "Continue without account" (anonymous auth) is the fastest path to explore the app.

---

## 🔧 Code / config still worth addressing (not upload-blocking)

- [ ] **Privacy manifest data types understate collection** — `PrivacyInfo.xcprivacy` declares only EmailAddress/UserID/Name. App also syncs fitness/training data (Fitness), stores community posts (OtherUserContent), and links GoogleAppMeasurement (UsageData/CrashData). Add these and mirror them in the ASC nutrition labels, or drop Firebase Analytics to shrink the disclosure surface.
- [ ] **`YOUTUBE_API_KEY` build setting is defined nowhere** — `Info.plist` embeds `$(YOUTUBE_API_KEY)` but no pbxproj/xcconfig/scheme defines it, so in an Archive build the value is empty and YouTube recs silently no-op (Guideline 2.1 risk); any injected key also ships plaintext in the bundle. Fix: route YouTube search through the existing `get_youtube_recommendations` Function (key stays server-side) and delete the Info.plist key.
- [ ] **SIWA presentation anchor** — `presentationContextProvider` cast is always nil (no conforming type); works on iPhone but verify SIWA on a physical device before submission (Apple tests it).
- [ ] **Production logging** — release builds are silent (`print()` gated out); migrate hot paths to `AppLogger` for os_log breadcrumbs.
- [ ] **Bundle ID** — `evan.TechnIQ` is valid but not reverse-DNS and becomes immutable after first upload. Decide now whether to switch to e.g. `com.evantakahashi.techniq` (requires new Firebase iOS app + updated `GoogleService-Info.plist` + URL scheme) before creating the ASC record.

---

## 👤 User action items (outside the codebase)

- [ ] **Rotate API keys** in `functions/.env.yaml` and revoke the old ones (they were exposed).
- [ ] **Host the privacy policy** and update `PRIVACY_POLICY.md` (add email/Apple/anonymous auth methods, UGC/community section, and the in-app Settings → Delete Account path; bump the effective date).
- [ ] **Create the App Store Connect app record**, then fill metadata, upload screenshots, complete nutrition labels + age rating, and add the demo account to review notes.
- [ ] **Physical-device pass** — auth (Google/Apple/email/anonymous), Firestore sync, Core Data persistence, offline behavior.

---

## Support information
- **Developer Email:** evan10takahashi@gmail.com
- **Bundle ID:** evan.TechnIQ
- **Primary Category:** Health & Fitness → Sports
- **Target Audience:** Soccer players (all skill levels)
