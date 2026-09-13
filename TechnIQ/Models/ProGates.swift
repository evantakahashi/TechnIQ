import Foundation

// MARK: - ProGates
//
// The free tier in one place, so every gate and every label agree:
//   free  — the onboarding plan (one AI plan), template and manual drills, 3 AI drills for life,
//           community, progress, reminders
//   Pro   — AI drills beyond the three, the coach's daily pick and cue, the weekly review with
//           plan changes, further AI plans
// Pure so the rules can be unit-tested; views ask these and never re-derive them.

enum ProGates {
    /// Every gated feature, for labels and the paywall's context copy.
    enum Feature: CaseIterable {
        case aiDrills, dailyCoaching, weeklyReview, aiPlans

        var title: String {
            switch self {
            case .aiDrills: return "More AI drills"
            case .dailyCoaching: return "Daily pick and cue"
            case .weeklyReview: return "Weekly review"
            case .aiPlans: return "New AI plans"
            }
        }

        var detail: String {
            switch self {
            case .aiDrills: return "Every drill you ask for, with its diagram, beyond your three free ones."
            case .dailyCoaching: return "Your coach picks today's drill from your library and gives you one cue."
            case .weeklyReview: return "A recap of the week and changes to next week you can accept one by one."
            case .aiPlans: return "Build a new plan whenever the season changes; your first is free."
            }
        }
    }

    /// AI plans: the first one (onboarding or the generator) is free, more need Pro.
    static func canGeneratePlan(isPro: Bool, existingAIPlans: Int) -> Bool {
        isPro || existingAIPlans == 0
    }

    /// AI drills: three for life, then Pro.
    static func canGenerateDrill(isPro: Bool, freeDrillsRemaining: Int) -> Bool {
        isPro || freeDrillsRemaining > 0
    }

    /// The tag to show on a row before the tap: nil when the tap is free.
    static func drillGateLabel(isPro: Bool, freeDrillsRemaining: Int) -> String? {
        guard !isPro else { return nil }
        switch freeDrillsRemaining {
        case 0: return "Pro"
        case 1: return "1 free left"
        default: return "\(freeDrillsRemaining) free left"
        }
    }

    static func planGateLabel(isPro: Bool, existingAIPlans: Int) -> String? {
        guard !isPro else { return nil }
        return existingAIPlans == 0 ? "First one free" : "Pro"
    }
}
