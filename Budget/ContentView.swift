//
//  ContentView.swift
//  Budget
//
//  Created by Prateek Sharma on 05/09/2025.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var systemColorScheme
    @State private var hasCompletedOnboarding = false
    @State private var budgetManager: BudgetManager?
    @State private var showingBudgetExpired = false
    @State private var showingBudgetSettings = false

    var body: some View {
        Group {
            if hasCompletedOnboarding, let manager = budgetManager {
                MainAppView(
                    budgetManager: manager,
                    showingBudgetSettings: $showingBudgetSettings
                )
                .overlay {
                    if showingBudgetExpired {
                        BudgetExpiredView(
                            budgetManager: manager,
                            onContinueWithSameSettings: {
                                if manager.createNextPeriodBudget() {
                                    showingBudgetExpired = false
                                    // Schedule notifications for the new budget
                                    if let budget = manager.currentBudget {
                                        NotificationService.shared.scheduleBudgetEndNotifications(for: budget)
                                    }
                                }
                            },
                            onChangeBudgetSettings: {
                                showingBudgetSettings = true
                                showingBudgetExpired = false
                            }
                        )
                        .transition(.opacity)
                    }
                }
            } else {
                OnboardingCoordinator(
                    onComplete: { completedBudget in
                        Task { @MainActor in
                            // Create budget manager with the completed budget
                            let manager = BudgetManager(modelContext: modelContext)
                            _ = manager.createBudget(completedBudget)
                            budgetManager = manager
                            hasCompletedOnboarding = true

                            // Schedule budget end notifications for the new budget
                            NotificationService.shared.scheduleBudgetEndNotifications(for: completedBudget)
                        }
                    },
                    onImport: { importedBudget, importedTransactions in
                        Task { @MainActor in
                            // Create budget manager with the imported budget
                            let manager = BudgetManager(modelContext: modelContext)

                            // Check if a budget with the same ID already exists
                            let existingBudgets = manager.getAllBudgets()
                            let budgetExists = existingBudgets.contains(where: { $0.id == importedBudget.id })

                            if budgetExists {
                                // Delete existing budget and its transactions
                                _ = manager.deleteBudget(importedBudget.id)
                            }

                            // Create the imported budget
                            guard manager.createBudget(importedBudget) else {
                                print("Failed to create imported budget")
                                return
                            }

                            // Add all imported transactions to the budget
                            for transaction in importedTransactions {
                                _ = manager.addTransaction(transaction, to: importedBudget.id)
                            }

                            budgetManager = manager
                            hasCompletedOnboarding = true

                            // Schedule budget end notifications for the imported budget
                            NotificationService.shared.scheduleBudgetEndNotifications(for: importedBudget)
                        }
                    }
                )
            }
        }
        .environment(\.appTheme, AppTheme.shared)
        .task {
            // Check if there are existing budgets to determine onboarding state
            await MainActor.run {
                let manager = BudgetManager(modelContext: modelContext)
                if manager.hasExistingBudgets() {
                    budgetManager = manager
                    hasCompletedOnboarding = true

                    // Check if current budget is expired
                    checkBudgetStatus(manager: manager)
                }
                // If no existing budgets, keep hasCompletedOnboarding = false to show onboarding
            }
        }
        .onAppear {
            // Re-check budget status whenever the view appears
            if let manager = budgetManager {
                checkBudgetStatus(manager: manager)
            }
            // Update theme based on system color scheme
            AppTheme.shared.updateColorScheme(systemScheme: systemColorScheme)
        }
        .onChange(of: systemColorScheme) { _, newScheme in
            // Update theme when system color scheme changes
            AppTheme.shared.updateColorScheme(systemScheme: newScheme)
        }
    }

    private func checkBudgetStatus(manager: BudgetManager) {
        let status = manager.checkBudgetStatus()

        switch status {
        case .expired:
            withAnimation(.easeInOut(duration: 0.3)) {
                showingBudgetExpired = true
            }
        case .endingSoon(let daysLeft):
            // For ending soon, we could show a banner or send notification
            // For now, let the notification system handle it
            if daysLeft == 0 {
                // If budget ends today, show a subtle reminder
                print("Budget ends today - user should see this via notification")
            }
        case .active, .noBudget:
            showingBudgetExpired = false
        }
    }
}


#Preview {
    ContentView()
        .modelContainer(for: [BudgetDataModel.self, TransactionDataModel.self])
}
