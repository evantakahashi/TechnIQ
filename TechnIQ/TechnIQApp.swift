//
//  TechnIQApp.swift
//  TechnIQ
//
//  Created by Evan Takahashi on 6/30/25.
//

import SwiftUI
import CoreData
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import FirebaseFirestore

@main
struct TechnIQApp: App {
    let coreDataManager = CoreDataManager.shared
    @StateObject private var authManager = AuthenticationManager.shared

    init() {
        // Configure Firebase FIRST before accessing any Firebase services
        FirebaseApp.configure()

        // Configure Firestore with simulator-friendly settings
        let db = Firestore.firestore()
        let settings = FirestoreSettings()

        #if targetEnvironment(simulator)
        // For simulator testing - disable problematic features
        print("🔧 Configuring Firestore for simulator")
        #endif

        db.settings = settings

        // Configure Google Sign-In
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let clientId = plist["CLIENT_ID"] as? String {
            let config = GIDConfiguration(clientID: clientId)
            GIDSignIn.sharedInstance.configuration = config
            print("✅ Google Sign-In configured successfully with client ID: \(clientId)")
        } else {
            print("❌ Warning: Could not configure Google Sign-In - GoogleService-Info.plist not found or invalid")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, coreDataManager.context)
                .environmentObject(coreDataManager)
                .environmentObject(authManager)
        }
    }
}
