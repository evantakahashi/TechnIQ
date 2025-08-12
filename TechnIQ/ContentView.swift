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
                    ProgressView("Loading...")
                    
                    Text("🚨 AUTH DEBUG: hasValidUser = FALSE")
                        .font(.caption)
                        .foregroundColor(.red)
                        .onAppear {
                            print("⚠️ AuthenticatedContentView: hasValidUser = false - showing loading screen")
                            print("   🔍 isAuthenticated: \(authManager.isAuthenticated ? "YES" : "NO")")
                            print("   🔍 userUID: '\(authManager.userUID)'")
                            print("   🔍 userUID.isEmpty: \(authManager.userUID.isEmpty ? "YES" : "NO")")
                        }
                    
                    // DEBUG: Show authentication status
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DEBUG INFO:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("isAuthenticated: \(authManager.isAuthenticated ? "YES" : "NO")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("hasValidUser: \(authManager.hasValidUser ? "YES" : "NO")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("userUID: \(authManager.userUID.isEmpty ? "EMPTY" : "HAS_UID")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    
                    // Force refresh button  
                    Button("Force Continue") {
                        // Temporarily force past this screen for debugging
                        print("🔧 DEBUG: Force continuing past auth check")
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
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
        
        // Initialize with predicate that allows results initially
        self._players = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Player.createdAt, ascending: false)],
            predicate: NSPredicate(value: true), // Allow all results initially
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
    
    init() {
        // Initialize with predicate that allows results initially
        self._players = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Player.createdAt, ascending: false)],
            predicate: NSPredicate(value: true), // Allow all results initially
            animation: .default
        )
    }
    
    var currentPlayer: Player? {
        let player = players.first
        if player == nil && !authManager.userUID.isEmpty {
            print("⚠️ MainTabView: currentPlayer is nil despite having userUID. Players count: \(players.count)")
        }
        return player
    }
    
    var body: some View {
        TabView {
            NavigationView {
                DashboardView()
            }
            .tabItem {
                Image(systemName: DesignSystem.Icons.home)
                Text("Home")
            }
            
            NavigationView {
                SessionHistoryView()
            }
            .tabItem {
                Image(systemName: DesignSystem.Icons.sessions)
                Text("Sessions")
            }
            
            NavigationView {
                if let player = currentPlayer {
                    ExerciseLibraryView(player: player)
                } else {
                    ProgressView("Loading...")
                }
            }
            .tabItem {
                Image(systemName: DesignSystem.Icons.exercises)
                Text("Exercises")
            }
            
            NavigationView {
                PlayerProfileView()
            }
            .tabItem {
                Image(systemName: DesignSystem.Icons.profile)
                Text("Profile")
            }
        }
        .accentColor(DesignSystem.Colors.primaryGreen)
        .onAppear {
            updatePlayersFilter()
        }
        .onChange(of: authManager.userUID) {
            updatePlayersFilter()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { notification in
            print("🔔 MainTabView: Core Data context saved - currentPlayer is now: \(currentPlayer?.name ?? "nil")")
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
