import SwiftUI

/// Card showing summary of filtered transactions with total amount
struct DSFilterSummaryCard: View {
    let filteredAmount: Double
    let filteredCount: Int
    let totalAmount: Double
    let totalCount: Int
    let currencyCode: String

    @Environment(\.appTheme) private var theme

    private var percentageOfTotal: Double {
        guard totalAmount > 0 else { return 0 }
        return (filteredAmount / totalAmount) * 100
    }

    private var amountFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }

    var body: some View {
        DSCard {
            VStack(spacing: DSSpacing.sm) {
                // Amount Display
                HStack(alignment: .firstTextBaseline, spacing: DSSpacing.xxs) {
                    if let formattedAmount = amountFormatter.string(from: NSNumber(value: filteredAmount)) {
                        DSText(formattedAmount, font: .dsBody, color: theme.colors.textPrimary)
                            .fontWeight(.bold)
                    }

                    DSText(currencyCode, font: .dsCaption, color: theme.colors.textSecondary)

                    Spacer()
                    
                    DSText(String(format: "%.1f%% of total expenses", percentageOfTotal), font: .dsCaption, color: theme.colors.primary)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: DSSpacing.lg) {
        // Example with some filtered results
        DSFilterSummaryCard(
            filteredAmount: 1250.50,
            filteredCount: 15,
            totalAmount: 5000.00,
            totalCount: 45,
            currencyCode: "USD"
        )

        // Example with most results filtered
        DSFilterSummaryCard(
            filteredAmount: 250.00,
            filteredCount: 5,
            totalAmount: 5000.00,
            totalCount: 45,
            currencyCode: "EUR"
        )
    }
    .background(AppTheme.shared.colors.background)
}
