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
            DispatchQueue.main.async {
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
            print("User signed in: \(result.user.uid)")
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
            print("User created: \(result.user.uid)")
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
            print("Anonymous user signed in: \(result.user.uid)")
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
            guard let presentingViewController = await UIApplication.shared.windows.first?.rootViewController else {
                await MainActor.run {
                    errorMessage = "Unable to find root view controller"
                    isLoading = false
                }
                return
            }

            print("🔄 Starting Google Sign-In...")

            // Perform Google Sign-In
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)

            print("✅ Google Sign-In UI completed")

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

            print("🔄 Creating Firebase credential...")

            // Create Firebase credential
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)

            // Sign in to Firebase
            let authResult = try await Auth.auth().signIn(with: credential)
            print("✅ Google Sign-In successful: \(authResult.user.uid)")
            print("📧 User email: \(authResult.user.email ?? "No email")")

        } catch let error as NSError {
            print("❌ Google Sign-In error: \(error.localizedDescription)")
            print("❌ Error code: \(error.code)")
            print("❌ Error domain: \(error.domain)")

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
            print("✅ User signed out successfully")
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
            print("Password reset email sent")
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
        print("Auth error: \(errorMessage)")
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

// MARK: - UIApplication Extension for Root View Controller

extension UIApplication {
    var windows: [UIWindow] {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
    }
}