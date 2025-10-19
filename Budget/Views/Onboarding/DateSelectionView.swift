import SwiftUI

struct DateSelectionView: View {
    @Bindable var onboardingState: OnboardingState
    let onBack: () -> Void

    var body: some View {
        DSBudgetPeriodManagementView(
            budgetName: $onboardingState.budgetName,
            startDate: $onboardingState.selectedStartDate,
            endDate: $onboardingState.selectedEndDate,
            budgetType: $onboardingState.selectedBudgetType,
            showHeader: true,
            headerTitle: "Dates",
            headerSubtitle: "Set start and end dates for budget period",
            onBack: onBack
        )
    }
}

#Preview {
    @Previewable let state = OnboardingState()
    state.currentStep = .dateSelection
    state.selectedBudgetType = .monthly
    return DateSelectionView(onboardingState: state, onBack: {})
}
