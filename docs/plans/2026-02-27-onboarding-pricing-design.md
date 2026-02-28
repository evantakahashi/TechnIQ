# Onboarding Overhaul + Pricing Design

## Summary
Redesign onboarding with "Value Sandwich" pattern: show app value first, personalize, then convert with soft paywall. Add post-onboarding contextual tooltips.

## Decisions
- **Pricing:** StoreKit 2 native (already implemented), single Pro tier ($6.99/mo, 7-day trial)
- **Approach:** Value Sandwich — Feature Highlights → Personalization → Plan Gen → Paywall
- **Paywall type:** Soft — "Continue with Free" always available
- **Tooltips:** 5 contextual coach marks on first visit to each tab

---

## Onboarding Flow (9 Screens)

### Screen 1: Welcome + Hook
- Hero: App logo + mascot (excited) on emerald gradient
- Headline: "Train Like a Pro"
- Subtext: "AI-powered soccer training built for you"
- CTA: "Get Started"
- No skip button

### Screen 2: Feature Highlight — AI Training
- Visual: Animated drill diagram mock (simplified, auto-playing)
- Mascot: coaching state with speech bubble
- Headline: "Smart Drills, Built for You"
- Body: "AI generates personalized drills based on your position, skill level, and weaknesses"
- Progress bar segment 2/9

### Screen 3: Feature Highlight — Progress & XP
- Visual: XP bar filling + level badge animating ("Level 5 — Rising Star")
- Streak fire icon + "7-Day Streak!" badge
- Headline: "Level Up Your Game"
- Body: "Earn XP, build streaks, unlock achievements. 50 levels from Grassroots to Living Legend"

### Screen 4: Feature Highlight — Avatar & Rewards
- Visual: Avatar cycling through cosmetic combos
- Coin icon + shop preview
- Headline: "Make It Yours"
- Body: "Customize your player avatar. Earn coins from training to unlock gear"
- CTA: "Let's Set Up Your Profile →"

**Feature screens shared traits:**
- Emerald-to-dark gradient background
- Swipe left/right navigation + dots indicator
- "Skip" link in top-right (jumps to Screen 5)
- Spring transition animations

### Screen 5: Your Goal (existing, refined)
- Goal selection (5 options with icons) + training frequency (4 chips)
- New: after selecting goal, subtle text: "We'll tailor your drills to this"
- Mascot: coaching

### Screen 6: About You (existing, refined)
- Name (prefilled), age, experience level, years playing
- New: age picker → scrollable wheel (more tactile for kids)
- New: experience buttons show one-line examples (Beginner = "Just starting out", etc.)
- Mascot: encouraging

### Screen 7: Your Style (existing, refined)
- Position (2x2 grid), playing style (5 chips), dominant foot (3 buttons)
- New: position selection shows mini field diagram with selected position highlighted
- New: playing style chips get one-word descriptors ("press high", "flair moves", etc.)
- Mascot: coaching

### Screen 8: Plan Generation (existing)
- 5-phase loading animation (connecting → analyzing → generating → structuring → finalizing)
- Success celebration → transitions to paywall instead of MainTabView

### Screen 9: Paywall
**Layout (top to bottom):**
- Header: "Unlock TechnIQ Pro" with emerald gradient accent
- Personalized hook: "Your [plan name] plan is ready"
- Benefits list (6 items, checkmarks):
  - Unlimited AI-generated drills
  - Personalized training plans
  - Animated drill walkthroughs
  - Smart recommendations based on weaknesses
  - Full progress analytics
  - All avatar items & rewards
- Pricing block:
  - Primary CTA: "Start Your 7-Day Free Trial" (large emerald button)
  - Subtitle: "Then $6.99/month. Cancel anytime."
  - Visual trial timeline: [Today: Trial Starts] — [Day 7: First Charge] — [Cancel anytime]
- Dismiss: "Continue with Free" text link (soft paywall)
- Restore purchases link (App Store required)
- Terms of Service + Privacy Policy links (required)

**Free tier reminder (on "Continue with Free" tap):**
- Toast/sheet: "Free includes: 1 custom drill, 1 quick drill, basic training. Upgrade anytime in Settings."
- Dismisses to MainTabView

**Technical:**
- Uses existing `SubscriptionManager.purchase()` — no new StoreKit code
- Custom UI (not SubscriptionStoreView) for branding control
- Success → dismiss to MainTabView with `isPro = true`
- Cancel/free → dismiss to MainTabView with `isPro = false`

---

## Post-Onboarding Contextual Tooltips

| Location | Trigger | Text | Points To |
|----------|---------|------|-----------|
| Dashboard | First launch post-onboarding | "Start your first session here!" | Today's Training CTA |
| Train tab | First tap | "Browse drills or generate a custom AI drill" | AI drill hero card |
| Plans tab | First tap | "Your AI plan lives here. Complete sessions to progress" | Active plan card |
| Progress tab | First tap | "Track your XP, streaks, and skill growth" | Stats section |
| Avatar | First tap | "Earn coins from training to unlock gear" | Coin balance |

**Implementation:**
- `CoachMarkOverlay` view modifier: dark backdrop (60% opacity) + spotlight cutout + tooltip card with arrow
- Dismiss: tap anywhere
- State: UserDefaults flags (`hasSeenCoachMark_dashboard`, etc.), shown once per key
- Timing: 0.5s delay, spring animation in
- Style: white/raised card, emerald accent arrow, body text, "Got it" dismiss link
- No mascot in tooltips (keep lightweight)

---

## Shared Design Elements

**Progress indicator:** Segmented bar across all 9 screens (not "Step X/5" text)

**Transitions:** Spring animations between all screens, swipe gesture support on feature highlight screens

**Design tokens used:**
- Colors: primaryGreen, accentGold, surfaceBase, surfaceRaised, textPrimary, textSecondary
- Typography: displayMedium (headlines), bodyLarge (descriptions), labelMedium (CTAs)
- Spacing: md (16), lg (24), xl (32)
- Corner radius: lg (16), xl (24)
- Animations: heroSpring, smooth (0.3s)

---

## Unresolved Questions
- What illustrations/assets are needed for feature highlight screens? Mockup vs live component preview?
- Should the paywall show annual pricing option in the future? (Not now, but worth leaving room)
- Should tooltips re-trigger if a user signs out and back in? (Probably no — UserDefaults persists)
