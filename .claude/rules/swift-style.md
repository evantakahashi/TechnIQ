---
paths:
  - "TechnIQ/**/*.swift"
---

# Swift/SwiftUI Style

- Use `DesignSystem` constants for all colors, spacing, typography — never hardcode values
- Use `ModernCard`, `ModernButton` component library for UI elements
- Use `EmptyStateView`/`ErrorStateView`/`LoadingStateView` for data-driven views
- Guard print statements with `#if DEBUG`; use `AppLogger.shared` for production logging
- Safe optional unwrapping — no force unwraps on Core Data optionals
- Bounds checks before array subscript access
- `@MainActor` required on any service accessing `viewContext`
