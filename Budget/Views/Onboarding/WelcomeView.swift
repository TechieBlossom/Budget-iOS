import SwiftUI

struct WelcomeView: View {
    @Bindable var onboardingState: OnboardingState

    @Environment(\.appTheme) private var theme
    @Environment(AuthManager.self) private var authManager
    @State private var showingLogoutConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Logout button in top-right corner
            HStack {
                Spacer()
                Button(action: {
                    HapticManager.shared.buttonTap()
                    showingLogoutConfirmation = true
                }) {
                    HStack(spacing: DSSpacing.xxs) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.dsBody)
                        DSText("Logout", font: .dsBody, color: theme.colors.textSecondary)
                    }
                    .padding(.horizontal, DSSpacing.md)
                    .padding(.vertical, DSSpacing.sm)
                    .background(theme.colors.surfaceVariant)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, DSSpacing.md)
            .padding(.top, DSSpacing.md)

            Spacer()
            
            // Header
            VStack(spacing: DSSpacing.md) {
                DSText("Dhaarã", font: .dsLargeTitle)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DSSpacing.xxl)
                
                DSText("The mindful flow of your money", font: .dsTitle)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DSSpacing.xxl)
            }
            
            Spacer()
                .frame(maxHeight: 60)
            
            // Action Buttons
            VStack(spacing: DSSpacing.lg) {
                // Get Started Button
                DSButtonCard("GET STARTED", subtitle: "Begin with a fresh budget setup", style: .primary) {
                    onboardingState.userChoice = .start
                    withAnimation(.easeOut(duration: 0.3)) {
                        onboardingState.goToNextStep()
                    }
                }
                .padding(.horizontal, DSSpacing.xl)
            }

            Spacer()
        }
        .background(theme.colors.background)
        .alert("Sign Out", isPresented: $showingLogoutConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                Task {
                    try? await authManager.signOut()
                }
            }
        } message: {
            Text("Are you sure you want to sign out? Your data is synced to the cloud and will be available when you sign in again.")
        }
    }
}

#Preview {
    WelcomeView(onboardingState: OnboardingState())
}
