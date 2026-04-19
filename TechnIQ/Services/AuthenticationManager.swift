import Foundation
import AuthenticationServices
import CryptoKit
import FirebaseAuth
import FirebaseCrashlytics
import GoogleSignIn
import SwiftUI

enum AuthError: LocalizedError {
    case nonceGenerationFailed

    var errorDescription: String? {
        switch self {
        case .nonceGenerationFailed:
            return "Unable to generate secure nonce. Please try again."
        }
    }
}

class AuthenticationManager: ObservableObject, AuthenticationManagerProtocol {
    @Published var isAuthenticated = false
    @Published var currentUser: User? = nil
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?
    
    static let shared = AuthenticationManager()
    
    private init() {
        setupAuthStateListener()
    }
    
    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    // MARK: - Auth State Management
    
    private func setupAuthStateListener() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
                self?.isAuthenticated = user != nil
                self?.clearError()
                Crashlytics.crashlytics().setUserID(user?.uid ?? "")
            }
        }
    }
    
    // MARK: - Email/Password Authentication

    func signIn(email: String, password: String) async {
        await MainActor.run {
            isLoading = true
            clearError()
        }

        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            #if DEBUG
            print("User signed in: \(result.user.uid)")
            #endif
        } catch {
            await MainActor.run {
                handleAuthError(error)
            }
        }

        await MainActor.run {
            isLoading = false
        }
    }

    func signUp(email: String, password: String) async {
        await MainActor.run {
            isLoading = true
            clearError()
        }

        do {
            let result: AuthDataResult
            if let currentUser = Auth.auth().currentUser, currentUser.isAnonymous {
                let credential = EmailAuthProvider.credential(withEmail: email, password: password)
                do {
                    result = try await currentUser.link(with: credential)
                } catch let error as NSError
                    where error.code == AuthErrorCode.emailAlreadyInUse.rawValue {
                    #if DEBUG
                    print("⚠️ Email already exists — falling back to createUser (anon data orphaned)")
                    #endif
                    result = try await Auth.auth().createUser(withEmail: email, password: password)
                }
            } else {
                result = try await Auth.auth().createUser(withEmail: email, password: password)
            }
            #if DEBUG
            print("User created: \(result.user.uid)")
            #endif
        } catch {
            await MainActor.run {
                handleAuthError(error)
            }
        }

        await MainActor.run {
            isLoading = false
        }
    }

    // MARK: - Anonymous Authentication

    func signInAnonymously() async {
        await MainActor.run {
            isLoading = true
            clearError()
        }

        do {
            let result = try await Auth.auth().signInAnonymously()
            #if DEBUG
            print("Anonymous user signed in: \(result.user.uid)")
            #endif
        } catch {
            await MainActor.run {
                handleAuthError(error)
            }
        }

        await MainActor.run {
            isLoading = false
        }
    }
    
    // MARK: - Anonymous Linking

    /// If the current user is anonymous, upgrade them to the given credential
    /// instead of creating a new auth session. This preserves their UID so Firestore
    /// data stays accessible.
    private func linkOrSignIn(with credential: AuthCredential) async throws -> AuthDataResult {
        if let currentUser = Auth.auth().currentUser, currentUser.isAnonymous {
            do {
                return try await currentUser.link(with: credential)
            } catch let error as NSError
                where error.code == AuthErrorCode.credentialAlreadyInUse.rawValue
                   || error.code == AuthErrorCode.emailAlreadyInUse.rawValue {
                #if DEBUG
                print("⚠️ Anonymous link conflict — credential belongs to existing account. Falling back to sign-in (anon data will be orphaned).")
                #endif
                return try await Auth.auth().signIn(with: credential)
            }
        }
        return try await Auth.auth().signIn(with: credential)
    }

    // MARK: - Google Sign-In

    func signInWithGoogle() async {
        await MainActor.run {
            isLoading = true
            clearError()
        }

        do {
            // Get the presenting view controller
            guard let scene = await UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                  let presentingViewController = scene.windows.first?.rootViewController else {
                await MainActor.run {
                    errorMessage = "Unable to find root view controller"
                    isLoading = false
                }
                return
            }

            #if DEBUG

            print("🔄 Starting Google Sign-In...")


            #endif
            // Perform Google Sign-In
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)

            #if DEBUG

            print("✅ Google Sign-In UI completed")


            #endif
            // Get the ID token
            guard let idToken = result.user.idToken?.tokenString else {
                await MainActor.run {
                    errorMessage = "Failed to get Google ID token"
                    isLoading = false
                }
                return
            }

            // Get the access token
            let accessToken = result.user.accessToken.tokenString

            #if DEBUG

            print("🔄 Creating Firebase credential...")


            #endif
            // Create Firebase credential
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)

            // Sign in to Firebase
            let authResult = try await linkOrSignIn(with: credential)
            #if DEBUG
            print("✅ Google Sign-In successful: \(authResult.user.uid)")
            #endif
            #if DEBUG
            print("📧 User email: \(authResult.user.email ?? "No email")")

            #endif
        } catch let error as NSError {
            #if DEBUG
            print("❌ Google Sign-In error: \(error.localizedDescription)")
            #endif
            #if DEBUG
            print("❌ Error code: \(error.code)")
            #endif
            #if DEBUG
            print("❌ Error domain: \(error.domain)")

            #endif
            // Handle specific Google Sign-In errors
            await MainActor.run {
                if error.domain == "com.google.GIDSignIn" {
                    switch error.code {
                    case -2: // User cancelled
                        errorMessage = "Sign-in was cancelled"
                    case -4: // No current user
                        errorMessage = "No current user found"
                    case -5: // Keychain error
                        errorMessage = "Keychain error occurred"
                    default:
                        errorMessage = "Google Sign-In failed: \(error.localizedDescription)"
                    }
                } else {
                    handleAuthError(error)
                }
            }
        }

        await MainActor.run {
            isLoading = false
        }
    }
    
    // MARK: - Apple Sign-In

    func signInWithApple() async {
        await MainActor.run {
            isLoading = true
            clearError()
        }

        let nonce: String
        do {
            nonce = try randomNonceString()
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
            return
        }
        currentNonce = nonce

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        await MainActor.run {
            guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                  let window = scene.windows.first else {
                errorMessage = "Unable to find window"
                isLoading = false
                return
            }

            let controller = ASAuthorizationController(authorizationRequests: [request])
            let delegate = AppleSignInDelegate(authManager: self, nonce: nonce)
            controller.delegate = delegate
            controller.presentationContextProvider = window.rootViewController as? ASAuthorizationControllerPresentationContextProviding
            objc_setAssociatedObject(controller, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
            controller.performRequests()
        }
    }

    func handleAppleSignIn(credential: ASAuthorizationAppleIDCredential, nonce: String) async {
        guard let appleIDToken = credential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            await MainActor.run {
                errorMessage = "Unable to get Apple ID token"
                isLoading = false
            }
            return
        }

        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: credential.fullName
        )

        do {
            let result = try await linkOrSignIn(with: firebaseCredential)

            // Apple only provides name on first sign-in — save it
            if let fullName = credential.fullName {
                let displayName = [fullName.givenName, fullName.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                if !displayName.isEmpty {
                    let changeRequest = result.user.createProfileChangeRequest()
                    changeRequest.displayName = displayName
                    try? await changeRequest.commitChanges()
                    UserDefaults.standard.set(displayName, forKey: "onboarding_prefill_name")
                }
            }

            #if DEBUG
            print("✅ Apple Sign-In successful: \(result.user.uid)")
            #endif
        } catch {
            await MainActor.run {
                handleAuthError(error)
            }
        }

        await MainActor.run {
            isLoading = false
        }
    }

    private func randomNonceString(length: Int = 32) throws -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        guard errorCode == errSecSuccess else {
            throw AuthError.nonceGenerationFailed
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Sign Out

    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            #if DEBUG
            print("✅ User signed out successfully")
            #endif
        } catch {
            handleAuthError(error)
        }
    }
    
    // MARK: - Delete Account

    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "AuthenticationManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }

        let uid = user.uid
        guard let idToken = try? await user.getIDToken() else {
            throw NSError(domain: "AuthenticationManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to get auth token"])
        }

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

                    await clearLocalData(uid: uid)

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

    // MARK: - Password Reset

    func resetPassword(email: String) async {
        await MainActor.run {
            isLoading = true
            clearError()
        }

        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            #if DEBUG
            print("Password reset email sent")
            #endif
        } catch {
            await MainActor.run {
                handleAuthError(error)
            }
        }

        await MainActor.run {
            isLoading = false
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleAuthError(_ error: Error) {
        if let authError = error as NSError? {
            switch AuthErrorCode.Code(rawValue: authError.code) {
            case .invalidEmail:
                errorMessage = "Invalid email address"
            case .wrongPassword:
                errorMessage = "Incorrect password"
            case .userNotFound:
                errorMessage = "No account found with this email"
            case .userDisabled:
                errorMessage = "This account has been disabled"
            case .emailAlreadyInUse:
                errorMessage = "An account with this email already exists"
            case .weakPassword:
                errorMessage = "Password is too weak"
            case .networkError:
                errorMessage = "Network error. Please check your connection"
            case .tooManyRequests:
                errorMessage = "Too many attempts. Please try again later"
            default:
                errorMessage = authError.localizedDescription
            }
        } else {
            errorMessage = error.localizedDescription
        }
        #if DEBUG
        print("Auth error: \(errorMessage)")
        #endif
    }
    
    private func clearError() {
        errorMessage = ""
    }
    
    // MARK: - User Profile Management
    
    var userDisplayName: String {
        return currentUser?.displayName ?? currentUser?.email ?? "User"
    }
    
    var userEmail: String {
        return currentUser?.email ?? ""
    }
    
    var userUID: String {
        return currentUser?.uid ?? ""
    }
    
    var hasValidUser: Bool {
        return currentUser != nil && !userUID.isEmpty
    }
}

// MARK: - Apple Sign-In Delegate

class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    private let authManager: AuthenticationManager
    private let nonce: String

    init(authManager: AuthenticationManager, nonce: String) {
        self.authManager = authManager
        self.nonce = nonce
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
        Task {
            await authManager.handleAppleSignIn(credential: appleIDCredential, nonce: nonce)
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        #if DEBUG
        print("❌ Apple Sign-In error: \(error.localizedDescription)")
        #endif
        Task { @MainActor in
            authManager.isLoading = false
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                authManager.errorMessage = "Apple Sign-In failed: \(error.localizedDescription)"
            }
        }
    }
}

