import SwiftUI

struct CurrencySettingsView: View {
    let currentBudget: Budget
    let onUpdateBudget: (Budget) -> Void

    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCurrency: Currency?

    init(currentBudget: Budget, onUpdateBudget: @escaping (Budget) -> Void) {
        self.currentBudget = currentBudget
        self.onUpdateBudget = onUpdateBudget
        self._selectedCurrency = State(initialValue: currentBudget.currency)
    }

    private var allCurrencies: [Currency] {
        Currency.search("")
    }

    private var hasChanges: Bool {
        selectedCurrency?.id != currentBudget.currency.id
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: DSSpacing.sm) {
                        ForEach(allCurrencies, id: \.id) { currency in
                            Button(action: {
                                selectedCurrency = currency
                            }) {
                                HStack(spacing: DSSpacing.sm) {
                                    // Currency Info
                                    VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                                        DSText(currency.name, font: .dsHeadline, color: theme.colors.textPrimary)
                                        DSText(currency.code, font: .dsCaption, color: theme.colors.textSecondary)
                                    }

                                    Spacer()

                                    // Selection Indicator
                                    if selectedCurrency?.id == currency.id {
                                        Image(systemName: "checkmark")
                                            .font(.dsHeadline)
                                            .foregroundColor(theme.colors.primary)
                                    }
                                }
                                .padding(DSSpacing.md)
                                .background(theme.colors.surface)
                                .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, DSSpacing.md)
                    .padding(.top, DSSpacing.md)
                }
            }
            .background(theme.colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        DSText("Change Currency", font: .dsHeadline, color: theme.colors.textPrimary)
                        DSText(currentBudget.budgetName, font: .dsCaption, color: theme.colors.textSecondary)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Image(systemName: "xmark")
                        .font(.dsHeadline)
                        .foregroundColor(theme.colors.textPrimary)
                        .onTapGesture {
                            dismiss()
                        }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        saveCurrencyChanges()
                    }) {
                        Image(systemName: "checkmark")
                            .font(.dsHeadline)
                            .foregroundColor(hasChanges ? theme.colors.primary : theme.colors.textSecondary)
                    }
                    .disabled(!hasChanges)
                }
            }
        }
    }
    
    private func saveCurrencyChanges() {
        guard let selectedCurrency = selectedCurrency else { return }

        let updatedBudget = Budget(
            id: currentBudget.id,
            period: currentBudget.period,
            currency: selectedCurrency, // New currency
            categories: currentBudget.categories,
            categoryAmounts: currentBudget.categoryAmounts
        )

        onUpdateBudget(updatedBudget)
        dismiss()
    }
}

#Preview {
    let budget = Budget.createSample()
    
    CurrencySettingsView(currentBudget: budget) { updatedBudget in
        print("Updated budget with currency: \(updatedBudget.currency)")
    }
}
