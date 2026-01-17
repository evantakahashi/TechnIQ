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
        TabView(selection: $selectedTab) {
            // Tab 0: Home
            NavigationView {
                DashboardView(selectedTab: $selectedTab)
            }
            .tabItem {
                Image(systemName: DesignSystem.Icons.home)
                Text("Home")
            }
            .tag(0)

            // Tab 1: Train (Sessions + Exercises combined)
            NavigationView {
                TrainHubView()
            }
            .tabItem {
                Image(systemName: "figure.run")
                Text("Train")
            }
            .tag(1)

            // Tab 2: Plans
            NavigationView {
                TrainingPlansListView()
            }
            .tabItem {
                Image(systemName: "calendar.badge.clock")
                Text("Plans")
            }
            .tag(2)

            // Tab 3: Matches (prominent for match reflections)
            NavigationView {
                if let player = currentPlayer {
                    MatchHistoryView(player: player)
                } else {
                    SwiftUI.ProgressView("Loading...")
                }
            }
            .tabItem {
                Image(systemName: "sportscourt.fill")
                Text("Matches")
            }
            .tag(3)

            // Tab 4: You (Profile hub with Progress accessible inside)
            NavigationView {
                EnhancedProfileView()
            }
            .tabItem {
                Image(systemName: DesignSystem.Icons.profile)
                Text("You")
            }
            .tag(4)
        }
        .accentColor(DesignSystem.Colors.primaryGreen)
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(CoreDataManager.shared)
}
