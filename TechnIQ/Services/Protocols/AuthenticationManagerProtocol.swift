import Foundation
import FirebaseAuth

// MARK: - AuthenticationManager Protocol

protocol AuthenticationManagerProtocol: AnyObject {
    var isAuthenticated: Bool { get }
    var currentUser: User? { get }
    var isLoading: Bool { get }
    var errorMessage: String { get }

    func signIn(email: String, password: String) async
    func signUp(email: String, password: String) async
    func signInAnonymously() async
    func signInWithGoogle() async
    func signOut()
    func deleteAccount() async throws
    func resetPassword(email: String) async
}
