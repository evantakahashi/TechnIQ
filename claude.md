# TechnIQ Development Guidelines

## About TechnIQ
TechnIQ is an AI-powered soccer training app for iOS that helps players improve their skills through:
- **AI-Generated Training Plans**: Personalized multi-week programs using Vertex AI/Gemini
- **Smart Exercise Library**: 45+ pre-built exercises with YouTube integration
- **Session Tracking**: Record training sessions with notes, ratings, and progress analytics
- **Custom Drill Creator**: Manual and AI-powered drill generation
- **Cloud Sync**: Firebase-backed profile and data synchronization
- **Analytics Dashboard**: Skill trends, session history, and performance insights

**Tech Stack**: SwiftUI, Core Data, Firebase (Auth, Firestore, Functions), Google Sign-In, Vertex AI

---

## Development Workflow

### 1. Plan First
- Read relevant files to understand current implementation
- Create a detailed plan in `tasks/todo.md` with:
  - Clear, actionable todo items
  - Build/test verification steps
  - Notes about files that will be modified
- **Wait for approval before proceeding**

### 2. Incremental Implementation
- Use the **TodoWrite** tool to track progress throughout implementation
- Mark tasks as `in_progress` before starting, `completed` when done
- Only work on ONE task at a time
- Build and test after each significant change

### 3. Communication
- Provide **high-level explanations** of changes (not line-by-line details)
- Reference code locations with `file_path:line_number` format
- Example: "Added AI generation in CloudMLService.swift:363"

### 4. Simplicity First
- Make minimal, targeted changes
- Avoid refactoring existing code unless necessary
- Prefer editing existing files over creating new ones
- Keep each change isolated to as few files as possible

### 5. Documentation
- Add a **Review** section to `tasks/todo.md` when done with:
  - Summary of changes
  - Files modified/created
  - Testing notes
  - Any outstanding issues or next steps

---

## TechnIQ-Specific Guidelines

### Code Quality
- **Never commit**:
  - API keys, credentials, or secrets (use Info.plist with env vars)
  - Debug print statements in production code
  - Backup files (*.backup, *.backup2)
  - Build artifacts or logs
- **Always use**:
  - `#if DEBUG` guards for debug print statements
  - AppLogger.shared for production logging
  - DesignSystem constants for colors, spacing, typography
  - Modern SwiftUI patterns (@StateObject, @Environment, async/await)

### Architecture Patterns
- **Core Data**: All persistent data (Player, Session, Exercise, TrainingPlan)
- **Firebase**: Authentication, cloud sync, AI Functions
- **Services**: CloudMLService, TrainingPlanService, CustomDrillService, YouTubeAPIService
- **Views**: Follow existing ModernCard, ModernButton, DesignSystem patterns

### Build & Testing
- **Always build** after making changes: `xcodebuild -scheme TechnIQ -sdk iphonesimulator`
- Test on **simulator first**, then physical device when needed
- Fix all compiler errors and warnings before committing
- Verify Core Data schema changes don't break existing data

### Firebase Integration
- AI Functions deployed to: `https://us-central1-techniq-b9a27.cloudfunctions.net/`
- Always check authentication state before Firebase calls
- Handle offline scenarios gracefully
- Use proper error messages for user-facing failures

### Git Commits
- Use descriptive commit messages
- Include Claude Code footer (automatically added by `/commit` command)
- Stage only relevant files (exclude backups, logs, user settings)
- Push to `main` branch after successful builds

---

## Quick Reference

### Key Files
- **App Entry**: `TechnIQApp.swift`
- **Main View**: `ContentView.swift`
- **Core Data**: `CoreDataManager.swift`, `DataModel.xcdatamodeld`
- **Services**: `CloudMLService.swift`, `TrainingPlanService.swift`, `CustomDrillService.swift`
- **Design System**: `DesignSystem.swift`
- **Exercise Library**: `TemplateExerciseLibrary.swift` (45+ exercises)

### Common Tasks
- **Commit & Push**: Use `/commit` slash command
- **Check Todo List**: Read `tasks/todo.md`
- **Build App**: `xcodebuild -scheme TechnIQ -sdk iphonesimulator`
- **View Git Status**: `git status`

### Testing Checklist
- [ ] App builds without errors or warnings
- [ ] Feature works on iOS simulator
- [ ] Core Data changes don't corrupt existing data
- [ ] Firebase calls handle auth failures gracefully
- [ ] UI follows DesignSystem patterns
- [ ] No debug print statements in committed code

---

## Remember
- **Plan → Approve → Implement → Test → Review**
- Keep changes simple and minimal
- Use TodoWrite tool to track progress
- Build frequently to catch errors early
- Ask before making architectural changes
