import SwiftUI

struct WelcomeView: View {
    @Bindable var onboardingState: OnboardingState
    
    @Environment(\.appTheme) private var theme
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Header
            VStack(spacing: 16) {
                DSText("Welcome to Budget", font: .dsLargeTitle)
                    .multilineTextAlignment(.center)
                
                DSText("Take control of your finances with smart budget tracking", font: .dsBody, color: theme.colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            
            Spacer()
            
            // Options
            VStack(spacing: 16) {
                DSCard {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(theme.colors.primaryText)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                DSText("Start Fresh", font: .dsHeadline)
                                DSText("Begin with a new budget setup", font: .dsBody, color: theme.colors.secondaryText)
                            }
                            
                            Spacer()
                        }
                        
                        DSButton("Get Started", style: .primary) {
                            onboardingState.userChoice = .start
                        }
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            onboardingState.userChoice == .start ? theme.colors.primaryText : Color.clear,
                            lineWidth: 2
                        )
                )
                
                DSCard {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title2)
                                .foregroundColor(theme.colors.primaryText)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                DSText("Import Data", font: .dsHeadline)
                                DSText("Continue with existing budget data", font: .dsBody, color: theme.colors.secondaryText)
                            }
                            
                            Spacer()
                        }
                        
                        DSButton("Import Existing", style: .outline) {
                            onboardingState.userChoice = .exportExisting
                        }
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            onboardingState.userChoice == .exportExisting ? theme.colors.primaryText : Color.clear,
                            lineWidth: 2
                        )
                )
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Continue Button
            if onboardingState.userChoice != nil {
                DSButton("Continue", style: .primary) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        onboardingState.goToNextStep()
                    }
                }
                .padding(.horizontal, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            Spacer()
        }
        .background(theme.colors.background)
        .animation(.easeInOut(duration: 0.3), value: onboardingState.userChoice)
    }
}

#Preview {
    WelcomeView(onboardingState: OnboardingState())
}