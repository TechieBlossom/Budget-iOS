//
//  MainAppView.swift
//  Budget
//
//  Created by Prateek Sharma on 05/09/2025.
//

import SwiftUI

struct MainAppView: View {
    let budgetManager: BudgetManager
    @Environment(\.appTheme) private var theme
    @State private var expandedCategories: Set<UUID> = []
    @State private var showingAddTransaction = false
    @State private var showingBudgetAnalysis = false
    
    init(budgetManager: BudgetManager) {
        self.budgetManager = budgetManager
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
            // Top section with budget name and dates
            HStack {
                Spacer()
                VStack(alignment: .center, spacing: 2) {
                    DSText(budgetManager.budget.budgetName, font: .dsHeadline, color: theme.colors.primaryText)
                    DSText(budgetManager.budget.period.formattedDateRange, font: .dsCaption, color: theme.colors.secondaryText)
                }
                Spacer()
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
                            DSText("Budget", font: .dsSmallTitle, color: theme.colors.primaryText)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        
                        // Budget Overview Card
                        Button(action: {
                            showingBudgetAnalysis = true
                        }) {
                            BudgetOverviewCard(budgetManager: budgetManager)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, 16)
                    }
                    
                    // Spends Section
                    VStack(spacing: 16) {
                        // Section Header
                        HStack {
                            DSText("Spends", font: .dsSmallTitle, color: theme.colors.primaryText)
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
                budgetPeriod: budgetManager.budget.period,
                budgetName: budgetManager.budget.budgetName
            ) { transaction in
                _ = budgetManager.addTransaction(transaction)
                showingAddTransaction = false
            }
        }
        .navigationDestination(isPresented: $showingBudgetAnalysis) {
            BudgetAnalysisView(budgetManager: budgetManager)
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
