//
//  HistoricalBudgetDetailView.swift
//  Budget
//
//  Created for Supabase integration - Phase 8
//

import SwiftUI
import Supabase

/// View model for managing historical budget details
@MainActor
@Observable
class HistoricalBudgetDetailViewModel {
    var categories: [SupabaseCategory] = []
    var transactions: [SupabaseTransaction] = []
    var isLoading = false
    var errorMessage: String?

    private let supabase = SupabaseClientManager.shared.client

    /// Fetch full budget details from Supabase
    func fetchBudgetDetails(budgetId: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            // Fetch categories
            let fetchedCategories: [SupabaseCategory] = try await supabase
                .from("categories")
                .select()
                .eq("budget_id", value: budgetId)
                .execute()
                .value

            categories = fetchedCategories

            // Fetch transactions for all categories
            if !fetchedCategories.isEmpty {
                let categoryIds = fetchedCategories.map { $0.id }
                let fetchedTransactions: [SupabaseTransaction] = try await supabase
                    .from("transactions")
                    .select()
                    .in("category_id", values: categoryIds)
                    .order("transaction_date", ascending: false)
                    .execute()
                    .value

                transactions = fetchedTransactions
            }

            isLoading = false

        } catch {
            errorMessage = "Failed to load budget details: \(error.localizedDescription)"
            isLoading = false
        }
    }

    /// Get transactions for a specific category
    func transactions(for categoryId: UUID) -> [SupabaseTransaction] {
        transactions.filter { $0.categoryId == categoryId }
    }

    /// Calculate spent amount for a category
    func spentAmount(for categoryId: UUID) -> Double {
        transactions(for: categoryId).reduce(0) { $0 + $1.amount }
    }

    /// Calculate total budget amount
    var totalBudgetAmount: Double {
        categories.reduce(0) { $0 + $1.allocatedAmount }
    }

    /// Calculate total spent
    var totalSpent: Double {
        transactions.reduce(0) { $0 + $1.amount }
    }

    /// Calculate remaining amount
    var totalRemaining: Double {
        max(0, totalBudgetAmount - totalSpent)
    }

    /// Calculate spent percentage
    var spentPercentage: Double {
        guard totalBudgetAmount > 0 else { return 0 }
        return totalSpent / totalBudgetAmount
    }

    /// Create a BudgetManager adapter for historical budget viewing
    func createBudgetManager(for budget: SupabaseBudget) -> HistoricalBudgetManager {
        let domainBudget = budget.toBudget(categories: categories)
        let domainTransactions = transactions.map { $0.toTransaction() }
        return HistoricalBudgetManager(budget: domainBudget, transactions: domainTransactions)
    }
}

/// Read-only detail view for a historical budget
struct HistoricalBudgetDetailView: View {
    let budget: SupabaseBudget

    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = HistoricalBudgetDetailViewModel()
    @State private var expandedGroups: Set<CategoryGroup> = []
    @State private var showAllTransactions = false

    private var budgetPeriod: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: budget.startDate)) - \(formatter.string(from: budget.endDate))"
    }

    // Computed property to get the budget manager once data is loaded
    private var budgetManager: HistoricalBudgetManager? {
        guard !viewModel.categories.isEmpty else { return nil }
        return viewModel.createBudgetManager(for: budget)
    }

    // Get sorted category groups based on spending
    private var sortedCategoryGroups: [CategoryGroup] {
        guard let manager = budgetManager else { return [] }

        let groups = Set(manager.budget.categories.map { $0.categoryGroup })
        return groups.sorted { group1, group2 in
            let spent1 = manager.spentAmount(for: group1, excludingSavings: false)
            let spent2 = manager.spentAmount(for: group2, excludingSavings: false)
            return spent1 > spent2
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                // Loading state
                VStack(spacing: DSSpacing.md) {
                    ProgressView()
                        .tint(theme.colors.primary)
                    DSText("Loading budget details...", font: .dsBody, color: theme.colors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if let errorMessage = viewModel.errorMessage {
                // Error state
                VStack(spacing: DSSpacing.md) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.dsLargeTitle)
                        .foregroundColor(theme.colors.textSecondary.opacity(0.6))

                    DSText("Error Loading Budget", font: .dsHeadline, color: theme.colors.textPrimary)
                        .fontWeight(.medium)

                    DSText(errorMessage, font: .dsBody, color: theme.colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DSSpacing.xl)

                    DSButton("Try Again", style: .primary) {
                        Task {
                            await viewModel.fetchBudgetDetails(budgetId: budget.id)
                        }
                    }
                    .padding(.top, DSSpacing.md)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if let manager = budgetManager {
                // Budget details with Budget Tab layout
                ScrollView {
                    VStack(spacing: DSSpacing.xl) {

                        // Budget Overview Section (matching Budget Tab)
                        VStack(spacing: DSSpacing.md) {
                            // Section Header
                            HStack {
                                DSText("Budget Overview", font: .dsSmallTitle, color: theme.colors.textPrimary)
                                Spacer()
                            }
                            .padding(.horizontal, DSSpacing.md)

                            // Budget Overview Hero Card
                            OverviewHeroCard(
                                budgetManager: manager,
                                excludeSavings: false,
                                selectedGroups: Set(CategoryGroup.allCases)
                            )
                            .padding(.horizontal, DSSpacing.md)
                        }

                        // Chart Section - Category Groups (matching Budget Tab)
                        VStack(alignment: .leading, spacing: DSSpacing.md) {
                            // Heading
                            HStack {
                                DSText("Completion by Category", font: .dsSmallTitle, color: theme.colors.textPrimary)
                                Spacer()
                            }
                            .padding(.horizontal, DSSpacing.md)

                            // Single Chart - Group-based spending
                            CategoryGroupBarChart(
                                budgetManager: manager,
                                excludeSavings: false,
                                selectedGroups: Set(CategoryGroup.allCases)
                            )
                        }

                        // All Transactions Link (matching Budget Tab)
                        if !viewModel.transactions.isEmpty {
                            DSButton(
                                "View All Transactions",
                                fullWidth: true
                            ) {
                                showAllTransactions = true
                            }
                            .padding(.horizontal, DSSpacing.md)
                        }

                        // Spends Section (matching Budget Tab)
                        if !sortedCategoryGroups.isEmpty {
                            VStack(spacing: DSSpacing.md) {
                                // Section Header
                                HStack {
                                    DSText("Spends", font: .dsSmallTitle, color: theme.colors.textPrimary)
                                    Spacer()
                                }
                                .padding(.horizontal, DSSpacing.md)

                                // Category Group Cards
                                LazyVStack(spacing: DSSpacing.md) {
                                    ForEach(sortedCategoryGroups, id: \.self) { group in
                                        CategoryGroupExpendableCard(
                                            group: group,
                                            budgetManager: manager,
                                            isExpanded: expandedGroups.contains(group),
                                            onToggle: {
                                                toggleExpansion(for: group)
                                            },
                                            onSubCategoryTap: { _ in
                                                // Read-only: do nothing on tap
                                            },
                                            onAddCategory: { _ in
                                                // Read-only: do nothing
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal, DSSpacing.md)
                            }
                        }

                        // Bottom spacing
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 24)
                    }
                    .padding(.top, DSSpacing.md)
                }
            }
        }
        .background(theme.colors.background)
        .navigationTitle(budget.budgetName)
        .navigationBarTitleDisplayMode(.inline)
        .customNavigationBarAppearance()
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    DSText(budget.budgetName, font: .dsBody, color: theme.colors.textPrimary)
                        .fontWeight(.semibold)
                    DSText(budgetPeriod, font: .dsCaption, color: theme.colors.textSecondary)
                }
            }
        }
        .task {
            await viewModel.fetchBudgetDetails(budgetId: budget.id)
        }
        .navigationDestination(isPresented: $showAllTransactions) {
            if let manager = budgetManager {
                AllTransactionsView(
                    budgetManager: manager,
                    isReadOnly: true
                )
            }
        }
    }

    // MARK: - Helper Methods

    private func toggleExpansion(for group: CategoryGroup) {
        withAnimation(.easeOut(duration: 0.3)) {
            if expandedGroups.contains(group) {
                expandedGroups.remove(group)
            } else {
                expandedGroups.insert(group)
            }
        }
    }
}

#Preview {
    NavigationStack {
        HistoricalBudgetDetailView(budget: SupabaseBudget(
            id: UUID(),
            userId: UUID(),
            startDate: Date().addingTimeInterval(-60*60*24*30),
            endDate: Date().addingTimeInterval(-60*60*24),
            budgetType: "monthly",
            budgetName: "January 2025",
            currencyCode: "USD",
            currencyName: "US Dollar",
            currencySymbol: "$",
            isActive: false,
            createdAt: Date(),
            updatedAt: Date()
        ))
        .environment(\.appTheme, AppTheme.shared)
    }
}
