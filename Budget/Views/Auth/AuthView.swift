//
//  AuthView.swift
//  Budget
//
//  Created for Supabase integration
//

import SwiftUI
import GoogleSignInSwift

struct AuthView: View {
    @Environment(\.appTheme) private var theme
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        ZStack {
            // Background
            theme.colors.background
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // App Logo/Branding
                VStack(spacing: 16) {
                    // App icon or logo would go here
                    DSText("Budget", font: .dsLargeTitle)
                        .fontWeight(.bold)

                    DSText(
                        "Track your expenses, achieve your goals",
                        font: .dsBody,
                        color: theme.colors.textSecondary
                    )
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                }

                Spacer()

                // Sign In Buttons
                VStack(spacing: 16) {
                    // Apple Sign In Button
                    AppleSignInButton()
                        .disabled(authManager.isLoading)
                        .opacity(authManager.isLoading ? 0.6 : 1.0)

                    // Google Sign In Button
                    GoogleSignInButton()
                        .disabled(authManager.isLoading)
                        .opacity(authManager.isLoading ? 0.6 : 1.0)
                }
                .padding(.horizontal, 32)

                // Loading Indicator
                if authManager.isLoading {
                    ProgressView()
                        .tint(theme.colors.textPrimary)
                        .padding(.top, 8)
                }

                // Error Message
                if let error = authManager.errorMessage {
                    DSText(error, font: .dsCaption, color: .red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 8)
                }

                Spacer()

                // Terms & Privacy
                VStack(spacing: 8) {
                    DSText(
                        "By signing in, you agree to our",
                        font: .dsCaption,
                        color: theme.colors.textSecondary
                    )

                    HStack(spacing: 4) {
                        DSText(
                            "Terms of Service",
                            font: .dsCaption,
                            color: theme.colors.textPrimary
                        )
                        .fontWeight(.semibold)

                        DSText(
                            "and",
                            font: .dsCaption,
                            color: theme.colors.textSecondary
                        )

                        DSText(
                            "Privacy Policy",
                            font: .dsCaption,
                            color: theme.colors.textPrimary
                        )
                        .fontWeight(.semibold)
                    }
                }
                .padding(.bottom, 32)
            }
        }
    }
}

// MARK: - Apple Sign In Button

private struct AppleSignInButton: View {
    @Environment(\.appTheme) private var theme
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        Button {
            Task {
                try? await authManager.signInWithApple()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)

                DSText("Continue with Apple", font: .dsBody, color: .white)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.black)
            .cornerRadius(12)
        }
    }
}

// MARK: - Google Sign In Button

private struct GoogleSignInButton: View {
    @Environment(\.appTheme) private var theme
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        Button {
            Task {
                // Get the root view controller
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let rootViewController = windowScene.windows.first?.rootViewController else {
                    return
                }

                try? await authManager.signInWithGoogle(presenting: rootViewController)
            }
        } label: {
            HStack(spacing: 12) {
                // Google logo (using SF Symbol as placeholder)
                Image(systemName: "g.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)

                DSText("Continue with Google", font: .dsBody, color: .white)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.26, green: 0.52, blue: 0.96), Color(red: 0.22, green: 0.45, blue: 0.85)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
    }
}

#Preview {
    AuthView()
        .environment(AuthManager())
        .environment(\.appTheme, AppTheme.shared)
}
