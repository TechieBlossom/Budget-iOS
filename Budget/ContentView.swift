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
    @State private var authManager = AuthManager()
    @State private var hasCompletedOnboarding = false
    @State private var budgetManager: BudgetManager?
    @State private var showingBudgetExpired = false
    @State private var showingBudgetSettings = false

    var body: some View {
        Group {
            // Check authentication first
            if !authManager.isAuthenticated {
                AuthView()
                    .environment(authManager)
            } else if hasCompletedOnboarding, let manager = budgetManager {
                MainAppView(
                    budgetManager: manager,
                    showingBudgetSettings: $showingBudgetSettings
                )
                .environment(authManager)
                .overlay {
                    if showingBudgetExpired {
                        BudgetExpiredView(
                            budgetManager: manager,
                            onContinueWithSameSettings: {
                                Task { @MainActor in
                                    if await manager.createNextPeriodBudget() {
                                        showingBudgetExpired = false
                                        // Schedule notifications for the new budget
                                        if let budget = manager.currentBudget {
                                            NotificationService.shared.scheduleBudgetEndNotifications(for: budget)
                                        }
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
                            let manager = BudgetManager(modelContext: modelContext, authManager: authManager)
                            _ = manager.createBudget(completedBudget)
                            budgetManager = manager
                            hasCompletedOnboarding = true

                            // Schedule budget end notifications for the new budget
                            NotificationService.shared.scheduleBudgetEndNotifications(for: completedBudget)
                        }
                    }
                )
            }
        }
        .environment(\.appTheme, AppTheme.shared)
        .task {
            // Check if there are existing budgets to determine onboarding state
            // Only run this if user is authenticated
            if authManager.isAuthenticated {
                await MainActor.run {
                    let manager = BudgetManager(modelContext: modelContext, authManager: authManager)
                    if manager.hasExistingBudgets() {
                        budgetManager = manager
                        hasCompletedOnboarding = true

                        // Check if current budget is expired
                        checkBudgetStatus(manager: manager)
                    }
                    // If no existing budgets, keep hasCompletedOnboarding = false to show onboarding
                }
            }
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            // When user signs in, initialize budget manager and let sync state handle UI updates
            if isAuthenticated {
                Task { @MainActor in
                    // Create manager - this will start sync in background
                    let manager = BudgetManager(modelContext: modelContext, authManager: authManager)
                    budgetManager = manager

                    // Check immediately for local budgets
                    if manager.hasExistingBudgets() {
                        hasCompletedOnboarding = true
                        checkBudgetStatus(manager: manager)
                    }
                    // If no local budgets, the onChange(syncState) will handle it after sync
                }
            } else {
                // When user signs out, reset state
                budgetManager = nil
                hasCompletedOnboarding = false
            }
        }
        .onChange(of: budgetManager?.syncState) { _, newState in
            // When sync completes successfully, check for budgets again
            guard let manager = budgetManager else { return }

            switch newState {
            case .success:
                // Sync completed - check if we now have budgets
                if !hasCompletedOnboarding && manager.hasExistingBudgets() {
                    hasCompletedOnboarding = true
                    checkBudgetStatus(manager: manager)
                }
            default:
                break
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
