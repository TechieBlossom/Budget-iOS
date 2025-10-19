import SwiftUI

/// Reusable currency selection UI component for onboarding and settings
struct DSCurrencySelectionView: View {
    @Binding var selectedCurrency: Currency?

    let showHeader: Bool
    let headerTitle: String?
    let headerSubtitle: String?
    let onBack: (() -> Void)?

    @Environment(\.appTheme) private var theme

    init(
        selectedCurrency: Binding<Currency?>,
        showHeader: Bool = false,
        headerTitle: String? = nil,
        headerSubtitle: String? = nil,
        onBack: (() -> Void)? = nil
    ) {
        self._selectedCurrency = selectedCurrency
        self.showHeader = showHeader
        self.headerTitle = headerTitle
        self.headerSubtitle = headerSubtitle
        self.onBack = onBack
    }

    private var allCurrencies: [Currency] {
        Currency.search("")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Optional Header (for onboarding flow)
            if showHeader, let title = headerTitle, let subtitle = headerSubtitle, let backAction = onBack {
                DSHeader(
                    title: title,
                    subtitle: subtitle,
                    buttonType: .back,
                    onBack: backAction
                )
            }

            // Currency List without search
            ScrollView {
                LazyVStack(spacing: DSSpacing.sm) {
                    ForEach(allCurrencies, id: \.id) { currency in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
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
        .background(theme.colors.background)
    }
}

#Preview("Onboarding Style") {
    @Previewable @State var selectedCurrency: Currency? = nil

    return DSCurrencySelectionView(
        selectedCurrency: $selectedCurrency,
        showHeader: true,
        headerTitle: "Currency",
        headerSubtitle: "Set currency for tracking expenses",
        onBack: {}
    )
}

#Preview("Settings Style") {
    @Previewable @State var selectedCurrency: Currency? = Currency(code: "USD", name: "US Dollar", symbol: "$")

    return DSCurrencySelectionView(
        selectedCurrency: $selectedCurrency,
        showHeader: false
    )
}
