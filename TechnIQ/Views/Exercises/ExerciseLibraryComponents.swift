import SwiftUI
import CoreData

// MARK: - Shared Exercise Preview Views

struct ExerciseYouTubePreview: View {
    let exercise: Exercise
    var height: CGFloat = 100

    var body: some View {
        if let videoId = exercise.videoId {
            AsyncImage(url: URL(string: "https://img.youtube.com/vi/\(videoId)/medium.jpg")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: height)
                    .clipped()
                    .overlay(
                        ZStack {
                            Color.black.opacity(0.2)
                            Image(systemName: "play.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                        }
                    )
            } placeholder: {
                Rectangle()
                    .fill(Color.red.opacity(0.2))
                    .overlay(ProgressView())
            }
        } else {
            Rectangle()
                .fill(Color.red.opacity(0.2))
                .overlay(
                    Image(systemName: "play.rectangle.fill")
                        .font(.title)
                        .foregroundColor(.red)
                )
        }
    }
}

struct ExerciseIconPreview: View {
    let exercise: Exercise
    var iconSize: CGFloat = 32

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [exercise.categoryColor.opacity(0.3), exercise.categoryColor.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: exercise.categoryIcon)
                    .font(.system(size: iconSize))
                    .foregroundColor(exercise.categoryColor)
            )
    }
}

struct ExerciseTypeBadge: View {
    let exercise: Exercise

    var body: some View {
        if exercise.isAIGenerated {
            HStack(spacing: 4) {
                Image(systemName: "brain.head.profile")
                    .font(.caption2)
                Text("AI Generated")
                    .font(DesignSystem.Typography.labelSmall)
            }
            .foregroundColor(DesignSystem.Colors.primaryGreen)
        } else if exercise.isYouTubeExercise {
            HStack(spacing: 4) {
                Image(systemName: "play.rectangle.fill")
                    .font(.caption2)
                Text("YouTube")
                    .font(DesignSystem.Typography.labelSmall)
            }
            .foregroundColor(.red)
        } else {
            CategoryBadge(category: exercise.category ?? "General")
        }
    }
}

// MARK: - Recommended Exercise Card (Larger, with match % and reason)

struct RecommendedExerciseCard: View {
    let exercise: Exercise
    let matchPercentage: Int
    let reason: String

    var body: some View {
        ModernCard(padding: 0) {
            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    if exercise.isYouTubeExercise {
                        ExerciseYouTubePreview(exercise: exercise, height: 120)
                    } else {
                        ExerciseIconPreview(exercise: exercise, iconSize: 40)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                        Text("\(matchPercentage)%")
                            .font(DesignSystem.Typography.labelSmall)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, 4)
                    .background(DesignSystem.Colors.primaryGreen)
                    .cornerRadius(DesignSystem.CornerRadius.sm)
                    .padding(DesignSystem.Spacing.sm)
                }
                .frame(height: 120)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text(exercise.name ?? "Unknown Exercise")
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(reason)
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack {
                        CategoryBadge(category: exercise.category ?? "General")
                        Spacer()
                        SimpleDifficultyIndicator(level: Int(exercise.difficulty))
                    }
                }
                .padding(DesignSystem.Spacing.md)
            }
        }
        .frame(width: 260, height: 230)
    }
}

// MARK: - Simple Exercise Card (Smaller, for category sections)

struct SimpleExerciseCard: View {
    let exercise: Exercise
    var isFavorite: Bool = false
    var onFavoriteToggle: (() -> Void)? = nil

    var body: some View {
        ModernCard(padding: 0) {
            VStack(spacing: 0) {
                ZStack {
                    if exercise.isYouTubeExercise {
                        ExerciseYouTubePreview(exercise: exercise)
                    } else {
                        ExerciseIconPreview(exercise: exercise)
                    }
                }
                .frame(height: 100)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    ExerciseTypeBadge(exercise: exercise)

                    Text(exercise.name ?? "Unknown Exercise")
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    SimpleDifficultyIndicator(level: Int(exercise.difficulty))
                }
                .padding(DesignSystem.Spacing.sm)
            }
        }
        .frame(width: 160, height: 180)
        .overlay(alignment: .topTrailing) {
            if onFavoriteToggle != nil {
                Button {
                    onFavoriteToggle?()
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isFavorite ? .red : .white)
                        .padding(6)
                        .background(Color.black.opacity(0.4))
                        .clipShape(Circle())
                }
                .padding(8)
            }
        }
    }
}

// MARK: - Favorite Exercise Card

struct FavoriteExerciseCard: View {
    let exercise: Exercise
    let onFavoriteToggle: () -> Void

    var body: some View {
        ModernCard(padding: 0) {
            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    if exercise.isYouTubeExercise, let videoId = exercise.videoId {
                        AsyncImage(url: URL(string: "https://img.youtube.com/vi/\(videoId)/medium.jpg")) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle().fill(Color.red.opacity(0.3))
                        }
                    } else {
                        ExerciseIconPreview(exercise: exercise, iconSize: 30)
                    }

                    Button {
                        onFavoriteToggle()
                    } label: {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.red)
                            .padding(8)
                            .background(Color.white.opacity(0.9))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    }
                    .padding(8)
                }
                .frame(height: 100)
                .clipped()

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    ExerciseTypeBadge(exercise: exercise)

                    Text(exercise.name ?? "Unknown Exercise")
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    SimpleDifficultyIndicator(level: Int(exercise.difficulty))
                }
                .padding(DesignSystem.Spacing.sm)
            }
        }
        .frame(width: 160, height: 180)
    }
}

// MARK: - Simple Difficulty Indicator

struct SimpleDifficultyIndicator: View {
    let level: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...3, id: \.self) { index in
                Circle()
                    .fill(index <= level ? difficultyColor : Color.gray.opacity(0.2))
                    .frame(width: 6, height: 6)
            }
        }
    }

    private var difficultyColor: Color {
        switch level {
        case 1: return DesignSystem.Colors.primaryGreen
        case 2: return DesignSystem.Colors.accentOrange
        default: return .red
        }
    }
}

// MARK: - Simple Loading Overlay

struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.md) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.primaryGreen))
                    .scaleEffect(1.5)

                Text("Loading YouTube videos...")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
            .padding(DesignSystem.Spacing.xl)
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.card)
            .customShadow(DesignSystem.Shadow.medium)
        }
    }
}

// MARK: - List Exercise Card (for list view mode)

struct ListExerciseCard: View {
    let exercise: Exercise
    let onFavoriteToggle: () -> Void

    var body: some View {
        ModernCard(padding: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.md) {
                ZStack {
                    if exercise.isYouTubeExercise, let videoId = exercise.videoId {
                        AsyncImage(url: URL(string: "https://img.youtube.com/vi/\(videoId)/default.jpg")) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle().fill(Color.red.opacity(0.2))
                        }
                    } else {
                        Rectangle()
                            .fill(exercise.categoryColor.opacity(0.2))
                            .overlay(
                                Image(systemName: exercise.categoryIcon)
                                    .font(.title3)
                                    .foregroundColor(exercise.categoryColor)
                            )
                    }
                }
                .frame(width: 60, height: 60)
                .cornerRadius(DesignSystem.CornerRadius.sm)
                .clipped()

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        if exercise.isAIGenerated {
                            Image(systemName: "brain.head.profile").font(.caption2)
                                .foregroundColor(DesignSystem.Colors.primaryGreen)
                            Text("AI").font(.caption2)
                                .foregroundColor(DesignSystem.Colors.primaryGreen)
                        } else if exercise.isYouTubeExercise {
                            Image(systemName: "play.rectangle.fill").font(.caption2)
                                .foregroundColor(.red)
                            Text("YouTube").font(.caption2)
                                .foregroundColor(.red)
                        } else {
                            Text(exercise.category ?? "General").font(.caption2)
                                .foregroundColor(exercise.categoryColor)
                        }
                        Spacer()
                        SimpleDifficultyIndicator(level: Int(exercise.difficulty))
                    }

                    Text(exercise.name ?? "Unknown Exercise")
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)

                    if let skills = exercise.targetSkills, !skills.isEmpty {
                        Text(skills.prefix(3).joined(separator: " • "))
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                            .lineLimit(1)
                    }
                }

                Button {
                    onFavoriteToggle()
                } label: {
                    Image(systemName: exercise.isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 18))
                        .foregroundColor(exercise.isFavorite ? .red : DesignSystem.Colors.textSecondary)
                }
            }
        }
    }

}

// MARK: - Filter Chip (for showing active filters)

struct FilterChip: View {
    let text: String
    let color: Color
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(DesignSystem.Typography.labelSmall)
                .foregroundColor(color)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(color.opacity(0.7))
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                .fill(color.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}
