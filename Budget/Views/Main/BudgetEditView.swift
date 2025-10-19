import SwiftUI

struct BudgetEditView: View {
    let budgetManager: BudgetManager
    let onBudgetUpdated: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @State private var showingCurrencySettings = false
    @State private var showingPeriodSettings = false
    @State private var showingCategorySettings = false
    @State private var notificationManager = NotificationManager()

    init(budgetManager: BudgetManager, onBudgetUpdated: (() -> Void)? = nil) {
        self.budgetManager = budgetManager
        self.onBudgetUpdated = onBudgetUpdated
    }

    private var isCurrentBudget: Bool {
        budgetManager.isViewingMostRecentBudget()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DSHeader(
                        title: "Edit Budget",
                        subtitle: budgetManager.budget.budgetName,
                        onBack: {
                            dismiss()
                        }
                    )

                    ScrollView {
                        VStack(spacing: DSSpacing.xl) {
                            // Warning banner for past budgets
                            if !isCurrentBudget {
                                DSCard {
                                    HStack(spacing: DSSpacing.sm) {
                                        Image(systemName: "info.circle.fill")
                                            .font(.dsSmallTitle)
                                            .foregroundColor(theme.colors.textPrimary.opacity(0.6))

                                        VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                                            DSText("Past Budget", font: .dsBody, color: theme.colors.textPrimary)
                                                .fontWeight(.medium)
                                            DSText("You cannot edit settings for past budgets", font: .dsCaption, color: theme.colors.textSecondary)
                                        }

                                        Spacer()
                                    }
                                    .padding(.horizontal, DSSpacing.sm)
                                    .padding(.vertical, DSSpacing.sm)
                                }
                            }

                            // Currency Section
                            SettingsSection(
                                title: "Currency",
                                currentValue: budgetManager.budget.currency.code,
                                description: "Change budget currency",
                                useSmallText: false,
                                isDisabled: !isCurrentBudget
                            ) {
                                showingCurrencySettings = true
                            }

                            // Period Section
                            SettingsSection(
                                title: "Budget Period",
                                currentValue: budgetManager.budget.period.formattedDateRange,
                                description: "Modify budget period and dates",
                                useSmallText: false,
                                isDisabled: !isCurrentBudget
                            ) {
                                showingPeriodSettings = true
                            }

                            // Categories Section
                            SettingsSection(
                                title: "Categories",
                                currentValue: "\(budgetManager.budget.categories.count) categories",
                                description: "Edit, add or remove categories",
                                useSmallText: false,
                                isDisabled: !isCurrentBudget
                            ) {
                                showingCategorySettings = true
                            }

                            // Bottom spacing
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: 24)
                        }
                        .padding(.horizontal, DSSpacing.md)
                        .padding(.top, DSSpacing.xl)
                    }
                }
                .background(theme.colors.background)
                .snackbar(notificationManager)
                .navigationBarBackButtonHidden(true)
                .enableSwipeBack()
                .sheet(isPresented: $showingCurrencySettings) {
                    CurrencySettingsView(
                        currentBudget: budgetManager.budget,
                        onUpdateBudget: { updatedBudget in
                            if budgetManager.updateBudget(updatedBudget) {
                                HapticManager.shared.success()
                                notificationManager.showSuccess("Currency updated successfully!")
                                onBudgetUpdated?()
                            } else {
                                HapticManager.shared.operationFailed()
                                notificationManager.showError("Failed to update currency")
                            }
                        }
                    )
                }
                .sheet(isPresented: $showingPeriodSettings) {
                    PeriodSettingsView(
                        currentBudget: budgetManager.budget,
                        onUpdateBudget: { updatedBudget in
                            if budgetManager.updateBudget(updatedBudget) {
                                HapticManager.shared.success()
                                notificationManager.showSuccess("Period updated successfully!")
                                onBudgetUpdated?()
                            } else {
                                HapticManager.shared.operationFailed()
                                notificationManager.showError("Failed to update period")
                            }
                        }
                    )
                }
                .sheet(isPresented: $showingCategorySettings) {
                    CategorySettingsView(
                        currentBudget: budgetManager.budget,
                        budgetManager: budgetManager,
                        onUpdateBudget: { updatedBudget in
                            if budgetManager.updateBudget(updatedBudget) {
                                HapticManager.shared.success()
                                notificationManager.showSuccess("Categories updated successfully!")
                                onBudgetUpdated?()
                            } else {
                                HapticManager.shared.operationFailed()
                                notificationManager.showError("Failed to update categories")
                            }
                        }
                    )
                }
        }
    }
}
