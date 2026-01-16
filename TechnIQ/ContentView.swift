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
        // Initialize with false predicate - will be updated in onAppear with correct firebaseUID
        self._players = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Player.createdAt, ascending: false)],
            predicate: NSPredicate(value: false), // Empty initially, filtered in onAppear
            animation: .default
        )
    }

    var currentPlayer: Player? {
        players.first
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                DashboardView(selectedTab: $selectedTab)
            }
            .tabItem {
                Image(systemName: DesignSystem.Icons.home)
                Text("Home")
            }
            .tag(0)

            NavigationView {
                SessionHistoryView()
            }
            .tabItem {
                Image(systemName: DesignSystem.Icons.sessions)
                Text("Sessions")
            }
            .tag(1)

            NavigationView {
                if let player = currentPlayer {
                    ExerciseLibraryView(player: player)
                } else {
                    SwiftUI.ProgressView("Loading...")
                }
            }
            .tabItem {
                Image(systemName: DesignSystem.Icons.exercises)
                Text("Exercises")
            }
            .tag(2)

            NavigationView {
                TrainingPlansListView()
            }
            .tabItem {
                Image(systemName: "calendar.badge.clock")
                Text("Plans")
            }
            .tag(3)

            NavigationView {
                if let player = currentPlayer {
                    PlayerProgressView(player: player)
                } else {
                    SwiftUI.ProgressView("Loading...")
                }
            }
            .tabItem {
                Image(systemName: "chart.line.uptrend.xyaxis")
                Text("Progress")
            }
            .tag(4)

            NavigationView {
                if let player = currentPlayer {
                    MatchHistoryView(player: player)
                } else {
                    SwiftUI.ProgressView("Loading...")
                }
            }
            .tabItem {
                Image(systemName: "sportscourt")
                Text("Matches")
            }
            .tag(5)

            NavigationView {
                PlayerProfileView()
            }
            .tabItem {
                Image(systemName: DesignSystem.Icons.profile)
                Text("Profile")
            }
            .tag(6)
        }
        .accentColor(DesignSystem.Colors.primaryGreen)
        .onAppear {
            updatePlayersFilter()
        }
        .onChange(of: authManager.userUID) {
            updatePlayersFilter()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { notification in
            #if DEBUG
            print("🔔 MainTabView: Core Data context saved - currentPlayer is now: \(currentPlayer?.name ?? "nil")")
            #endif
        }
    }
    
    private func updatePlayersFilter() {
        guard !authManager.userUID.isEmpty else { return }
        
        players.nsPredicate = NSPredicate(format: "firebaseUID == %@", authManager.userUID)
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(CoreDataManager.shared)
}
