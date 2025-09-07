//
//  ContentView.swift
//  Budget
//
//  Created by Prateek Sharma on 05/09/2025.
//

import SwiftUI

struct ContentView: View {
    @State private var hasCompletedOnboarding = false
    @State private var userBudget: Budget?
    
    var body: some View {
        Group {
            if hasCompletedOnboarding, let budget = userBudget {
                MainAppView(budget: budget)
            } else {
                OnboardingCoordinator { completedBudget in
                    userBudget = completedBudget
                    hasCompletedOnboarding = true
                }
            }
        }
        .environment(\.appTheme, AppTheme.shared)
    }
}

struct MainAppView: View {
    let budget: Budget
    @Environment(\.appTheme) private var theme
    @State private var budgetManager: BudgetManager
    @State private var expandedCategories: Set<UUID> = []
    @State private var showingAddTransaction = false
    
    init(budget: Budget) {
        self.budget = budget
        self._budgetManager = State(initialValue: BudgetManager(budget: budget))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
            // Top section with budget name
            HStack {
                Spacer()
                DSText(budgetManager.budget.budgetName, font: .dsHeadline, color: theme.colors.primaryText)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 24)
            
            ScrollView {
                VStack(spacing: 24) {
                    // Budget Section
                    VStack(spacing: 16) {
                        // Section Header
                        HStack {
                            DSText("Budget", font: .dsTitle, color: theme.colors.primaryText)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        
                        // Budget Overview Card
                        BudgetOverviewCard(budgetManager: budgetManager)
                            .padding(.horizontal, 16)
                    }
                    
                    // Spends Section
                    VStack(spacing: 16) {
                        // Section Header
                        HStack {
                            DSText("Spends", font: .dsTitle, color: theme.colors.primaryText)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        
                        // Category Cards
                        LazyVStack(spacing: 16) {
                            ForEach(budgetManager.budget.categories) { category in
                                CategoryExpendableCard(
                                    category: category,
                                    budgetManager: budgetManager,
                                    isExpanded: expandedCategories.contains(category.id)
                                ) {
                                    toggleExpansion(for: category)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // Bottom spacing
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 40)
                }
            }
        }
        .background(theme.colors.background)
        .navigationDestination(isPresented: $showingAddTransaction) {
            AddTransactionSheet(
                categories: budgetManager.budget.categories,
                currency: budgetManager.budget.currency,
                budgetPeriod: budgetManager.budget.period
            ) { transaction in
                budgetManager.addTransaction(transaction)
                showingAddTransaction = false
            }
        }
        .overlay(
            // Floating Action Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    DSIconButton(type: .add) {
                        showingAddTransaction = true
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
                }
            }
        )
        }
    }
    
    private func toggleExpansion(for category: Category) {
        withAnimation(.easeInOut(duration: 0.3)) {
            if expandedCategories.contains(category.id) {
                expandedCategories.remove(category.id)
            } else {
                expandedCategories.insert(category.id)
            }
        }
    }
}

#Preview {
    ContentView()
}

#Preview("MainApp") {
    MainAppView(budget: Budget.createSample())
}
