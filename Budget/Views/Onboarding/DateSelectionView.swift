import SwiftUI

struct DateSelectionView: View {
    @Bindable var onboardingState: OnboardingState
    
    @Environment(\.appTheme) private var theme
    
    var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 12) {
                DSText("Budget Period", font: .dsTitle)
                    .multilineTextAlignment(.center)
                
                DSText("Choose when you want your budget period to start", font: .dsBody, color: theme.colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 16)
            
            // Date Selection
            DSCard {
                VStack(spacing: 20) {
                    HStack {
                        Image(systemName: "calendar")
                            .font(.title2)
                            .foregroundColor(theme.colors.primaryText)
                        
                        DSText("Budget Start Date", font: .dsHeadline)
                        
                        Spacer()
                    }
                    
                    DatePicker(
                        "Start Date",
                        selection: $onboardingState.selectedStartDate,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                }
            }
            .padding(.horizontal, 24)
            
            // Budget Period Preview
            DSCard {
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .font(.title2)
                            .foregroundColor(theme.colors.primaryText)
                        
                        DSText("Budget Preview", font: .dsHeadline)
                        
                        Spacer()
                    }
                    
                    VStack(spacing: 12) {
                        // Budget Name
                        HStack {
                            DSText("Budget Name:", font: .dsBody)
                            Spacer()
                            DSText(onboardingState.budgetPeriod.name, font: .dsHeadline)
                        }
                        
                        Divider()
                            .background(theme.colors.secondaryText.opacity(0.3))
                        
                        // Date Range
                        HStack {
                            DSText("Period:", font: .dsBody)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                DSText(formatDate(onboardingState.budgetPeriod.startDate), font: .dsBody)
                                DSText("to", font: .dsCaption)
                                DSText(formatDate(onboardingState.budgetPeriod.endDate), font: .dsBody)
                            }
                        }
                        
                        Divider()
                            .background(theme.colors.secondaryText.opacity(0.3))
                        
                        // Duration
                        HStack {
                            DSText("Duration:", font: .dsBody)
                            Spacer()
                            DSText("\(onboardingState.budgetPeriod.durationInDays) days", font: .dsHeadline)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Navigation Buttons
            HStack(spacing: 16) {
                DSButton("Back", style: .outline) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        onboardingState.goToPreviousStep()
                    }
                }
                
                DSButton("Continue", style: .primary) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        onboardingState.goToNextStep()
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background(theme.colors.background)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    let state = OnboardingState()
    state.currentStep = .dateSelection
    return DateSelectionView(onboardingState: state)
}