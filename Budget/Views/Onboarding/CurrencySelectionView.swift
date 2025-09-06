import SwiftUI

struct CurrencySelectionView: View {
    @Bindable var onboardingState: OnboardingState
    
    @Environment(\.appTheme) private var theme
    
    private var filteredCurrencies: [Currency] {
        Currency.search(onboardingState.currencySearchText)
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                DSText("Select Your Currency", font: .dsTitle)
                    .multilineTextAlignment(.center)
                
                DSText("Choose the currency you'll use for budgeting", font: .dsBody, color: theme.colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 16)
            
            // Search Field
            VStack(spacing: 16) {
                DSTextField("Search currencies", text: $onboardingState.currencySearchText)
                    .padding(.horizontal, 24)
                
                if !onboardingState.currencySearchText.isEmpty && filteredCurrencies.isEmpty {
                    DSCard {
                        DSText("No currencies found", font: .dsBody, color: theme.colors.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 16)
                    }
                    .padding(.horizontal, 24)
                }
            }
            
            // Currency List
            DSList(filteredCurrencies) { currency in
                DSListItem(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        onboardingState.selectedCurrency = currency
                    }
                }) {
                    HStack(spacing: 16) {
                        // Currency Symbol
                        Text(currency.symbol)
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(theme.colors.primaryText)
                            .frame(width: 40, alignment: .center)
                        
                        // Currency Info
                        VStack(alignment: .leading, spacing: 4) {
                            DSText(currency.name, font: .dsHeadline)
                            DSText(currency.code, font: .dsBody, color: theme.colors.secondaryText)
                        }
                        
                        Spacer()
                        
                        // Selection Indicator
                        if onboardingState.selectedCurrency?.id == currency.id {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(theme.colors.primaryText)
                        } else {
                            Image(systemName: "circle")
                                .font(.title3)
                                .foregroundColor(theme.colors.secondaryText)
                        }
                    }
                }
            }
            
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
                .disabled(!onboardingState.canProceed)
                .opacity(onboardingState.canProceed ? 1.0 : 0.6)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background(theme.colors.background)
    }
}

#Preview {
    let state = OnboardingState()
    state.currentStep = .currency
    return CurrencySelectionView(onboardingState: state)
}