import SwiftUI

/// View displayed after completing a training session
/// Shows XP earned, level ups, achievements, and streak updates
struct SessionCompleteView: View {
    let xpBreakdown: XPService.SessionXPBreakdown?
    let newLevel: Int?
    let achievements: [Achievement]
    let player: Player
    let onDismiss: () -> Void

    @State private var animateXP = false
    @State private var animateLevel = false
    @State private var animateAchievements = false
    @State private var showConfetti = false
    @StateObject private var aiCoachService = AICoachService.shared
    @State private var showingWeeklyCheckIn = false
    @State private var showingShareSheet = false

    /// Determine if this is a big celebration (level up or achievements)
    private var isBigCelebration: Bool {
        newLevel != nil || !achievements.isEmpty
    }

    /// Mascot state based on celebration type
    private var mascotState: MascotState {
        if newLevel != nil {
            return .proud
        } else if !achievements.isEmpty {
            return .excited
        } else {
            return .happy
        }
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    DesignSystem.Colors.primaryGreen.opacity(0.1),
                    DesignSystem.Colors.background
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Header with Mascot
                    headerSection

                    // XP Breakdown Card
                    if let breakdown = xpBreakdown {
                        xpBreakdownCard(breakdown)
                    }

                    // Level Up Card
                    if let level = newLevel {
                        levelUpCard(level)
                    }

                    // Achievements Card
                    if !achievements.isEmpty {
                        achievementsCard
                    }

                    // Streak Update
                    streakCard

                    // Weekly Check-In Card
                    if aiCoachService.weeklyCheckInAvailable {
                        weeklyCheckInCard
                    }

                    // Continue Button
                    continueButton

                    // Share to Community
                    Button {
                        showingShareSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share to Community")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(DesignSystem.Colors.primaryGreen.opacity(0.12))
                        .cornerRadius(DesignSystem.CornerRadius.button)
                    }
                    .opacity(animateAchievements ? 1 : 0)
                }
                .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                .padding(.vertical, DesignSystem.Spacing.xl)
            }

            // Confetti overlay for big celebrations
            if showConfetti && isBigCelebration {
                ConfettiView(particleCount: 60, duration: 4.0)
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            // Trigger haptic for session completion
            HapticManager.shared.sessionComplete()

            // Start confetti for big celebrations
            if isBigCelebration {
                showConfetti = true
            }

            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                animateXP = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3)) {
                animateLevel = true
                if newLevel != nil {
                    HapticManager.shared.levelUp()
                }
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.5)) {
                animateAchievements = true
                if !achievements.isEmpty {
                    HapticManager.shared.achievementUnlocked()
                }
            }
        }
        .sheet(isPresented: $showingWeeklyCheckIn) {
            WeeklyCheckInView(weekNumber: aiCoachService.completedWeekNumber, player: player)
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareToCommunitySheet(
                shareType: .session(
                    duration: Int(xpBreakdown?.baseXP ?? 0) / 2,
                    exerciseCount: 0,
                    rating: 0,
                    xp: Int(xpBreakdown?.total ?? 0)
                ),
                player: player,
                onDismiss: { showingShareSheet = false }
            )
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Mascot
            MascotView(state: mascotState, size: .large)
                .scaleEffect(animateXP ? 1 : 0.5)
                .opacity(animateXP ? 1 : 0)

            // Checkmark badge overlay
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(DesignSystem.Colors.successGreen)
                .background(Circle().fill(Color.white).frame(width: 36, height: 36))
                .offset(x: 40, y: -30)
                .scaleEffect(animateXP ? 1 : 0)
                .opacity(animateXP ? 1 : 0)

            Text("Session Complete!")
                .font(DesignSystem.Typography.headlineLarge)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .opacity(animateXP ? 1 : 0)

            Text(celebrationMessage)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .opacity(animateXP ? 1 : 0)
        }
        .padding(.top, DesignSystem.Spacing.xl)
    }

    /// Dynamic celebration message based on what was achieved
    private var celebrationMessage: String {
        if newLevel != nil && !achievements.isEmpty {
            return "Amazing! Level up AND new achievements!"
        } else if newLevel != nil {
            return "You leveled up! Keep pushing!"
        } else if !achievements.isEmpty {
            return "New achievement unlocked!"
        } else {
            return "Great work on your training!"
        }
    }

    // MARK: - XP Breakdown Card

    private func xpBreakdownCard(_ breakdown: XPService.SessionXPBreakdown) -> some View {
        ModernCard(padding: DesignSystem.Spacing.lg) {
            VStack(spacing: DesignSystem.Spacing.md) {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(DesignSystem.Colors.accentYellow)
                    Text("XP Earned")
                        .font(DesignSystem.Typography.titleMedium)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Spacer()
                    Text("+\(breakdown.total)")
                        .font(DesignSystem.Typography.headlineMedium)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                }

                Divider()

                VStack(spacing: DesignSystem.Spacing.sm) {
                    xpRow("Session Base", value: breakdown.baseXP)

                    if breakdown.intensityBonus > 0 {
                        xpRow("Intensity Bonus", value: breakdown.intensityBonus)
                    }

                    if breakdown.firstSessionBonus > 0 {
                        xpRow("First Session of Day", value: breakdown.firstSessionBonus)
                    }

                    if breakdown.completionBonus > 0 {
                        xpRow("All Exercises Done", value: breakdown.completionBonus)
                    }

                    if breakdown.ratingBonus > 0 {
                        xpRow("Session Rated", value: breakdown.ratingBonus)
                    }

                    if breakdown.notesBonus > 0 {
                        xpRow("Notes Added", value: breakdown.notesBonus)
                    }

                    if breakdown.streakBonus > 0 {
                        xpRow("Streak Bonus!", value: breakdown.streakBonus, highlight: true)
                    }
                }
            }
        }
        .scaleEffect(animateXP ? 1 : 0.9)
        .opacity(animateXP ? 1 : 0)
    }

    private func xpRow(_ label: String, value: Int32, highlight: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(highlight ? DesignSystem.Colors.accentOrange : DesignSystem.Colors.textSecondary)
            Spacer()
            Text("+\(value)")
                .font(DesignSystem.Typography.labelLarge)
                .fontWeight(highlight ? .bold : .medium)
                .foregroundColor(highlight ? DesignSystem.Colors.accentOrange : DesignSystem.Colors.textPrimary)
        }
    }

    // MARK: - Level Up Card

    private func levelUpCard(_ level: Int) -> some View {
        ModernCard(padding: DesignSystem.Spacing.lg) {
            VStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(DesignSystem.Colors.secondaryBlue)

                Text("Level Up!")
                    .font(DesignSystem.Typography.headlineMedium)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text("You're now level \(level)")
                    .font(DesignSystem.Typography.bodyLarge)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                if let tier = XPService.shared.tierForLevel(level) {
                    Text(tier.title)
                        .font(DesignSystem.Typography.titleMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.secondaryBlue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(DesignSystem.Colors.secondaryBlue.opacity(0.15))
                        .cornerRadius(20)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .stroke(DesignSystem.Colors.secondaryBlue, lineWidth: 2)
        )
        .scaleEffect(animateLevel ? 1 : 0.9)
        .opacity(animateLevel ? 1 : 0)
    }

    // MARK: - Achievements Card

    private var achievementsCard: some View {
        ModernCard(padding: DesignSystem.Spacing.lg) {
            VStack(spacing: DesignSystem.Spacing.md) {
                HStack {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(DesignSystem.Colors.accentYellow)
                    Text("Achievements Unlocked!")
                        .font(DesignSystem.Typography.titleMedium)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Spacer()
                }

                ForEach(achievements, id: \.id) { achievement in
                    HStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: achievement.icon)
                            .font(.system(size: 24))
                            .foregroundColor(DesignSystem.Colors.primaryGreen)
                            .frame(width: 40)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(achievement.name)
                                .font(DesignSystem.Typography.bodyMedium)
                                .fontWeight(.semibold)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            Text(achievement.description)
                                .font(DesignSystem.Typography.labelSmall)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, DesignSystem.Spacing.xs)
                }
            }
        }
        .scaleEffect(animateAchievements ? 1 : 0.9)
        .opacity(animateAchievements ? 1 : 0)
    }

    // MARK: - Streak Card

    private var streakCard: some View {
        ModernCard(padding: DesignSystem.Spacing.lg) {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 30))
                    .foregroundColor(DesignSystem.Colors.accentOrange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(player.currentStreak) Day Streak")
                        .font(DesignSystem.Typography.titleMedium)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Text("Keep it going!")
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Best")
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Text("\(player.longestStreak)")
                        .font(DesignSystem.Typography.titleMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.accentOrange)
                }
            }
        }
        .opacity(animateXP ? 1 : 0)
    }

    // MARK: - Weekly Check-In Card

    private var weeklyCheckInCard: some View {
        ModernCard(padding: DesignSystem.Spacing.lg) {
            VStack(spacing: DesignSystem.Spacing.md) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(DesignSystem.Colors.accentYellow)
                    Text("Week \(aiCoachService.completedWeekNumber) Complete!")
                        .font(DesignSystem.Typography.titleMedium)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Spacer()
                }

                Text("Your AI coach has reviewed your performance and may have suggestions for next week.")
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                ModernButton("See AI Review", icon: "sparkles", style: .secondary) {
                    showingWeeklyCheckIn = true
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .stroke(DesignSystem.Colors.accentYellow.opacity(0.3), lineWidth: 1.5)
        )
        .scaleEffect(animateAchievements ? 1 : 0.9)
        .opacity(animateAchievements ? 1 : 0)
    }

    // MARK: - Continue Button

    private var continueButton: some View {
        Button(action: onDismiss) {
            Text("Continue")
                .font(DesignSystem.Typography.labelLarge)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(DesignSystem.Colors.primaryGreen)
                .cornerRadius(DesignSystem.CornerRadius.button)
        }
        .padding(.top, DesignSystem.Spacing.md)
        .opacity(animateAchievements ? 1 : 0)
    }
}

// Preview disabled - requires Core Data context
// To preview, use the app simulator
