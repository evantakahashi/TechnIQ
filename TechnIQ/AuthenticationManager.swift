import Foundation
import FirebaseAuth
import GoogleSignIn
import SwiftUI

class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User? = nil
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
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
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
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
            let authResult = try await Auth.auth().signIn(with: credential)
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

