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
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Player.createdAt, ascending: false)],
        animation: .default)
    private var players: FetchedResults<Player>
    
    @State private var isAuthenticated = false
    @State private var isOnboardingComplete = false
    
    var body: some View {
        Group {
            if !isAuthenticated {
                AuthenticationView(isAuthenticated: $isAuthenticated)
            } else if players.isEmpty && !isOnboardingComplete {
                OnboardingView(isOnboardingComplete: $isOnboardingComplete)
            } else {
                MainTabView()
            }
        }
        .onAppear {
            isOnboardingComplete = !players.isEmpty
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationView {
                DashboardView()
            }
            .tabItem {
                Image(systemName: "house.fill")
                Text("Home")
            }
            
            NavigationView {
                SessionHistoryView()
            }
            .tabItem {
                Image(systemName: "calendar")
                Text("Sessions")
            }
            
            NavigationView {
                ExerciseLibraryView()
            }
            .tabItem {
                Image(systemName: "book.fill")
                Text("Exercises")
            }
            
            NavigationView {
                PlayerProfileView()
            }
            .tabItem {
                Image(systemName: "person.fill")
                Text("Profile")
            }
        }
        .accentColor(.black)
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
}
