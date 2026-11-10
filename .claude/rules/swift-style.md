---
paths:
  - "TechnIQ/**/*.swift"
---

# Swift/SwiftUI Style

- Use `DesignSystem` constants for all colors, spacing, typography — never hardcode values
- Compose screens only from `Components/Touchline/TQ*` (no ad-hoc cards, shadows, gradients, pills or extra accent colours); empty/loading states are a left-aligned `TQDisplayTitle` + `TQBody` (+ `TQButton`) or `TQSkeleton`
- Guard print statements with `#if DEBUG`; use `AppLogger.shared` for production logging
- Safe optional unwrapping — no force unwraps on Core Data optionals
- Bounds checks before array subscript access
- `@MainActor` required on any service accessing `viewContext`
