# Account Deletion Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add account deletion with two-step confirmation, server-side data cleanup via Firebase Function, and local data wipe.

**Architecture:** New `delete_account` Firebase Function handles Firestore data deletion + auth user deletion server-side. Client calls it via `AuthenticationManager.deleteAccount()`, then clears local Core Data and signs out. UI lives in SettingsView with two-step confirmation (alert + type "DELETE").

**Tech Stack:** Python (Firebase Functions), Swift/SwiftUI, Firebase Admin SDK, Firebase Auth

---

### Task 1: Add `delete_account` Firebase Function

**Files:**
- Modify: `functions/main.py`

**Step 1: Add the `delete_account` endpoint**

Add this function after the last endpoint (after `get_plan_adaptation`, ~line 1707):

```python
@https_fn.on_request(timeout_sec=120)
def delete_account(req: https_fn.Request) -> https_fn.Response:
    """
    Permanently delete a user's account and all associated data.
    Anonymizes community posts, deletes Firestore docs, deletes Firebase Auth user.
    """
    try:
        # Handle CORS preflight
        if req.method == 'OPTIONS':
            return https_fn.Response(
                "",
                status=200,
                headers={
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Methods': 'POST, OPTIONS',
                    'Access-Control-Allow-Headers': 'Content-Type, Authorization'
                }
            )

        if req.method != 'POST':
            return https_fn.Response("Method not allowed", status=405)

        # Auth verification — REQUIRED, no ALLOW_UNAUTHENTICATED bypass
        auth_header = req.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return https_fn.Response(
                json.dumps({"error": "Authentication required"}),
                status=401,
                headers={'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'}
            )

        try:
            id_token = auth_header.split('Bearer ')[1]
            decoded_token = auth.verify_id_token(id_token)
            uid = decoded_token['uid']
            logger.info(f"🗑️ Account deletion requested by user: {uid}")
        except Exception as e:
            return https_fn.Response(
                json.dumps({"error": "Invalid authentication token"}),
                status=401,
                headers={'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'}
            )

        global db
        if not db:
            db = firestore.client()

        # Step 1: Anonymize community posts
        try:
            posts_ref = db.collection('communityPosts').where('authorID', '==', uid)
            posts = posts_ref.get()
            for post in posts:
                post.reference.update({
                    'authorID': 'deleted',
                    'authorName': 'Deleted User',
                    'authorProfileImageURL': '',
                    'authorAvatarState': None
                })
            logger.info(f"📝 Anonymized {len(posts)} community posts")
        except Exception as e:
            logger.warning(f"⚠️ Error anonymizing posts: {e}")

        # Step 2: Delete user-scoped Firestore documents
        collections_to_delete = [
            'playerProfiles',
            'players',
            'mlRecommendations',
            'playerGoals',
            'recommendationFeedback',
            'cloudSyncStatus'
        ]

        for collection_name in collections_to_delete:
            try:
                doc_ref = db.collection(collection_name).document(uid)
                doc_ref.delete()
                logger.info(f"🗑️ Deleted {collection_name}/{uid}")
            except Exception as e:
                logger.warning(f"⚠️ Error deleting {collection_name}/{uid}: {e}")

        # Step 3: Delete /users/{uid} and all subcollections
        try:
            user_doc_ref = db.collection('users').document(uid)
            _delete_document_and_subcollections(user_doc_ref)
            logger.info(f"🗑️ Deleted users/{uid} and subcollections")
        except Exception as e:
            logger.warning(f"⚠️ Error deleting users/{uid}: {e}")

        # Step 4: Delete Firebase Auth user
        try:
            auth.delete_user(uid)
            logger.info(f"🗑️ Deleted Firebase Auth user: {uid}")
        except Exception as e:
            logger.error(f"❌ Error deleting auth user: {e}")
            return https_fn.Response(
                json.dumps({"error": f"Failed to delete auth user: {str(e)}"}),
                status=500,
                headers={'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'}
            )

        logger.info(f"✅ Account deletion complete for user: {uid}")
        return https_fn.Response(
            json.dumps({"success": True}),
            status=200,
            headers={
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, Authorization'
            }
        )

    except Exception as e:
        logger.error(f"❌ Error in delete_account: {str(e)}")
        logger.error(traceback.format_exc())
        return https_fn.Response(
            json.dumps({"error": str(e)}),
            status=500,
            headers={
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, Authorization'
            }
        )


def _delete_document_and_subcollections(doc_ref):
    """Recursively delete a document and all its subcollections."""
    # Delete all subcollections
    for collection_ref in doc_ref.collections():
        for doc in collection_ref.get():
            _delete_document_and_subcollections(doc.reference)
    # Delete the document itself
    doc_ref.delete()
```

**Step 2: Commit**

```bash
git add functions/main.py
git commit -m "feat: add delete_account Firebase Function endpoint"
```

---

### Task 2: Add `deleteAccount()` to AuthenticationManager

**Files:**
- Modify: `TechnIQ/AuthenticationManager.swift`

**Step 1: Add the deleteAccount method**

Add after `signOut()` (~line 219), before the `// MARK: - Password Reset` section:

```swift
// MARK: - Delete Account

func deleteAccount() async throws {
    guard let user = Auth.auth().currentUser else {
        throw NSError(domain: "AuthenticationManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
    }

    let uid = user.uid
    guard let idToken = try? await user.getIDToken() else {
        throw NSError(domain: "AuthenticationManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to get auth token"])
    }

    // Call Firebase Function
    let functionsURL = "https://us-central1-techniq-b9a27.cloudfunctions.net/delete_account"
    guard let url = URL(string: functionsURL) else {
        throw NSError(domain: "AuthenticationManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
    request.httpBody = try JSONSerialization.data(withJSONObject: [:])
    request.timeoutInterval = 120

    // Retry with exponential backoff (same pattern as CloudMLService)
    var lastError: Error?
    for attempt in 0..<3 {
        do {
            if attempt > 0 {
                let delay = pow(2.0, Double(attempt))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "AuthenticationManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }

            if httpResponse.statusCode == 200 {
                #if DEBUG
                print("✅ Account deletion confirmed by server for UID: \(uid)")
                #endif

                // Clear local Core Data
                await clearLocalData(uid: uid)

                // Sign out
                await MainActor.run {
                    signOut()
                }
                return
            } else {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw NSError(domain: "AuthenticationManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error: \(errorBody)"])
            }
        } catch {
            lastError = error
            #if DEBUG
            print("⚠️ Delete account attempt \(attempt + 1) failed: \(error.localizedDescription)")
            #endif
        }
    }

    throw lastError ?? NSError(domain: "AuthenticationManager", code: 5, userInfo: [NSLocalizedDescriptionKey: "Account deletion failed after retries"])
}

private func clearLocalData(uid: String) async {
    let context = CoreDataManager.shared.context
    await context.perform {
        let request = Player.fetchRequest()
        request.predicate = NSPredicate(format: "firebaseUID == %@", uid)
        if let players = try? context.fetch(request) {
            for player in players {
                context.delete(player)
            }
        }
        try? context.save()
    }
    #if DEBUG
    print("✅ Cleared local Core Data for UID: \(uid)")
    #endif
}
```

**Step 2: Build and verify**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add TechnIQ/AuthenticationManager.swift
git commit -m "feat: add deleteAccount method with retry and local data cleanup"
```

---

### Task 3: Add Delete Account UI to SettingsView

**Files:**
- Modify: `TechnIQ/SettingsView.swift`

**Step 1: Add state variables and environment objects**

Add to `SettingsView` struct, after the existing `@AppStorage` line (~line 12):

```swift
@EnvironmentObject private var authManager: AuthenticationManager
@State private var showingDeleteAlert = false
@State private var showingDeleteConfirmation = false
@State private var deleteConfirmationText = ""
@State private var isDeletingAccount = false
@State private var deleteError: String?
@State private var showingDeleteError = false
```

**Step 2: Add the Account section to the Form**

Add a new `Section` before the "About" section (~line 29):

```swift
Section {
    Button(role: .destructive) {
        showingDeleteAlert = true
    } label: {
        HStack {
            Image(systemName: "trash")
                .foregroundColor(DesignSystem.Colors.error)
            Text("Delete Account")
                .foregroundColor(DesignSystem.Colors.error)
        }
    }
    .disabled(isDeletingAccount)
} header: {
    Text("Account")
} footer: {
    Text("Permanently deletes your account, training data, plans, and progress. This cannot be undone.")
}
```

**Step 3: Add the alerts and loading overlay**

Add after the existing `.toolbar` modifier (~line 53):

```swift
.alert("Delete Account?", isPresented: $showingDeleteAlert) {
    Button("Cancel", role: .cancel) { }
    Button("Continue", role: .destructive) {
        deleteConfirmationText = ""
        showingDeleteConfirmation = true
    }
} message: {
    Text("This will permanently delete your account, all training data, plans, and progress. This cannot be undone.")
}
.alert("Type DELETE to confirm", isPresented: $showingDeleteConfirmation) {
    TextField("Type DELETE", text: $deleteConfirmationText)
        .autocapitalization(.allCharacters)
    Button("Cancel", role: .cancel) {
        deleteConfirmationText = ""
    }
    Button("Delete Account", role: .destructive) {
        performAccountDeletion()
    }
    .disabled(deleteConfirmationText != "DELETE")
} message: {
    Text("This action is permanent and cannot be reversed.")
}
.alert("Deletion Failed", isPresented: $showingDeleteError) {
    Button("Try Again", role: .destructive) {
        performAccountDeletion()
    }
    Button("Cancel", role: .cancel) { }
} message: {
    Text(deleteError ?? "An unknown error occurred. Please try again.")
}
.overlay {
    if isDeletingAccount {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                Text("Deleting account...")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
        }
    }
}
```

**Step 4: Add the deletion function**

Add to `SettingsView` struct:

```swift
private func performAccountDeletion() {
    isDeletingAccount = true
    deleteError = nil

    Task {
        do {
            try await authManager.deleteAccount()
            await MainActor.run {
                isDeletingAccount = false
                dismiss()
            }
        } catch {
            await MainActor.run {
                isDeletingAccount = false
                deleteError = error.localizedDescription
                showingDeleteError = true
            }
        }
    }
}
```

**Step 5: Build and verify**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build`
Expected: BUILD SUCCEEDED

**Step 6: Commit**

```bash
git add TechnIQ/SettingsView.swift
git commit -m "feat: add delete account UI with two-step confirmation in Settings"
```

---

### Task 4: Pass EnvironmentObject to SettingsView

**Files:**
- Modify: `TechnIQ/EnhancedProfileView.swift`

**Step 1: Check if SettingsView receives authManager**

`SettingsView` is presented as a sheet from `EnhancedProfileView` (line 87):
```swift
.sheet(isPresented: $showingSettings) {
    SettingsView()
}
```

Since `EnhancedProfileView` already has `@EnvironmentObject private var authManager: AuthenticationManager`, the sheet inherits it. **But** confirm the `.environmentObject(authManager)` is propagated through the NavigationView in `MainTabView` (ContentView.swift line 296). The `NavigationView` wraps each tab and passes `.environmentObject(authManager)` — so SettingsView will receive it via the environment chain.

If builds fail with "no ObservableObject of type AuthenticationManager found", explicitly pass it:

```swift
.sheet(isPresented: $showingSettings) {
    SettingsView()
        .environmentObject(authManager)
}
```

**Step 2: Build and verify**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build`
Expected: BUILD SUCCEEDED

**Step 3: Commit (if changes were needed)**

```bash
git add TechnIQ/EnhancedProfileView.swift
git commit -m "fix: ensure SettingsView receives authManager environmentObject"
```

---

### Task 5: Deploy Firebase Function and Final Build

**Step 1: Deploy the function**

```bash
cd functions && firebase deploy --only functions:delete_account
```
Expected: successful deploy

**Step 2: Full clean build**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' clean build`
Expected: BUILD SUCCEEDED

**Step 3: Push**

```bash
git push origin main
```
