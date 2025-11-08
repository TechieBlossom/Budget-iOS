import SwiftUI

struct DSCurrencyList: View {
    @Binding var selectedCurrency: Currency?
    @Binding var searchText: String

    @Environment(\.appTheme) private var theme

    private var filteredCurrencies: [Currency] {
        Currency.search(searchText)
    }

    var body: some View {
        VStack(spacing: DSSpacing.md) {
            // Search Field
            DSTextField("Search currencies", text: $searchText)
                .padding(.horizontal, DSSpacing.md)

            // Currency List
            ScrollView {
                LazyVStack(spacing: DSSpacing.sm) {
                    ForEach(filteredCurrencies, id: \.id) { currency in
                        Button(action: {
                            withAnimation(.easeOut(duration: 0.2)) {
                                selectedCurrency = currency
                            }
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
    }
}

#Preview {
    @Previewable @State var selectedCurrency: Currency? = Currency(code: "USD", name: "US Dollar", symbol: "USD")
    @Previewable @State var searchText = ""

    DSCurrencyList(
        selectedCurrency: $selectedCurrency,
        searchText: $searchText
    )
}
