import SwiftUI

struct OnboardingCoordinator: View {
    @State private var onboardingState = OnboardingState()
    let onComplete: (Budget) -> Void
    
    @Environment(\.appTheme) private var theme
    
    init(onComplete: @escaping (Budget) -> Void = { _ in }) {
        self.onComplete = onComplete
    }
    
    var body: some View {
        ZStack {
            // Main content area
            VStack(spacing: 0) {
                // Current Step View
                Group {
                    switch onboardingState.currentStep {
                    case .welcome:
                        WelcomeView(onboardingState: onboardingState)
                    case .currency:
                        CurrencySelectionView(onboardingState: onboardingState)
                    case .budgetTypeSelection:
                        // Skip this step since budget type selection is now part of DateSelectionView
                        DateSelectionView(onboardingState: onboardingState)
                    case .dateSelection:
                        DateSelectionView(onboardingState: onboardingState)
                    case .categorySetup:
                        CategorySetupView(onboardingState: onboardingState)
                    }
                }
                .transition(.opacity)
                
            }
            
            // Fixed Back Button at Top (only show on non-welcome steps)
            if !onboardingState.isFirstStep {
                VStack {
                    HStack {
                        DSIconButton(type: .back) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                onboardingState.goToPreviousStep()
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    Spacer()
                }
            }
            
            // Fixed Navigation Area (only show on non-welcome steps)
            if !onboardingState.isFirstStep {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        
                        // Next/Complete Button
                        Group {
                            if onboardingState.isLastStep {
                                DSIconButton(
                                    type: .complete(progress: onboardingState.currentStep.progress)
                                ) {
                                    let completedBudget = onboardingState.createCompletedBudget()
                                    onComplete(completedBudget)
                                }
                            } else {
                                DSIconButton(
                                    type: .next(progress: onboardingState.currentStep.progress)
                                ) {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        onboardingState.goToNextStep()
                                    }
                                }
                                .disabled(!onboardingState.canProceed)
                                .opacity(onboardingState.canProceed ? 1.0 : 0.6)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
        }
        .background(theme.colors.background)
        .animation(.easeInOut(duration: 0.3), value: onboardingState.currentStep)
    }
}


#Preview {
    OnboardingCoordinator()
}