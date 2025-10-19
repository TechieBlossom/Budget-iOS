import SwiftUI

struct DSBudgetPreviewCard: View {
    let title: String
    let budgetName: String
    let periodText: String
    let budgetType: BudgetType

    @Environment(\.appTheme) private var theme

    var body: some View {
        DSCard {
            VStack(spacing: DSSpacing.sm) {
                HStack {
                    DSText(title, font: .dsHeadline)
                    Spacer()
                }

                HStack {
                    DSText("Budget Name:", font: .dsBody)
                    Spacer()
                    DSText(budgetName.isEmpty ? "Unnamed Budget" : budgetName, font: .dsBody, color: theme.colors.textPrimary)
                }

                HStack {
                    DSText("Period:", font: .dsBody)
                    Spacer()
                    DSText(periodText, font: .dsBody, color: theme.colors.textPrimary)
                }

                HStack {
                    DSText("Type:", font: .dsBody)
                    Spacer()
                    DSText(budgetType == .monthly ? "Monthly" : "Custom", font: .dsBody, color: theme.colors.textPrimary)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: DSSpacing.md) {
        DSBudgetPreviewCard(
            title: "Budget Preview",
            budgetName: "January 2025 Budget",
            periodText: "Jan 1 - Jan 31",
            budgetType: .monthly
        )

        DSBudgetPreviewCard(
            title: "New Period Preview",
            budgetName: "Holiday Fund",
            periodText: "Dec 15 - Jan 5",
            budgetType: .custom
        )
    }
    .padding(DSSpacing.md)
}
