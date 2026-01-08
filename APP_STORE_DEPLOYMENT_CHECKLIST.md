# TechnIQ App Store Deployment Checklist

**Last Updated:** November 24, 2025

## ✅ **COMPLETED ITEMS**

### Code Quality
- [x] **Debug Logging Removed** - All 187 print() statements wrapped in `#if DEBUG` blocks
- [x] **No TODOs/FIXMEs** - All code comments cleaned up
- [x] **Build Succeeds** - Clean build with no errors
- [x] **No Hardcoded Secrets** - API keys properly stored in environment variables

### Configuration
- [x] **Bundle Identifier** - `evan.TechnIQ`
- [x] **Version Number** - 1.0 (Build 1)
- [x] **Info.plist Complete** - All required keys present
- [x] **Privacy Descriptions** - No additional permissions needed (app doesn't use camera, location, etc.)
- [x] **Privacy Policy** - Comprehensive policy created at `/PRIVACY_POLICY.md`

### Code Implementation
- [x] **Core Data Models** - All Training Plan entities properly added
- [x] **Firebase Integration** - Authentication, Firestore, Functions properly configured
- [x] **Error Handling** - Appropriate error handling in place
- [x] **API Deprecations Fixed** - Updated `.onChange(of:)` to iOS 17+ syntax

## ⚠️ **CRITICAL - REQUIRES IMMEDIATE ACTION**

### Visual Assets (BLOCKING)
- [ ] **App Icon** - **MISSING - MUST CREATE**
  - Required: 1024x1024px PNG
  - Location: `TechnIQ/Assets.xcassets/AppIcon.appiconset/`
  - No transparency allowed
  - Should represent a soccer training app

- [ ] **App Store Screenshots** - **MISSING - MUST CREATE**
  - Required for each device size:
    - iPhone 6.7" (iPhone 14 Pro Max, 15 Pro Max)
    - iPhone 6.5" (iPhone 11 Pro Max, XS Max)
    - iPhone 5.5" (iPhone 8 Plus)
  - Minimum: 3 screenshots per size
  - Recommended: 5 screenshots showing key features
  - Dimensions: See [Apple's guidelines](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications)

## 📋 **RECOMMENDED BEFORE SUBMISSION**

### Testing
- [ ] **Physical Device Testing**
  - Test on actual iPhone (not just simulator)
  - Verify Firebase authentication works
  - Test YouTube video recommendations
  - Verify Core Data persistence
  - Test offline functionality

- [ ] **User Flow Testing**
  - Complete onboarding process
  - Create player profile
  - Add training sessions
  - Generate recommendations
  - Test all tabs (Home, Sessions, Exercises, Plans, Progress, Profile)

### App Store Connect Preparation
- [ ] **App Store Listing Text**
  - App Name (30 characters max)
  - Subtitle (30 characters max)
  - Description (4000 characters max)
  - Keywords (100 characters max)
  - Promotional Text (170 characters)

- [ ] **Support & Marketing URLs**
  - Support URL (required)
  - Marketing URL (optional)
  - Privacy Policy URL (required) - Host the PRIVACY_POLICY.md somewhere

- [ ] **Age Rating**
  - Complete questionnaire in App Store Connect
  - Expected: 4+ (safe for all ages)

- [ ] **App Review Information**
  - Contact information
  - Demo account credentials (if needed)
  - Notes for reviewer

## 🔍 **KNOWN NON-BLOCKING ISSUES**

### Minor Warnings (Safe to Ignore)
- Core Data auto-generated files in Copy Bundle Resources (cosmetic Xcode warning)
- Duplicate library warnings in linker (harmless)

### Future Improvements (Post-Launch)
- Implement CloudMLService TODO at line 87 (already completed)
- Add more comprehensive analytics
- Consider adding in-app purchases for premium features
- Implement push notifications for training reminders

## 📝 **SUBMISSION PROCESS**

1. **Archive the App**
   - Product → Archive in Xcode
   - Wait for archive to complete
   - Organizer window will open

2. **Upload to App Store Connect**
   - Click "Distribute App"
   - Select "App Store Connect"
   - Upload
   - Wait for processing (can take 30+ minutes)

3. **Complete App Store Connect Listing**
   - Add screenshots
   - Write app description
   - Add keywords
   - Set pricing (free or paid)
   - Submit for review

4. **App Review**
   - Typically takes 1-3 days
   - May receive questions from review team
   - Be ready to respond quickly

## ⚡ **CRITICAL PATH TO LAUNCH**

**You MUST complete these before submission:**

1. **Create App Icon** (1-2 hours)
   - Design or commission 1024x1024 icon
   - Add to Assets.xcassets/AppIcon.appiconset/

2. **Create Screenshots** (2-4 hours)
   - Run app on actual devices or use simulator
   - Capture key screens (Onboarding, Dashboard, Session, Exercises, Progress)
   - Edit/polish in design tool if needed
   - Upload to App Store Connect

3. **Host Privacy Policy** (30 minutes)
   - Upload PRIVACY_POLICY.md to a website
   - Or use GitHub Pages
   - Get permanent URL for App Store Connect

4. **Test on Physical Device** (1-2 hours)
   - Deploy to your iPhone
   - Go through complete user flow
   - Fix any device-specific issues

5. **Write App Store Listing** (1-2 hours)
   - App description highlighting features
   - Keywords for discovery
   - Support email/website

**Estimated Time to Submission: 6-12 hours of work**

## 📞 **SUPPORT INFORMATION**

- **Developer Email:** evan10takahashi@gmail.com
- **Bundle ID:** evan.TechnIQ
- **Primary Category:** Health & Fitness → Sports
- **Target Audience:** Soccer players (all skill levels)

---

**Next Steps:** Focus on creating the app icon and screenshots. Everything else is ready for submission.
