import SwiftUI
import SwiftData

struct BudgetExpiredView: View {
    let budgetManager: any BudgetManagerProtocol
    let isManualEnd: Bool
    let onContinueWithSameSettings: () -> Void
    let onChangeBudgetSettings: () -> Void
    let onCancel: (() -> Void)?

    init(budgetManager: any BudgetManagerProtocol,
         isManualEnd: Bool = false,
         onContinueWithSameSettings: @escaping () -> Void,
         onChangeBudgetSettings: @escaping () -> Void,
         onCancel: (() -> Void)? = nil) {
        self.budgetManager = budgetManager
        self.isManualEnd = isManualEnd
        self.onContinueWithSameSettings = onContinueWithSameSettings
        self.onChangeBudgetSettings = onChangeBudgetSettings
        self.onCancel = onCancel
    }

    @Environment(\.appTheme) private var theme

    private var currentDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: Date())
    }

    private var budgetPeriodText: String {
        let budget = budgetManager.budget

        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM"

        let startString = formatter.string(from: budget.period.startDate)
        let endString = formatter.string(from: budget.period.endDate)

        return "\(startString) to \(endString)"
    }

    var body: some View {
        ZStack {
            // Background overlay
            theme.colors.background.opacity(0.95)
                .ignoresSafeArea()

            VStack(spacing: DSSpacing.xxl) {
                // Maintain spacing for natural expiration
                Spacer()
                    .frame(height: 32)
                Spacer()

                // Icon and main message
                VStack(spacing: DSSpacing.xl) {
                    // Icon
                    Image(systemName: isManualEnd ? "questionmark.circle" : "calendar.badge.exclamationmark")
                        .font(.dsLargeTitle)
                        .fontWeight(.light)
                        .foregroundColor(theme.colors.textPrimary)

                    // Main message
                    VStack(spacing: DSSpacing.sm) {
                        DSText(isManualEnd ? "End Budget Confirmation" : "Budget Period Ended",
                               font: .dsTitle, color: theme.colors.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)

                        DSText(isManualEnd ? "Are you sure you want to end your current budget?" : "Your budget was active from",
                               font: .dsBody, color: theme.colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)

                        DSText(budgetPeriodText, font: .dsHeadline, color: theme.colors.textPrimary)
                            .multilineTextAlignment(.center)

                        if !isManualEnd {
                            DSText("Today is \(currentDate)", font: .dsBody, color: theme.colors.textSecondary)
                                .multilineTextAlignment(.center)
                        } else {
                            DSText("This will end your budget early and you can start a new one",
                                   font: .dsBody, color: theme.colors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.top, DSSpacing.sm)
                        }
                    }
                }

                // Action buttons
                VStack(spacing: DSSpacing.md) {
                    DSText(isManualEnd ? "Choose how to proceed:" : "What would you like to do next?",
                           font: .dsSubtitle, color: theme.colors.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, DSSpacing.xs)

                    // Continue with same settings
                    DSButton(
                        isManualEnd ? "End & Create New Budget" : "Continue with Same Settings",
                        style: .primary,
                        fullWidth: true,
                        action: onContinueWithSameSettings
                    )

                    // Change budget settings
                    DSButton(
                        isManualEnd ? "End & Configure New Budget" : "Change Budget Settings",
                        style: .outline,
                        fullWidth: true,
                        action: onChangeBudgetSettings
                    )

                    // Cancel option (only for manual end)
                    if isManualEnd, let onCancel = onCancel {
                        VStack(spacing: DSSpacing.md) {
                            // Separator
                            HStack {
                                Rectangle()
                                    .fill(theme.colors.textSecondary.opacity(0.3))
                                    .frame(height: 1)
                                DSText("Changed my mind", font: .dsCaption, color: theme.colors.textSecondary)
                                    .padding(.horizontal, DSSpacing.md)
                                    .fixedSize(horizontal: true, vertical: false)
                                Rectangle()
                                    .fill(theme.colors.textSecondary.opacity(0.3))
                                    .frame(height: 1)
                            }
                            .padding(.top, DSSpacing.xs)

                            // Cancel button
                            DSButton(
                                "I don't want to end budget early",
                                style: .outline,
                                fullWidth: true,
                                action: onCancel
                            )
                        }
                    }
                }
                .padding(.horizontal, DSSpacing.md)

                Spacer()

                // Helper text
                DSText(isManualEnd ?
                       "Your transaction data will be preserved and a new budget will be created" :
                       "Don't worry, all your transaction data has been preserved!",
                       font: .dsCaption,
                       color: theme.colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DSSpacing.xxl)
                    .padding(.bottom, DSSpacing.xxl)
            }
            .padding(.horizontal, DSSpacing.xl)
        }
    }
}

#Preview {
    // Simple preview without SwiftData dependency
    BudgetExpiredView(
        budgetManager: MockBudgetManager(budget: Budget.createSample()),
        isManualEnd: true,
        onContinueWithSameSettings: {
            print("Continue with same settings")
        },
        onChangeBudgetSettings: {
            print("Change budget settings")
        },
        onCancel: {
            print("Cancel")
        }
    )
    .environment(\.appTheme, AppTheme.shared)
}
