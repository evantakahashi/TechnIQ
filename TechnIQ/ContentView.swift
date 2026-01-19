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
            if players.isEmpty && !isOnboardingComplete {
                EnhancedOnboardingView(isOnboardingComplete: $isOnboardingComplete)
            } else {
                MainTabView()
            }
        }
        .onAppear {
            updatePlayersFilter()
            isOnboardingComplete = !players.isEmpty
        }
        .onChange(of: authManager.userUID) {
            updatePlayersFilter()
        }
    }
    
    private func updatePlayersFilter() {
        guard !authManager.userUID.isEmpty else { return }
        
        players.nsPredicate = NSPredicate(format: "firebaseUID == %@", authManager.userUID)
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
