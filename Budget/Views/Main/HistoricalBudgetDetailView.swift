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
        return min(1.0, totalSpent / totalBudgetAmount)
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
    @State private var expandedCategories: Set<UUID> = []
    @State private var showAllTransactions = false

    private var budgetPeriod: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: budget.startDate)) - \(formatter.string(from: budget.endDate))"
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

            } else {
                // Budget details
                ScrollView {
                    VStack(spacing: DSSpacing.xl) {
                        // Info banner
                        DSCard {
                            HStack(spacing: DSSpacing.sm) {
                                Image(systemName: "info.circle.fill")
                                    .font(.dsTitle)
                                    .foregroundColor(theme.colors.primary)

                                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                                    DSText("Historical Budget", font: .dsBody, color: theme.colors.textPrimary)
                                        .fontWeight(.medium)
                                    DSText("This budget is read-only and cannot be edited", font: .dsCaption, color: theme.colors.textSecondary)
                                }

                                Spacer()
                            }
                            .padding(.horizontal, DSSpacing.sm)
                            .padding(.vertical, DSSpacing.sm)
                        }
                        .padding(.horizontal, DSSpacing.md)

                        // Budget summary
                        budgetSummarySection

                        // Categories section
                        if !viewModel.categories.isEmpty {
                            categoriesSection
                        }

                        // View All Transactions section
                        if !viewModel.transactions.isEmpty {
                            viewAllTransactionsSection
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
            if !viewModel.categories.isEmpty && !viewModel.transactions.isEmpty {
                AllTransactionsView(
                    budgetManager: viewModel.createBudgetManager(for: budget),
                    isReadOnly: true
                )
            }
        }
    }

    // MARK: - Budget Summary Section

    private var budgetSummarySection: some View {
        VStack(spacing: DSSpacing.md) {
            // Section header
            HStack {
                DSText("Summary", font: .dsSmallTitle, color: theme.colors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, DSSpacing.md)

            // Summary card
            DSCard {
                VStack(spacing: DSSpacing.lg) {
                    // Total budget
                    HStack {
                        DSText("Total Budget", font: .dsBody, color: theme.colors.textSecondary)
                        Spacer()
                        DSText(formatCurrency(viewModel.totalBudgetAmount), font: .dsTitle, color: theme.colors.textPrimary)
                            .fontWeight(.bold)
                    }

                    // Progress bar
                    VStack(alignment: .leading, spacing: DSSpacing.xs) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(theme.colors.surfaceVariant)
                                    .frame(height: 12)

                                // Progress
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(progressColor)
                                    .frame(width: geometry.size.width * viewModel.spentPercentage, height: 12)
                            }
                        }
                        .frame(height: 12)

                        // Percentage label
                        DSText("\(Int(viewModel.spentPercentage * 100))% spent", font: .dsCaption, color: theme.colors.textSecondary)
                    }

                    // Spent and remaining
                    HStack(spacing: DSSpacing.xl) {
                        VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                            DSText("Spent", font: .dsCaption, color: theme.colors.textSecondary)
                            DSText(formatCurrency(viewModel.totalSpent), font: .dsHeadline, color: theme.colors.textPrimary)
                                .fontWeight(.semibold)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: DSSpacing.xxs) {
                            DSText("Remaining", font: .dsCaption, color: theme.colors.textSecondary)
                            DSText(formatCurrency(viewModel.totalRemaining), font: .dsHeadline, color: theme.colors.primary)
                                .fontWeight(.semibold)
                        }
                    }

                    // Transaction count
                    Divider()
                        .padding(.vertical, DSSpacing.xxs)

                    HStack {
                        DSText("Total Transactions", font: .dsBody, color: theme.colors.textSecondary)
                        Spacer()
                        DSText("\(viewModel.transactions.count)", font: .dsBody, color: theme.colors.textPrimary)
                            .fontWeight(.medium)
                    }
                }
                .padding(.horizontal, DSSpacing.md)
                .padding(.vertical, DSSpacing.md)
            }
            .padding(.horizontal, DSSpacing.md)
        }
    }

    // MARK: - View All Transactions Section

    private var viewAllTransactionsSection: some View {
        VStack(spacing: DSSpacing.md) {
            DSCard {
                Button(action: {
                    showAllTransactions = true
                }) {
                    HStack(spacing: DSSpacing.md) {
                        // Icon
                        Image(systemName: "list.bullet.rectangle")
                            .font(.dsTitle)
                            .foregroundColor(theme.colors.primary)
                            .frame(width: 40, height: 40)
                            .background(theme.colors.primary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        // Info
                        VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                            DSText("View All Transactions", font: .dsHeadline, color: theme.colors.textPrimary)
                                .fontWeight(.medium)

                            DSText("See all \(viewModel.transactions.count) transactions with search and filters", font: .dsCaption, color: theme.colors.textSecondary)
                        }

                        Spacer()

                        // Chevron
                        Image(systemName: "chevron.right")
                            .font(.dsSubtitle)
                            .foregroundColor(theme.colors.textSecondary)
                    }
                    .padding(.horizontal, DSSpacing.sm)
                    .padding(.vertical, DSSpacing.sm)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, DSSpacing.md)
        }
    }

    // MARK: - Categories Section

    private var categoriesSection: some View {
        VStack(spacing: DSSpacing.md) {
            // Section header
            HStack {
                DSText("Categories (\(viewModel.categories.count))", font: .dsSmallTitle, color: theme.colors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, DSSpacing.md)

            // Categories list
            LazyVStack(spacing: DSSpacing.md) {
                ForEach(viewModel.categories, id: \.id) { category in
                    CategoryDetailCard(
                        category: category,
                        transactions: viewModel.transactions(for: category.id),
                        spentAmount: viewModel.spentAmount(for: category.id),
                        isExpanded: expandedCategories.contains(category.id),
                        onToggle: {
                            toggleExpansion(for: category.id)
                        }
                    )
                }
            }
            .padding(.horizontal, DSSpacing.md)
        }
    }

    // MARK: - Helper Methods

    private var progressColor: Color {
        let percentage = viewModel.spentPercentage
        if percentage >= 1.0 {
            return .red
        } else if percentage >= 0.8 {
            return .orange
        } else {
            return theme.colors.primary
        }
    }

    private func formatCurrency(_ amount: Double) -> String {
        return "\(budget.currencySymbol)\(String(format: "%.2f", amount))"
    }

    private func toggleExpansion(for categoryId: UUID) {
        withAnimation(.easeOut(duration: 0.3)) {
            if expandedCategories.contains(categoryId) {
                expandedCategories.remove(categoryId)
            } else {
                expandedCategories.insert(categoryId)
            }
        }
    }
}

// MARK: - Category Detail Card

struct CategoryDetailCard: View {
    let category: SupabaseCategory
    let transactions: [SupabaseTransaction]
    let spentAmount: Double
    let isExpanded: Bool
    let onToggle: () -> Void

    @Environment(\.appTheme) private var theme

    private var spentPercentage: Double {
        guard category.allocatedAmount > 0 else { return 0 }
        return min(1.0, spentAmount / category.allocatedAmount)
    }

    private var remainingAmount: Double {
        max(0, category.allocatedAmount - spentAmount)
    }

    private var progressColor: Color {
        if spentPercentage >= 1.0 {
            return .red
        } else if spentPercentage >= 0.8 {
            return .orange
        } else {
            return theme.colors.primary
        }
    }

    var body: some View {
        DSCard(padding: 8) {
            VStack(spacing: DSSpacing.md) {
                // Header - Always visible
                Button(action: onToggle) {
                    HStack(spacing: DSSpacing.sm) {
                        VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                            DSText(category.name, font: .dsHeadline, color: theme.colors.textPrimary)
                                .fontWeight(.medium)

                            HStack(spacing: DSSpacing.xs) {
                                DSText("Budget:", font: .dsCaption, color: theme.colors.textSecondary)
                                DSText(String(format: "%.2f", category.allocatedAmount), font: .dsCaption, color: theme.colors.textPrimary)
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: DSSpacing.xxs) {
                            DSText(String(format: "%.2f", spentAmount), font: .dsHeadline, color: theme.colors.textPrimary)
                                .fontWeight(.semibold)
                            DSText("\(transactions.count) transactions", font: .dsCaption, color: theme.colors.textSecondary)
                        }

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.dsSubtitle)
                            .foregroundColor(theme.colors.textSecondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(theme.colors.surfaceVariant)
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(progressColor)
                            .frame(width: geometry.size.width * spentPercentage, height: 8)
                    }
                }
                .frame(height: 8)

                // Expanded content - Transactions
                if isExpanded && !transactions.isEmpty {
                    Divider()
                        .padding(.vertical, DSSpacing.xxs)

                    VStack(spacing: DSSpacing.sm) {
                        ForEach(transactions, id: \.id) { transaction in
                            TransactionHistoryRow(transaction: transaction)
                        }
                    }
                }

                // Empty state when expanded but no transactions
                if isExpanded && transactions.isEmpty {
                    Divider()
                        .padding(.vertical, DSSpacing.xxs)

                    DSText("No transactions", font: .dsCaption, color: theme.colors.textSecondary)
                        .padding(.vertical, DSSpacing.sm)
                }
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.sm)
        }
    }
}

// MARK: - Transaction History Row

struct TransactionHistoryRow: View {
    let transaction: SupabaseTransaction

    @Environment(\.appTheme) private var theme

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: transaction.transactionDate)
    }

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                if !transaction.notes.isEmpty {
                    DSText(transaction.notes, font: .dsBody, color: theme.colors.textPrimary)
                } else {
                    DSText("Transaction", font: .dsBody, color: theme.colors.textSecondary)
                        .italic()
                }

                DSText(formattedDate, font: .dsCaption, color: theme.colors.textSecondary)

                if transaction.isRecurring {
                    HStack(spacing: DSSpacing.xxs) {
                        Image(systemName: "repeat")
                            .font(.system(size: 10))
                        DSText(transaction.recurrenceType.capitalized, font: .dsCaption, color: theme.colors.primary)
                    }
                }
            }

            Spacer()

            DSText(String(format: "%.2f", transaction.amount), font: .dsBody, color: theme.colors.textPrimary)
                .fontWeight(.medium)
        }
        .padding(.vertical, DSSpacing.xxs)
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
