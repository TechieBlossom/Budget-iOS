import SwiftUI

struct WelcomeView: View {
    @Bindable var onboardingState: OnboardingState
    
    @Environment(\.appTheme) private var theme
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Header
            VStack(spacing: 16) {
                DSText("Welcome To Budget App", font: .dsLargeTitle)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 80)
                
                DSText("Take control of your finances with smart budget tracking and expense management", font: .dsBody, color: theme.colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)
            }
            
            Spacer()
                .frame(maxHeight: 60)
            
            // Action Buttons
            VStack(spacing: 20) {
                // Get Started Button
                DSButtonCard("GET STARTED", subtitle: "Begin with a fresh budget setup", style: .primary) {
                    onboardingState.userChoice = .start
                    withAnimation(.easeInOut(duration: 0.3)) {
                        onboardingState.goToNextStep()
                    }
                }
                .padding(.horizontal, 24)
                
                // OR Separator
                HStack {
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(theme.colors.secondaryText.opacity(0.3))
                    
                    DSText("OR", font: .dsCaption, color: theme.colors.secondaryText)
                        .padding(.horizontal, 12)
                    
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(theme.colors.secondaryText.opacity(0.3))
                }
                .padding(.horizontal, 24)
                
                // Import Button
                DSButtonCard("IMPORT", subtitle: "Continue with existing budget data", style: .outline) {
                    onboardingState.userChoice = .exportExisting
                    withAnimation(.easeInOut(duration: 0.3)) {
                        onboardingState.goToNextStep()
                    }
                }
                .padding(.horizontal, 24)
            }
            
            Spacer()
        }
        .background(theme.colors.background)
    }
}

#Preview {
    WelcomeView(onboardingState: OnboardingState())
}
