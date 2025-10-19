import SwiftUI

struct CurrencySelectionView: View {
    @Bindable var onboardingState: OnboardingState
    let onBack: () -> Void

    var body: some View {
        DSCurrencySelectionView(
            selectedCurrency: $onboardingState.selectedCurrency,
            showHeader: true,
            headerTitle: "Currency",
            headerSubtitle: "Set currency for tracking expenses",
            onBack: onBack
        )
    }
}

#Preview {
    let state = OnboardingState()
    state.currentStep = .currency
    return CurrencySelectionView(onboardingState: state, onBack: {})
}
