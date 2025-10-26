import SwiftUI

struct WelcomeView: View {
    @Bindable var onboardingState: OnboardingState

    @Environment(\.appTheme) private var theme
    
    var body: some View {
        VStack(spacing: 0) {
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
                    withAnimation(.easeInOut(duration: 0.3)) {
                        onboardingState.goToNextStep()
                    }
                }
                .padding(.horizontal, DSSpacing.xl)
            }

            Spacer()
        }
        .background(theme.colors.background)
    }
}

#Preview {
    WelcomeView(onboardingState: OnboardingState())
}
