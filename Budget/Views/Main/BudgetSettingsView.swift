import SwiftUI

struct BudgetSettingsView: View {
    let budgetManager: any BudgetManagerProtocol
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    
    var body: some View {
        VStack(spacing: 0) {
            DSHeader(
                title: "Budget Settings",
                subtitle: budgetManager.budget.budgetName,
                onBack: {
                    dismiss()
                }
            )
            
            // Settings content - placeholder for now
            VStack(spacing: 24) {
                Spacer()
                
                Image(systemName: "gearshape")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(theme.colors.secondaryText)
                
                VStack(spacing: 8) {
                    DSText("Settings", font: .dsHeadline, color: theme.colors.primaryText)
                    DSText("Budget settings will be available here", font: .dsBody, color: theme.colors.secondaryText)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
        }
        .background(theme.colors.background)
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    BudgetSettingsView(budgetManager: MockBudgetManager(budget: Budget.createSample()))
        .background(AppTheme.shared.colors.background)
}