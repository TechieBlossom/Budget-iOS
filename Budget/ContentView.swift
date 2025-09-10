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
    @State private var hasCompletedOnboarding = false
    @State private var budgetManager: BudgetManager?
    
    var body: some View {
        Group {
            if hasCompletedOnboarding, let manager = budgetManager {
                MainAppView(budgetManager: manager)
            } else {
                OnboardingCoordinator { completedBudget in
                    Task { @MainActor in
                        // Create budget manager with the completed budget
                        let manager = BudgetManager(modelContext: modelContext)
                        _ = manager.createBudget(completedBudget)
                        budgetManager = manager
                        hasCompletedOnboarding = true
                    }
                }
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
                }
                // If no existing budgets, keep hasCompletedOnboarding = false to show onboarding
            }
        }
    }
}


#Preview {
    ContentView()
        .modelContainer(for: [BudgetDataModel.self, TransactionDataModel.self])
}
