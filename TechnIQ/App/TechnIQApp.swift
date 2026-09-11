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
import FirebaseCrashlytics

@main
struct TechnIQApp: App {
    let coreDataManager = CoreDataManager.shared
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    init() {
        // Configure Firebase FIRST before accessing any Firebase services
        FirebaseApp.configure()
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)

        // Configure Firestore with simulator-friendly settings
        let db = Firestore.firestore()
        let settings = FirestoreSettings()

        #if targetEnvironment(simulator)
        // For simulator testing - disable problematic features
        #if DEBUG
        print("Configuring Firestore for simulator")
        #endif
        #endif

        db.settings = settings

        // Configure Google Sign-In
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let clientId = plist["CLIENT_ID"] as? String {
            let config = GIDConfiguration(clientID: clientId)
            GIDSignIn.sharedInstance.configuration = config
            #if DEBUG
            print("Google Sign-In configured successfully with client ID: \(clientId)")
            #endif
        } else {
            #if DEBUG
            print("Warning: Could not configure Google Sign-In - GoogleService-Info.plist not found or invalid")
            #endif
        }
    }

    var body: some Scene {
        WindowGroup {
            rootView
                .environment(\.managedObjectContext, coreDataManager.context)
                .environmentObject(coreDataManager)
                .environmentObject(authManager)
                .environmentObject(subscriptionManager)
                .preferredColorScheme(.dark)
        }
    }

    @ViewBuilder
    private var rootView: some View {
        #if DEBUG
        if TQGalleryView.isRequested {
            TQGalleryView()
        } else if let screen = TQDebugScreen.requested {
            TQDebugScreenHost(screen: screen)
        } else {
            ContentView()
        }
        #else
        ContentView()
        #endif
    }
}
