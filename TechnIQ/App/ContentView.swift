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

    @ObservedObject private var restoreService = CloudService.shared
    @State private var isCheckingCloud = false
    @State private var hasCheckedCloud = false
    @State private var restoreError: String?

    init(isOnboardingComplete: Binding<Bool>) {
        self._isOnboardingComplete = isOnboardingComplete

        // Filter to the current user's players from the first render so a previous account's
        // rows never gate routing. NSPredicate(value: false) until a UID is known; the
        // onAppear/onChange path refreshes this when the UID changes.
        let uid = AuthenticationManager.shared.userUID
        let predicate = uid.isEmpty
            ? NSPredicate(value: false)
            : NSPredicate(format: "firebaseUID == %@", uid)
        self._players = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Player.createdAt, ascending: false)],
            predicate: predicate,
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
        #if DEBUG
        if TQDemoSeed.isRequested {
            // Demo runs never restore from the cloud: seed a local player and go straight in.
            TQDemoSeed.ensurePlayer(uid: authManager.userUID, context: viewContext)
            hasCheckedCloud = true
            return
        }
        #endif

        isCheckingCloud = true

        Task {
            do {
                let hasData = await restoreService.hasCloudDataForRestore()

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
    @State private var selectedTab = MainTabView.initialTab

    /// `-TQTab n` (DEBUG) opens the app on a given tab for screenshot comparison.
    private static var initialTab: Int {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "-TQTab"), index + 1 < args.count, let tab = Int(args[index + 1]), (0..<5).contains(tab) {
            return tab
        }
        #endif
        return 0
    }

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
        ZStack {
            DesignSystem.Colors.surfaceBase.ignoresSafeArea()
            VStack(spacing: 0) {
                AnimatedTabContent(selectedTab: $selectedTab) { tab in
                    Group {
                        switch tab {
                        case 0:
                            NavigationStack { DashboardView(selectedTab: $selectedTab) }
                        case 1:
                            NavigationStack { TrainHubView() }
                        case 2:
                            NavigationStack { TrainingPlansListView() }
                        case 3:
                            NavigationStack { CommunityView() }
                        case 4:
                            NavigationStack { EnhancedProfileView() }
                        default:
                            EmptyView()
                        }
                    }
                    .environment(\.managedObjectContext, viewContext)
                    .environmentObject(authManager)
                }

                TQTabBar(selectedTab: $selectedTab)
                    .ignoresSafeArea(.keyboard)
            }
        }
        #if DEBUG
        .onAppear {
            if TQDemoSeed.isRequested, let player = currentPlayer {
                TQDemoSeed.apply(to: player, context: viewContext)
            }
        }
        #endif
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(CoreDataManager.shared)
}
