import SwiftUI

struct BudgetSettingsView: View {
    let budgetManager: BudgetManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Environment(AuthManager.self) private var authManager
    @State private var showingCurrencySettings = false
    @State private var showingPeriodSettings = false
    @State private var showingCategorySettings = false
    @State private var showingEndBudgetConfirmation = false
    @State private var showingSignOutConfirmation = false
    @State private var notificationManager = NotificationManager()

    private var isCurrentBudget: Bool {
        budgetManager.isViewingMostRecentBudget()
    }

    var body: some View {
        VStack(spacing: 0) {
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

                        // Divider
                        Divider()
                            .padding(.vertical, DSSpacing.xs)

                        // Account Section - Sign Out
                        SignOutSection {
                            showingSignOutConfirmation = true
                        }

                        // Divider
                        if isCurrentBudget {
                            Divider()
                                .padding(.vertical, DSSpacing.xs)

                            // End Budget Section (only for current budget)
                            EndBudgetSection {
                                showingEndBudgetConfirmation = true
                            }
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
            .navigationTitle("Budget Settings")
            .navigationBarTitleDisplayMode(.inline)
            .customNavigationBarAppearance()
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        DSText("Budget Settings", font: .dsBody, color: theme.colors.textPrimary)
                            .fontWeight(.semibold)
                        DSText(budgetManager.budget.budgetName, font: .dsCaption, color: theme.colors.textSecondary)
                    }
                }
            }
            .snackbar(notificationManager)
            .sheet(isPresented: $showingCurrencySettings) {
                CurrencySettingsView(
                    currentBudget: budgetManager.budget,
                    onUpdateBudget: { updatedBudget in
                        if budgetManager.updateBudget(updatedBudget) {
                            HapticManager.shared.success()
                            notificationManager.showSuccess("Currency updated successfully!")
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
                        } else {
                            HapticManager.shared.operationFailed()
                            notificationManager.showError("Failed to update categories")
                        }
                    }
                )
            }
            .fullScreenCover(isPresented: $showingEndBudgetConfirmation) {
                BudgetExpiredView(
                    budgetManager: budgetManager,
                    isManualEnd: true,
                    onContinueWithSameSettings: {
                        Task { @MainActor in
                            if await budgetManager.createNextPeriodBudget() {
                                showingEndBudgetConfirmation = false
                                dismiss() // Go back to main app
                                // Schedule notifications for the new budget
                                if let budget = budgetManager.currentBudget {
                                    NotificationService.shared.scheduleBudgetEndNotifications(for: budget)
                                }
                            }
                        }
                    },
                    onChangeBudgetSettings: {
                        showingEndBudgetConfirmation = false
                        // Stay in settings to configure new budget
                    },
                    onCancel: {
                        showingEndBudgetConfirmation = false
                    }
                )
            }
            .alert("Sign Out", isPresented: $showingSignOutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    Task {
                        try? await authManager.signOut()
                        dismiss()
                    }
                }
            } message: {
                Text("Are you sure you want to sign out? Your data is synced to the cloud and will be available when you sign in again.")
            }
    }
}

struct SettingsSection: View {
    let title: String
    let currentValue: String
    let description: String
    let useSmallText: Bool
    let isDisabled: Bool
    let action: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: {
            if !isDisabled {
                action()
            }
        }) {
            DSCard(padding: 8) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                        DSText(title, font: .dsHeadline, color: isDisabled ? theme.colors.textSecondary : theme.colors.textPrimary)
                        DSText(description, font: .dsCaption, color: theme.colors.textSecondary)
                    }

                    Spacer()

                    HStack(spacing: DSSpacing.xs) {
                        if !currentValue.isEmpty {
                            DSText(currentValue, font: useSmallText ? .dsCaption : .dsSubtitle, color: isDisabled ? theme.colors.textSecondary : theme.colors.textPrimary)
                                .fontWeight(.medium)
                        }
                        Image(systemName: isDisabled ? "lock.fill" : "chevron.right")
                            .font(.dsSubtitle)
                            .fontWeight(.medium)
                            .foregroundColor(theme.colors.textSecondary)
                    }
                }
                .padding(.horizontal, DSSpacing.sm)
                .padding(.vertical, DSSpacing.sm)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1.0)
    }
}

struct EndBudgetSection: View {
    let action: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: action) {
            DSCard(padding: 8) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                        DSText("End Budget Early", font: .dsHeadline, color: Color.red)
                        DSText("Finish current budget and start a new one", font: .dsCaption, color: theme.colors.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "exclamationmark.triangle")
                        .font(.dsHeadline)
                        .foregroundColor(Color.red)
                }
                .padding(.horizontal, DSSpacing.sm)
                .padding(.vertical, DSSpacing.sm)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SignOutSection: View {
    let action: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: action) {
            DSCard(padding: 8) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                        DSText("Sign Out", font: .dsHeadline, color: theme.colors.textPrimary)
                        DSText("Sign out of your account", font: .dsCaption, color: theme.colors.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.dsHeadline)
                        .foregroundColor(theme.colors.textSecondary)
                }
                .padding(.horizontal, DSSpacing.sm)
                .padding(.vertical, DSSpacing.sm)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
