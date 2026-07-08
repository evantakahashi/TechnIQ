# App Store Connect — Listing Package (draft, 2026-07-07)

## App name (30 chars max)
**TechnIQ: AI Soccer Training** (29)

## Subtitle (30 chars max)
**AI drills, plans & progress** (27)

## Promotional text (170 chars, editable without review)
Train smarter: AI builds your weekly plan, generates drills for your weaknesses, and tracks every session. New drills and features added constantly.

## Description
TechnIQ is your AI soccer coach. Tell it your position, goals, and weak spots — it builds a personalized training plan, generates custom drills with animated diagrams, and tracks your progress session by session.

TRAIN WITH PURPOSE
• AI training plans built around your schedule, level, and goals
• Custom drill generator: describe what you want to improve, get a full drill with setup diagram, steps, and coaching points
• Quick drills for when you have 15 minutes and a ball

TRACK EVERYTHING
• Log training sessions and matches; see streaks, XP, and level progression
• Skill trends, calendar heat map, and season stats
• Smart insights that spot your weaknesses and recommend what to work on next

STAY MOTIVATED
• 30 achievements, coin economy, and a customizable avatar
• Community: share drills, post progress, learn from other players
• Curated YouTube drill videos matched to your training needs

TECHNIQ PRO (subscription)
• Unlimited AI training plans and drill generation
• Daily AI coaching and weekly plan adaptation
• Smart recommendations powered by your training history
7-day free trial, cancel anytime.

Works offline; your data syncs securely across devices with your account. Sign in with Apple, Google, email — or train as a guest.

## Keywords (100 chars max, comma-separated, no spaces)
soccer,football,training,drills,AI,coach,practice,skills,dribbling,youth,fitness,plan,tracker
(98 chars)

## Category
Primary: Sports · Secondary: Health & Fitness

## Age rating
4+ (no objectionable content; UGC exists → answer "Yes" to unrestricted web access? NO — no browser. UGC questionnaire: user-generated content with moderation (report/block) → typically still 4+; answer honestly: infrequent/mild UGC.)

## URLs
- Support URL: (needed — GitHub Pages or techniq-b9a27.web.app/support — create page)
- Marketing URL (optional): brother's YouTube channel (40k+ subs) or hosted landing page
- Privacy Policy URL: host PRIVACY_POLICY.md (already served? verify https://techniq-b9a27.web.app/privacy-policy.html matches the updated markdown — REGENERATE the hosted HTML from the 2026-07-07 policy before submitting)

## Privacy nutrition labels (must match PrivacyInfo.xcprivacy)
Collected, linked to identity, NOT used for tracking:
- Contact info: email, name
- Identifiers: user ID
- Fitness: training/fitness data
- User content: other user content (community posts/drills)
Collected, NOT linked: Diagnostics (crash data)
No tracking. No third-party advertising.

## Review notes (paste into ASC)
TechnIQ requires an account for cloud sync. FASTEST REVIEW PATH: tap "Continue without account" on the sign-in screen (anonymous auth — full core experience, no credentials needed).
Demo account (Pro features unlocked): email `<CREATE-DEMO-ACCOUNT>` password `<SET>` — seed it with a profile + a few sessions before submitting.
Subscriptions: TechnIQ Pro monthly (com.techniq.pro.monthly) with 7-day trial; sandbox-testable.
Community content is user-generated with report + block support; content is soccer-training focused.
Sign in with Apple is implemented per guideline 4.8 alongside Google Sign-In.
Account deletion: Settings → Delete Account (guideline 5.1.1(v)).

## Screenshot shot-list (6.9" mandatory; capture on iPhone 16/17 Pro Max sim, dark mode)
1. Dashboard — header + streak + Today's Focus card ("Your AI coach for every session")
2. Custom drill generator result w/ diagram ("Describe it. Get a full drill.")
3. Active training session view ("Guided sessions that keep score")
4. Training plan week view ("A plan that adapts to you")
5. Progress/analytics — skill trends + heat map ("Watch yourself improve")
6. (optional) Community feed ("Train with the community")
Framing: device frame + one-line headline per shot; Stadium Night dark background, lime accents.

## Build/submission mechanics
- Archive via CLI ONLY (see APP_STORE_DEPLOYMENT_CHECKLIST.md — explicit-modules flags)
- Export compliance: ITSAppUsesNonExemptEncryption=false already in Info.plist
- Version 1.0, build 1 (bump build per upload)
