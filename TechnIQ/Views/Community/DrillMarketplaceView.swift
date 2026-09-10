import SwiftUI
import CoreData

// MARK: - Community drills (Touchline 6b)
//
// "DRILL OF THE WEEK" pitch card (most-saved drill from the last seven days, else all-time) with
// Add to my drills / Preview, a chip row (Trending · New · Technical · Tactical · Physical), then
// flat rows with the author, level, minutes and a saves count.

struct DrillMarketplaceView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: AuthenticationManager
    @ObservedObject private var communityService = CommunityService.shared
    @FetchRequest var players: FetchedResults<Player>

    @State private var chip: Chip = .trending
    @State private var selectedDrill: SharedDrill?
    @State private var notice: String?
    @State private var isSavingFeatured = false

    enum Chip: String, CaseIterable, Identifiable {
        case trending = "Trending", new = "New", technical = "Technical", tactical = "Tactical", physical = "Physical"
        var id: String { rawValue }

        var category: String? {
            switch self {
            case .technical, .tactical, .physical: return rawValue.lowercased()
            default: return nil
            }
        }
    }

    init() {
        self._players = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Player.createdAt, ascending: false)],
            predicate: NSPredicate(value: true),
            animation: .default
        )
    }

    private var currentPlayer: Player? {
        guard !authManager.userUID.isEmpty else { return nil }
        return players.first { $0.firebaseUID == authManager.userUID }
    }

    // MARK: Derived

    private var visibleDrills: [SharedDrill] {
        let drills = communityService.sharedDrills.filter { !$0.isHidden }
        switch chip {
        case .trending: return drills.sorted { $0.saveCount > $1.saveCount }
        case .new: return drills.sorted { $0.timestamp > $1.timestamp }
        case .technical, .tactical, .physical:
            return drills.filter { $0.category.lowercased() == chip.category }.sorted { $0.saveCount > $1.saveCount }
        }
    }

    /// Most-saved drill shared in the last seven days; falls back to the most-saved overall.
    private var drillOfTheWeek: SharedDrill? {
        let drills = communityService.sharedDrills.filter { !$0.isHidden }
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recent = drills.filter { $0.timestamp >= weekAgo }
        return (recent.isEmpty ? drills : recent).max { $0.saveCount < $1.saveCount }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
                if let notice {
                    TQBanner(.info, message: notice, actionTitle: "OK") { self.notice = nil }
                }

                if let featured = drillOfTheWeek {
                    featuredCard(featured)
                }

                TQChipRow {
                    ForEach(Chip.allCases) { option in
                        TQChip(option.rawValue, isSelected: chip == option) {
                            withAnimation(DesignSystem.Animation.quick) { chip = option }
                            Task { await communityService.fetchSharedDrills(refresh: true, category: option.category) }
                        }
                    }
                }

                if communityService.isLoadingDrills && communityService.sharedDrills.isEmpty {
                    TQRowList {
                        ForEach(0..<4, id: \.self) { _ in
                            HStack(spacing: 12) {
                                TQSkeleton(width: 42, height: 42, cornerRadius: DesignSystem.CornerRadius.tile)
                                VStack(alignment: .leading, spacing: 6) {
                                    TQSkeleton(widthFraction: 0.6, height: 14, cornerRadius: 4)
                                    TQSkeleton(widthFraction: 0.4, height: 10)
                                }
                            }
                            .padding(.vertical, DesignSystem.Spacing.rowVertical)
                            .overlay(alignment: .bottom) { TQRule() }
                        }
                    }
                } else if visibleDrills.isEmpty {
                    TQRowList {
                        TQRow("No shared drills yet", note: "be the first to post one").disabled(true)
                    }
                } else {
                    TQRowList {
                        ForEach(visibleDrills) { drill in
                            TQRow(
                                drill.title,
                                subtitle: "\(CommunityService.displayName(for: drill.authorName)) · Lvl \(max(drill.difficulty, 1)) · \(drill.duration) min",
                                leading: .tile(TQTile.category(drill.category)),
                                accessory: .saves(drill.saveCount),
                                verticalPadding: DesignSystem.Spacing.rowVertical,
                                action: { selectedDrill = drill }
                            )
                            .onAppear {
                                if drill.id == visibleDrills.last?.id {
                                    Task { await communityService.fetchSharedDrills(category: chip.category) }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.bottom, DesignSystem.Spacing.lg)
        }
        .refreshable {
            await communityService.fetchSharedDrills(refresh: true, category: chip.category)
        }
        .onAppear {
            updatePlayersFilter()
            if communityService.sharedDrills.isEmpty {
                Task { await communityService.fetchSharedDrills(refresh: true) }
            }
        }
        .sheet(item: $selectedDrill) { drill in
            SharedDrillDetailView(drill: drill)
        }
    }

    // MARK: - Drill of the week

    private func featuredCard(_ drill: SharedDrill) -> some View {
        TQPitchCard(.card, markings: .box) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    TQEyebrow("Drill of the week", size: 11)
                    Spacer()
                    TQMeta("\(savesLabel(drill.saveCount)) saves", tone: .onPitch, size: 13, weight: .regular)
                }
                VStack(alignment: .leading, spacing: 4) {
                    TQDisplayTitle(drill.title, size: .card)
                    Text("by \(CommunityService.displayName(for: drill.authorName)) · \(drill.category.capitalized) · Lvl \(max(drill.difficulty, 1)) · \(drill.duration) min")
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textOnPitch)
                        .lineLimit(1)
                }
                HStack(spacing: 8) {
                    TQButton(drill.isSavedByCurrentUser ? "In my drills" : "Add to my drills", size: .compact, isLoading: isSavingFeatured, fullWidth: false) {
                        saveToLibrary(drill)
                    }
                    .disabled(drill.isSavedByCurrentUser)
                    Button {
                        HapticManager.shared.selectionChanged()
                        selectedDrill = drill
                    } label: {
                        Text("Preview")
                            .font(Font.system(size: 14, weight: .semibold).width(.condensed))
                            .textCase(.uppercase)
                            .tracking(0.6)
                            .foregroundColor(DesignSystem.Colors.chalkWhite)
                            .padding(.horizontal, 14)
                            .frame(height: 44)
                            .overlay(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous).strokeBorder(DesignSystem.Colors.chalkWhite.opacity(0.3), lineWidth: 1))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func savesLabel(_ count: Int) -> String {
        count >= 1000 ? String(format: "%.1fK", Double(count) / 1000).replacingOccurrences(of: ".0K", with: "K") : "\(count)"
    }

    private func saveToLibrary(_ drill: SharedDrill) {
        guard let player = currentPlayer else { notice = "Sign in to save drills."; return }
        isSavingFeatured = true
        Task {
            do {
                try await communityService.saveDrillToLibrary(drill: drill, player: player, context: viewContext)
                notice = "\"\(drill.title)\" added to your drills."
                HapticManager.shared.success()
            } catch {
                notice = "Couldn't save that drill. Try again."
            }
            isSavingFeatured = false
        }
    }

    private func updatePlayersFilter() {
        guard !authManager.userUID.isEmpty else { return }
        players.nsPredicate = NSPredicate(format: "firebaseUID == %@", authManager.userUID)
    }
}
