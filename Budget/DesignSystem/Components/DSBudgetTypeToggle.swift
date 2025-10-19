import SwiftUI

struct DSBudgetTypeToggle: View {
    @Binding var selectedBudgetType: BudgetType
    let onToggle: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        DSCard {
            HStack(spacing: DSSpacing.md) {
                DSText("Custom End Date?", font: .dsBody, color: theme.colors.textPrimary)

                Spacer()

                Toggle("", isOn: Binding(
                    get: { selectedBudgetType == .custom },
                    set: { newValue in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedBudgetType = newValue ? .custom : .monthly
                        }
                        onToggle()
                    }
                ))
                .labelsHidden()
                .tint(theme.colors.primary)
            }
            .padding(.vertical, DSSpacing.xxs)
        }
    }
}

#Preview {
    @Previewable @State var budgetType: BudgetType = .monthly

    VStack(spacing: DSSpacing.md) {
        DSBudgetTypeToggle(selectedBudgetType: $budgetType) {
            print("Budget type toggled to: \(budgetType)")
        }

        DSText("Current type: \(budgetType == .monthly ? "Monthly" : "Custom")", font: .dsBody)
    }
    .padding(DSSpacing.md)
}
