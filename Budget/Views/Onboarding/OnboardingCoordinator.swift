import SwiftUI

struct OnboardingCoordinator: View {
    @State private var onboardingState = OnboardingState()
    
    @Environment(\.appTheme) private var theme
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress Bar
            ProgressBarView(progress: onboardingState.currentStep.progress)
            
            // Current Step View
            Group {
                switch onboardingState.currentStep {
                case .welcome:
                    WelcomeView(onboardingState: onboardingState)
                case .currency:
                    CurrencySelectionView(onboardingState: onboardingState)
                case .dateSelection:
                    DateSelectionView(onboardingState: onboardingState)
                case .categorySetup:
                    CategorySetupView(onboardingState: onboardingState)
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
        }
        .background(theme.colors.background)
        .animation(.easeInOut(duration: 0.3), value: onboardingState.currentStep)
    }
}

struct ProgressBarView: View {
    let progress: Double
    
    @Environment(\.appTheme) private var theme
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(theme.colors.secondaryText.opacity(0.2))
                        .frame(height: 4)
                    
                    Rectangle()
                        .fill(theme.colors.primaryText)
                        .frame(width: geometry.size.width * progress, height: 4)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 4)
            
            // Progress Text
            HStack {
                DSText("Step \(Int(progress * 4)) of 4", font: .dsCaption)
                Spacer()
                DSText("\(Int(progress * 100))%", font: .dsCaption)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
    }
}

#Preview {
    OnboardingCoordinator()
}