import SwiftUI

struct PeriodSettingsView: View {
    let currentBudget: Budget
    let onUpdateBudget: (Budget) -> Void

    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var budgetName: String
    @State private var startDate: Date
    @State private var endDate: Date?
    @State private var budgetType: BudgetType

    init(currentBudget: Budget, onUpdateBudget: @escaping (Budget) -> Void) {
        self.currentBudget = currentBudget
        self.onUpdateBudget = onUpdateBudget
        self._budgetName = State(initialValue: currentBudget.budgetName)
        self._startDate = State(initialValue: currentBudget.period.startDate)
        self._endDate = State(initialValue: currentBudget.period.endDate)
        self._budgetType = State(initialValue: currentBudget.period.type)
    }

    private var hasChanges: Bool {
        let calendar = Calendar.current

        // Check if dates changed
        if !calendar.isDate(startDate, inSameDayAs: currentBudget.period.startDate) {
            return true
        }

        if let currentEnd = endDate, !calendar.isDate(currentEnd, inSameDayAs: currentBudget.period.endDate) {
            return true
        }

        // Check if budget type or name changed
        return budgetType != currentBudget.period.type || budgetName != currentBudget.budgetName
    }

    var body: some View {
        NavigationStack {
            DSBudgetPeriodManagementView(
                budgetName: $budgetName,
                startDate: $startDate,
                endDate: $endDate,
                budgetType: $budgetType,
                showHeader: false
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        DSText("Budget Period", font: .dsHeadline, color: theme.colors.textPrimary)
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
                    Image(systemName: "checkmark")
                        .font(.dsHeadline)
                        .foregroundColor(hasChanges ? theme.colors.primary : theme.colors.textSecondary)
                        .onTapGesture {
                            if hasChanges {
                                savePeriodChanges()
                            }
                        }
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func savePeriodChanges() {
        guard let finalEndDate = endDate else { return }

        let newPeriod = BudgetPeriod(
            type: budgetType,
            startDate: startDate,
            endDate: finalEndDate,
            customName: budgetName
        )

        let updatedBudget = Budget(
            id: currentBudget.id,
            period: newPeriod,
            currency: currentBudget.currency,
            categories: currentBudget.categories,
            categoryAmounts: currentBudget.categoryAmounts
        )

        onUpdateBudget(updatedBudget)
        dismiss()
    }
}

#Preview {
    let budget = Budget.createSample()
    
    PeriodSettingsView(currentBudget: budget) { updatedBudget in
        print("Updated budget with period: \(updatedBudget.period)")
    }
}
