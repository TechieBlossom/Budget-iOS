//
//  AuthManager.swift
//  Budget
//
//  Created for Supabase integration
//

import Foundation
import Supabase
import AuthenticationServices
import GoogleSignIn
import SwiftUI
import Security

/// User profile data
struct UserProfile: Codable {
    let id: UUID
    let themePreference: String
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case themePreference = "theme_preference"
        case updatedAt = "updated_at"
    }
}

/// Profile creation request
struct ProfileCreateRequest: Codable {
    let id: UUID
    let themePreference: String

    enum CodingKeys: String, CodingKey {
        case id
        case themePreference = "theme_preference"
    }
}

/// Profile update request
struct ProfileUpdateRequest: Codable {
    let themePreference: String

    enum CodingKeys: String, CodingKey {
        case themePreference = "theme_preference"
    }
}

// MARK: - Keychain Helper

/// Secure storage for session data using iOS Keychain
private enum KeychainHelper {
    private static let service = "com.budget.app.auth"
    private static let userIdKey = "cached_user_id"
    private static let userEmailKey = "cached_user_email"

    /// Save user ID to Keychain
    static func saveUserId(_ userId: UUID) {
        save(key: userIdKey, value: userId.uuidString)
    }

    /// Load user ID from Keychain
    static func loadUserId() -> UUID? {
        guard let string = load(key: userIdKey) else { return nil }
        return UUID(uuidString: string)
    }

    /// Save user email to Keychain
    static func saveUserEmail(_ email: String?) {
        guard let email = email else { return }
        save(key: userEmailKey, value: email)
    }

    /// Load user email from Keychain
    static func loadUserEmail() -> String? {
        return load(key: userEmailKey)
    }

    /// Clear all session data from Keychain
    static func clearSession() {
        delete(key: userIdKey)
        delete(key: userEmailKey)
    }

    // MARK: - Private Keychain Operations

    private static func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }

        // Delete existing item first
        delete(key: key)

        // Add new item
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("⚠️ Keychain save failed for \(key): \(status)")
        }
    }

    private static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    private static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}

/// Authentication state and user management
@MainActor
@Observable
class AuthManager: NSObject {
    // MARK: - Properties

    /// Current authenticated user
    private(set) var currentUser: User?

    /// User profile data
    private(set) var userProfile: UserProfile?

    /// Whether user is authenticated
    var isAuthenticated: Bool {
        currentUser != nil
    }

    /// Loading state
    private(set) var isLoading = false

    /// Error message
    private(set) var errorMessage: String?

    /// Supabase client
    private let supabase = SupabaseClientManager.shared.client

    /// Budget manager reference (for data cleanup on logout)
    weak var budgetManager: AnyObject?

    // MARK: - Initialization

    override init() {
        super.init()
        Task {
            await checkSession()
        }
    }

    // MARK: - Session Management

    /// Check for existing session (with offline support)
    func checkSession() async {
        isLoading = true
        errorMessage = nil

        do {
            // Try to get session from Supabase (normal online flow)
            let session = try await supabase.auth.session
            currentUser = session.user

            // Persist session to Keychain for offline access
            persistSessionToKeychain(session.user)

            // Load user profile (requires network)
            await loadUserProfile()

            print("✅ AuthManager: Session validated online")
        } catch {
            // Check if this is a network-related error
            if isNetworkError(error) {
                // Try to restore from cached session (offline mode)
                if let cachedUser = loadCachedSession() {
                    currentUser = cachedUser
                    userProfile = nil // Can't load profile offline
                    print("⚠️ AuthManager: Offline mode - using cached session (userId: \(cachedUser.id))")
                } else {
                    // No cached session available - user needs to sign in
                    currentUser = nil
                    userProfile = nil
                    print("❌ AuthManager: No cached session - user must sign in")
                }
            } else {
                // Non-network error (expired token, revoked access, etc.)
                // Clear cache and require re-authentication
                clearCachedSession()
                currentUser = nil
                userProfile = nil
                print("❌ AuthManager: Session invalid - cleared cache, re-authentication required")
            }
        }

        isLoading = false
    }

    /// Persist session to Keychain for offline access
    private func persistSessionToKeychain(_ user: User) {
        KeychainHelper.saveUserId(user.id)
        KeychainHelper.saveUserEmail(user.email)
        print("💾 AuthManager: Session persisted to Keychain")
    }

    /// Load cached session from Keychain
    private func loadCachedSession() -> User? {
        guard let userId = KeychainHelper.loadUserId() else {
            return nil
        }

        let email = KeychainHelper.loadUserEmail()

        // Create a minimal User object for offline access
        // Note: Supabase User struct may not be directly instantiable
        // We use a workaround by creating it through JSON serialization
        let userDict: [String: Any] = [
            "id": userId.uuidString,
            "email": email as Any,
            "aud": "authenticated",
            "role": "authenticated",
            "created_at": Date().ISO8601Format(),
            "updated_at": Date().ISO8601Format()
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: userDict)
            let user = try JSONDecoder().decode(User.self, from: jsonData)
            return user
        } catch {
            print("⚠️ AuthManager: Failed to reconstruct User from cache: \(error)")
            return nil
        }
    }

    /// Clear cached session from Keychain
    private func clearCachedSession() {
        KeychainHelper.clearSession()
        print("🗑️ AuthManager: Cleared cached session from Keychain")
    }

    /// Check if error is network-related
    private func isNetworkError(_ error: Error) -> Bool {
        let nsError = error as NSError

        // Check for common network error domains and codes
        if nsError.domain == NSURLErrorDomain {
            return true
        }

        // Check for specific network-related error codes
        let networkErrorCodes: Set<Int> = [
            NSURLErrorNotConnectedToInternet,
            NSURLErrorNetworkConnectionLost,
            NSURLErrorCannotConnectToHost,
            NSURLErrorTimedOut,
            NSURLErrorDNSLookupFailed,
            NSURLErrorCannotFindHost
        ]

        if networkErrorCodes.contains(nsError.code) {
            return true
        }

        // Check error description for network-related keywords
        let errorDescription = error.localizedDescription.lowercased()
        let networkKeywords = ["network", "internet", "connection", "offline", "unreachable"]

        return networkKeywords.contains { errorDescription.contains($0) }
    }

    /// Load user profile from Supabase
    private func loadUserProfile() async {
        guard let userId = currentUser?.id else { return }

        do {
            let response: UserProfile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value

            userProfile = response
        } catch {
            print("Failed to load user profile: \(error)")
            // Profile might not exist yet, will be created on first sign in
        }
    }

    // MARK: - Apple Sign In

    /// Sign in with Apple
    func signInWithApple() async throws {
        isLoading = true
        errorMessage = nil

        do {
            // Request Apple ID credential
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]

            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            let delegate = AppleSignInDelegate()

            authorizationController.delegate = delegate
            authorizationController.performRequests()

            // Wait for the result
            let credential = try await delegate.credential

            // Convert identity token data to string
            guard let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                throw NSError(domain: "AuthManager", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to get ID token from Apple"
                ])
            }

            // Sign in with Supabase using the ID token
            try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: idToken
                )
            )

            // Update current user
            let session = try await supabase.auth.session
            currentUser = session.user

            // Persist session to Keychain for offline access
            persistSessionToKeychain(session.user)

            // Create profile if needed
            await createProfileIfNeeded()

            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Apple Sign In failed: \(error.localizedDescription)"
            throw error
        }
    }

    // MARK: - Google Sign In

    /// Sign in with Google
    func signInWithGoogle(presenting viewController: UIViewController) async throws {
        isLoading = true
        errorMessage = nil

        do {
            // Configure Google Sign In with iOS client ID
            let clientID: String = SupabaseConfig.googleiOSClientID
            let configuration = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = configuration

            // Perform sign in
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: viewController
            )

            guard let idToken = result.user.idToken?.tokenString else {
                throw NSError(domain: "AuthManager", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to get ID token from Google"
                ])
            }

            // Sign in with Supabase using the ID token (no nonce for iOS)
            // NOTE: "Skip nonce check" must be enabled in Supabase Dashboard
            // Authentication > Providers > Google > Skip nonce checks
            try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .google,
                    idToken: idToken
                )
            )

            // Update current user
            let session = try await supabase.auth.session
            currentUser = session.user

            // Persist session to Keychain for offline access
            persistSessionToKeychain(session.user)

            // Create profile if needed
            await createProfileIfNeeded()

            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Google Sign In failed: \(error.localizedDescription)"
            throw error
        }
    }

    // MARK: - Profile Management

    /// Create user profile if it doesn't exist
    private func createProfileIfNeeded() async {
        guard let userId = currentUser?.id else { return }

        do {
            // Check if profile exists
            let existingProfile: [UserProfile] = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .execute()
                .value

            if existingProfile.isEmpty {
                // Create new profile
                let newProfile = ProfileCreateRequest(
                    id: userId,
                    themePreference: "system"
                )

                try await supabase
                    .from("profiles")
                    .insert(newProfile)
                    .execute()
            }

            // Load the profile
            await loadUserProfile()
        } catch {
            print("Failed to create profile: \(error)")
        }
    }

    // MARK: - Sign Out

    /// Sign out current user and clear all local data
    func signOut() async throws {
        print("🚪 AuthManager: Starting logout process...")
        isLoading = true
        errorMessage = nil

        do {
            // Clear local database before signing out
            print("   Checking budgetManager reference...")
            if let manager = budgetManager as? BudgetManager {
                print("   ✅ BudgetManager reference found, clearing data...")
                do {
                    try manager.clearAllData()
                    print("   ✅ Local data cleared on logout")
                } catch {
                    print("   ⚠️ Warning: Failed to clear local data: \(error)")
                    // Continue with sign out even if data cleanup fails
                }
            } else {
                print("   ⚠️ WARNING: BudgetManager reference is nil - data NOT cleared!")
                print("   budgetManager value: \(String(describing: budgetManager))")
            }

            // Clear cached session from Keychain
            print("   Clearing cached session from Keychain...")
            clearCachedSession()
            print("   ✅ Keychain session cleared")

            // Clear sync timestamp from UserDefaults (backup cleanup)
            print("   Clearing sync timestamp from UserDefaults...")
            UserDefaults.standard.removeObject(forKey: "lastSyncTimestamp")
            print("   ✅ Sync timestamp cleared")

            // Sign out from Supabase
            print("   Signing out from Supabase...")
            try await supabase.auth.signOut()
            currentUser = nil
            userProfile = nil
            isLoading = false
            print("   ✅ Logout completed successfully")
        } catch {
            isLoading = false
            errorMessage = "Sign out failed: \(error.localizedDescription)"
            print("   ❌ Logout failed: \(error)")
            throw error
        }
    }

    // MARK: - Theme Management

    /// Update theme preference
    func updateThemePreference(_ theme: String) async {
        guard let userId = currentUser?.id else { return }

        do {
            let updates = ProfileUpdateRequest(themePreference: theme)

            try await supabase
                .from("profiles")
                .update(updates)
                .eq("id", value: userId)
                .execute()

            // Reload profile
            await loadUserProfile()
        } catch {
            print("Failed to update theme preference: \(error)")
        }
    }
}

// MARK: - Apple Sign In Delegate

@MainActor
private class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?

    var credential: ASAuthorizationAppleIDCredential {
        get async throws {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
            }
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
            continuation?.resume(returning: credential)
        } else {
            continuation?.resume(throwing: NSError(
                domain: "AuthManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid credential type"]
            ))
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        continuation?.resume(throwing: error)
    }
}
