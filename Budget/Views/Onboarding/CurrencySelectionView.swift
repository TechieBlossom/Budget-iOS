import SwiftUI

struct CurrencySelectionView: View {
    @Bindable var onboardingState: OnboardingState
    
    @Environment(\.appTheme) private var theme
    
    private var filteredCurrencies: [Currency] {
        Currency.search(onboardingState.currencySearchText)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    DSText("Select Your Currency", font: .dsTitle)
                    DSText("Set your preferred currency for tracking expenses", font: .dsBody, color: theme.colors.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Image(systemName: "globe")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(theme.colors.primaryText)
            }
            .padding(.horizontal, 16)
            .padding(.top, 80) // Space for back button
            .padding(.bottom, 16)
            
            // Search Field
            DSTextField("Search currencies", text: $onboardingState.currencySearchText)
                .padding(.horizontal, 16)
            
            // Currency List - Full Screen
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredCurrencies, id: \.id) { currency in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                onboardingState.selectedCurrency = currency
                            }
                        }) {
                            HStack(spacing: 16) {
                                // Currency Info (removed symbol)
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
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .background(theme.colors.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        onboardingState.selectedCurrency?.id == currency.id 
                                        ? theme.colors.primaryText 
                                        : Color.clear, 
                                        lineWidth: 2
                                    )
                            )
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, 16)
                    }
                    
                    // Bottom spacing to ensure last item is visible above next button
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 80)
                }
            }
        }
        .background(theme.colors.background)
    }
}

#Preview {
    let state = OnboardingState()
    state.currentStep = .currency
    return CurrencySelectionView(onboardingState: state)
}
