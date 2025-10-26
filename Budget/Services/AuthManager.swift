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

    // MARK: - Initialization

    override init() {
        super.init()
        Task {
            await checkSession()
        }
    }

    // MARK: - Session Management

    /// Check for existing session
    func checkSession() async {
        isLoading = true
        errorMessage = nil

        do {
            let session = try await supabase.auth.session
            currentUser = session.user
            await loadUserProfile()
        } catch {
            // No active session, user needs to sign in
            currentUser = nil
            userProfile = nil
        }

        isLoading = false
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

    /// Sign out current user
    func signOut() async throws {
        isLoading = true
        errorMessage = nil

        do {
            try await supabase.auth.signOut()
            currentUser = nil
            userProfile = nil
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Sign out failed: \(error.localizedDescription)"
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
