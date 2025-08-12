# Firebase Firestore Setup for ML Recommendation System

## Required Dependencies

To complete the machine learning recommendation system implementation, you need to add Firebase Firestore to your Xcode project.

### 1. Add Firebase Firestore Package Dependency

In Xcode:
1. Go to **File > Add Package Dependencies**
2. The Firebase iOS SDK is already configured, but you need to add Firestore
3. In the existing Firebase package dependency, add **FirebaseFirestore** to your target

### 2. Update TechnIQApp.swift

Add the Firestore import and initialization:

```swift
import SwiftUI
import CoreData
import FirebaseCore
import FirebaseFirestore  // Add this import
import GoogleSignIn

@main
struct TechnIQApp: App {
    let coreDataManager = CoreDataManager.shared
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var cloudSyncManager = CloudSyncManager.shared  // Add this
    
    init() {
        // Configure Firebase
        FirebaseApp.configure()
        
        // Configure Firestore settings
        let db = Firestore.firestore()
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
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
                .environmentObject(cloudSyncManager)  // Add this
        }
    }
}
```

### 3. Update ContentView.swift

Add the CloudSyncManager environment object:

```swift
struct ContentView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var cloudSyncManager: CloudSyncManager  // Add this
    
    // ... rest of your ContentView code
}
```

### 4. Firestore Security Rules

Set up the following Firestore security rules in the Firebase Console:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      // User's subcollections
      match /{subcollection=**} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
    
    // ML Analytics - authenticated users can write
    match /mlAnalytics/{document} {
      allow write: if request.auth != null;
      allow read: if false; // Only backend can read
    }
    
    // Aggregated data - read-only for authenticated users
    match /aggregatedProfiles/{document} {
      allow read: if request.auth != null;
      allow write: if false; // Only backend can write
    }
    
    match /exerciseMetrics/{document} {
      allow read: if request.auth != null;
      allow write: if false; // Only backend can write
    }
    
    match /userClusters/{document} {
      allow read: if request.auth != null;
      allow write: if false; // Only backend can write
    }
  }
}
```

### 5. Firestore Database Structure

The following collections will be created automatically:

```
/users/{userUID}/
  ├── playerProfiles/{playerID}
  ├── playerGoals/{goalID}
  ├── trainingSessions/{sessionID}
  └── recommendationFeedback/{feedbackID}

/mlAnalytics/{sessionID}
/aggregatedProfiles/{playerID}
/exerciseMetrics/{exerciseID}
/userClusters/{clusterID}
/userSimilarity/{similarityID}
/exerciseAffinity/{affinityID}
/modelMetrics/{modelID}
```

### 6. Test the Implementation

After adding the dependencies:

1. Run the app and complete the enhanced onboarding flow
2. Check the Firestore console to verify data is being synced
3. The CloudSyncManager will automatically sync data every 5 minutes
4. Monitor the console for sync status messages

### 7. Enable Firestore APIs in Google Cloud Console

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Select your Firebase project
3. Navigate to "APIs & Services" > "Library"
4. Enable the following APIs:
   - Cloud Firestore API
   - Firebase Extensions API (for future ML extensions)

## Next Steps

Once Firebase Firestore is configured:

1. **Cloud Functions**: Create serverless functions for ML model training and recommendations
2. **BigQuery Integration**: Set up data warehouse for advanced analytics
3. **Vertex AI**: Implement collaborative filtering models
4. **Real-time Recommendations**: Build the recommendation engine

## Troubleshooting

### Common Issues:

1. **Build Errors**: Make sure FirebaseFirestore is added to your target's package dependencies
2. **Sync Failures**: Check that your GoogleService-Info.plist has the correct project configuration
3. **Permission Errors**: Verify Firestore security rules allow authenticated users to read/write their data
4. **Network Issues**: Firestore requires internet connectivity for initial setup

### Debug Commands:

```swift
// Check authentication status
print("Auth user: \(Auth.auth().currentUser?.uid ?? "none")")

// Check Firestore connection
let db = Firestore.firestore()
db.settings.host = "localhost:8080" // For Firestore emulator testing
```

The ML recommendation system foundation is now ready for the next phase of implementation!