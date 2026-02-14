//
//  ContentView.swift
//  TechnIQ
//
//  Created by Evan Takahashi on 6/30/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: AuthenticationManager
    @State private var isOnboardingComplete = false
    
    var body: some View {
        Group {
            if !authManager.isAuthenticated {
                AuthenticationView()
            } else {
                AuthenticatedContentView(isOnboardingComplete: $isOnboardingComplete)
            }
        }
    }
}

struct AuthenticatedContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: AuthenticationManager
    @Binding var isOnboardingComplete: Bool
    
    var body: some View {
        Group {
            if authManager.hasValidUser {
                PlayerContentView(isOnboardingComplete: $isOnboardingComplete)
            } else {
                VStack(spacing: 16) {
                    ProgressView("Loading your profile...")
                        .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.primaryGreen))
                        .scaleEffect(1.5)

                    Text("Setting up your account")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding()
            }
        }
    }
}

struct PlayerContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: AuthenticationManager
    @Binding var isOnboardingComplete: Bool

    @FetchRequest var players: FetchedResults<Player>

    @StateObject private var restoreService = CloudRestoreService.shared
    @State private var isCheckingCloud = false
    @State private var hasCheckedCloud = false
    @State private var restoreError: String?

    init(isOnboardingComplete: Binding<Bool>) {
        self._isOnboardingComplete = isOnboardingComplete

        // Initialize with true predicate to detect if onboarding is needed
        // Will be filtered by firebaseUID in onAppear
        self._players = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Player.createdAt, ascending: false)],
            predicate: NSPredicate(value: true),
            animation: .default
        )
    }

    var body: some View {
        Group {
            if !players.isEmpty {
                // Has local player - show main app
                MainTabView()
            } else if isCheckingCloud || restoreService.isRestoring {
                // Checking cloud or restoring
                CloudRestoreProgressView(
                    isChecking: isCheckingCloud,
                    isRestoring: restoreService.isRestoring,
                    progress: restoreService.restoreProgress
                )
            } else if !hasCheckedCloud {
                // Haven't checked cloud yet - show loading and trigger check
                CloudRestoreProgressView(isChecking: true, isRestoring: false, progress: 0)
                    .onAppear {
                        checkForCloudData()
                    }
            } else if let error = restoreError {
                // Restore failed - show error with retry option
                CloudRestoreErrorView(error: error) {
                    restoreError = nil
                    hasCheckedCloud = false
                }
            } else if !isOnboardingComplete {
                // No local data, no cloud data - show onboarding
                UnifiedOnboardingView(isOnboardingComplete: $isOnboardingComplete)
            } else {
                MainTabView()
            }
        }
        .onAppear {
            updatePlayersFilter()
            if !players.isEmpty {
                isOnboardingComplete = true
            }
        }
        .onChange(of: authManager.userUID) {
            updatePlayersFilter()
            // Reset cloud check state when user changes
            hasCheckedCloud = false
            restoreError = nil
        }
    }

    private func updatePlayersFilter() {
        guard !authManager.userUID.isEmpty else { return }
        players.nsPredicate = NSPredicate(format: "firebaseUID == %@", authManager.userUID)
    }

    private func checkForCloudData() {
        guard !authManager.userUID.isEmpty else {
            hasCheckedCloud = true
            return
        }

        isCheckingCloud = true

        Task {
            do {
                let hasData = await restoreService.hasCloudData()

                if hasData {
                    #if DEBUG
                    print("Cloud data found - starting restore")
                    #endif
                    let _ = try await restoreService.restoreFromCloud()
                    await MainActor.run {
                        isOnboardingComplete = true
                        hasCheckedCloud = true
                        isCheckingCloud = false
                    }
                } else {
                    #if DEBUG
                    print("No cloud data found - showing onboarding")
                    #endif
                    await MainActor.run {
                        hasCheckedCloud = true
                        isCheckingCloud = false
                    }
                }
            } catch {
                #if DEBUG
                print("Cloud restore failed: \(error)")
                #endif
                await MainActor.run {
                    restoreError = error.localizedDescription
                    hasCheckedCloud = true
                    isCheckingCloud = false
                }
            }
        }
    }
}

// MARK: - Cloud Restore Progress View

struct CloudRestoreProgressView: View {
    let isChecking: Bool
    let isRestoring: Bool
    let progress: Double

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "icloud.and.arrow.down")
                .font(.system(size: 60))
                .foregroundColor(DesignSystem.Colors.primaryGreen)
                .symbolEffect(.pulse, options: .repeating)

            VStack(spacing: 12) {
                Text(isRestoring ? "Restoring Your Data" : "Checking for Existing Data")
                    .font(DesignSystem.Typography.headlineMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text(isRestoring ? "Syncing your training history, progress, and settings..." : "Looking for your profile in the cloud...")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if isRestoring {
                VStack(spacing: 8) {
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: DesignSystem.Colors.primaryGreen))
                        .frame(width: 200)

                    Text("\(Int(progress * 100))%")
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.primaryGreen))
                    .scaleEffect(1.2)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.background)
    }
}

// MARK: - Cloud Restore Error View

struct CloudRestoreErrorView: View {
    let error: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.icloud")
                .font(.system(size: 60))
                .foregroundColor(DesignSystem.Colors.accentOrange)

            VStack(spacing: 12) {
                Text("Couldn't Restore Data")
                    .font(DesignSystem.Typography.headlineMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text(error)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button(action: onRetry) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .font(DesignSystem.Typography.bodyMedium.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(DesignSystem.Colors.primaryGreen)
                .cornerRadius(12)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.background)
    }
}

struct MainTabView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: AuthenticationManager

    @FetchRequest var players: FetchedResults<Player>
    @State private var selectedTab = 0

    init() {
        // Fetch all players initially - currentPlayer filters by firebaseUID
        self._players = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Player.createdAt, ascending: false)],
            predicate: NSPredicate(value: true),
            animation: .default
        )
    }

    var currentPlayer: Player? {
        // Filter to authenticated user's player (not just first player)
        guard !authManager.userUID.isEmpty else { return nil }
        return players.first { $0.firebaseUID == authManager.userUID }
    }

    var body: some View {
        VStack(spacing: 0) {
            AnimatedTabContent(selectedTab: $selectedTab) { tab in
                Group {
                    switch tab {
                    case 0:
                        NavigationView { DashboardView(selectedTab: $selectedTab) }
                    case 1:
                        NavigationView { TrainHubView() }
                    case 2:
                        NavigationView { TrainingPlansListView() }
                    case 3:
                        NavigationView { CommunityView() }
                    case 4:
                        NavigationView { EnhancedProfileView() }
                    default:
                        EmptyView()
                    }
                }
                .environment(\.managedObjectContext, viewContext)
                .environmentObject(authManager)
            }

            AnimatedTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard)
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(CoreDataManager.shared)
}
