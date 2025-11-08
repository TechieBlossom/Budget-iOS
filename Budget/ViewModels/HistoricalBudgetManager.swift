//
//  HistoricalBudgetManager.swift
//  Budget
//
//  Created for Historical Budget UI - Issue #7
//  Read-only adapter for displaying historical budget data
//

import Foundation

@MainActor
@Observable
class HistoricalBudgetManager: BudgetManagerProtocol {
    // MARK: - Properties
    let budget: Budget
    private let _transactions: [Transaction]

    // MARK: - Initialization
    init(budget: Budget, transactions: [Transaction]) {
        self.budget = budget
        self._transactions = transactions
    }

    // MARK: - Computed Properties

    var totalSpent: Double {
        _transactions.reduce(0) { $0 + $1.amount }
    }

    var totalRemains: Double {
        max(0, totalBudgetAmount(excludingSavings: false) - totalSpent)
    }

    var spentPercentage: Double {
        let total = totalBudgetAmount(excludingSavings: false)
        guard total > 0 else { return 0 }
        return totalSpent / total
    }

    // MARK: - Budget Analysis

    func totalBudgetAmount(excludingSavings: Bool) -> Double {
        let categories = excludingSavings
            ? budget.categories.filter { $0.categoryType != .savings }
            : budget.categories

        return categories.reduce(0) { sum, category in
            sum + (budget.categoryAmounts[category.id.uuidString] ?? 0)
        }
    }

    func totalSpent(excludingSavings: Bool) -> Double {
        if excludingSavings {
            let savingsCategories = budget.categories.filter { $0.categoryType == .savings }
            let savingsCategoryIds = Set(savingsCategories.map { $0.id })
            return _transactions
                .filter { !savingsCategoryIds.contains($0.categoryId) }
                .reduce(0) { $0 + $1.amount }
        } else {
            return totalSpent
        }
    }

    func totalRemains(excludingSavings: Bool) -> Double {
        max(0, totalBudgetAmount(excludingSavings: excludingSavings) - totalSpent(excludingSavings: excludingSavings))
    }

    func spentPercentage(excludingSavings: Bool) -> Double {
        let total = totalBudgetAmount(excludingSavings: excludingSavings)
        guard total > 0 else { return 0 }
        return totalSpent(excludingSavings: excludingSavings) / total
    }

    // MARK: - Sub-Category Methods

    func spentAmount(for subCategory: SubCategory) -> Double {
        transactions(for: subCategory).reduce(0) { $0 + $1.amount }
    }

    func remainingAmount(for subCategory: SubCategory) -> Double {
        let allocated = budget.categoryAmounts[subCategory.id.uuidString] ?? 0
        return max(0, allocated - spentAmount(for: subCategory))
    }

    func spentPercentage(for subCategory: SubCategory) -> Double {
        let allocated = budget.categoryAmounts[subCategory.id.uuidString] ?? 0
        guard allocated > 0 else { return 0 }
        return spentAmount(for: subCategory) / allocated
    }

    func recentTransactions(for subCategory: SubCategory, limit: Int) -> [Transaction] {
        Array(transactions(for: subCategory).prefix(limit))
    }

    func transactions(for subCategory: SubCategory) -> [Transaction] {
        _transactions.filter { $0.categoryId == subCategory.id }
            .sorted { $0.date > $1.date }
    }

    // MARK: - Category Group Methods

    func spentAmount(for group: CategoryGroup, excludingSavings: Bool) -> Double {
        transactions(for: group).reduce(0) { $0 + $1.amount }
    }

    func allocatedAmount(for group: CategoryGroup, excludingSavings: Bool) -> Double {
        subCategories(for: group).reduce(0) { sum, category in
            sum + (budget.categoryAmounts[category.id.uuidString] ?? 0)
        }
    }

    func remainingAmount(for group: CategoryGroup, excludingSavings: Bool) -> Double {
        max(0, allocatedAmount(for: group, excludingSavings: excludingSavings) - spentAmount(for: group, excludingSavings: excludingSavings))
    }

    func spentPercentage(for group: CategoryGroup, excludingSavings: Bool) -> Double {
        let allocated = allocatedAmount(for: group, excludingSavings: excludingSavings)
        guard allocated > 0 else { return 0 }
        return spentAmount(for: group, excludingSavings: excludingSavings) / allocated
    }

    func subCategories(for group: CategoryGroup) -> [SubCategory] {
        budget.categories.filter { $0.categoryGroup == group }
    }

    func transactions(for group: CategoryGroup) -> [Transaction] {
        let categoryIds = Set(subCategories(for: group).map { $0.id })
        return _transactions.filter { categoryIds.contains($0.categoryId) }
            .sorted { $0.date > $1.date }
    }

    func recentTransactions(for group: CategoryGroup, limit: Int) -> [Transaction] {
        Array(transactions(for: group).prefix(limit))
    }

    // MARK: - Transaction Retrieval

    func getAllTransactions() -> [Transaction] {
        _transactions
    }

    func getAllTransactionsAcrossAllBudgets() -> [Transaction] {
        // Historical budgets only return their own transactions
        _transactions
    }

    // MARK: - Read-Only Stubs (Not Supported for Historical Budgets)

    func addTransaction(_ transaction: Transaction) -> Bool {
        print("⚠️ Cannot add transactions to historical budget")
        return false
    }

    func updateTransaction(_ transaction: Transaction) -> Bool {
        print("⚠️ Cannot update transactions in historical budget")
        return false
    }

    func deleteTransaction(_ transaction: Transaction) -> Bool {
        print("⚠️ Cannot delete transactions from historical budget")
        return false
    }

    func deleteAllTransactions(for subCategory: SubCategory) -> Bool {
        print("⚠️ Cannot delete transactions from historical budget")
        return false
    }

    func undoLastTransaction() -> Bool {
        print("⚠️ Cannot undo transactions in historical budget")
        return false
    }

    func canUndo() -> Bool {
        false
    }

    // MARK: - Budget Navigation Stubs (Not Supported)

    func getAllBudgetsSorted() -> [Budget] {
        [budget]
    }

    func getCurrentBudgetIndex() -> Int? {
        0
    }

    func switchToPreviousBudget() -> Bool {
        false
    }

    func switchToNextBudget() -> Bool {
        false
    }

    func canSwitchToPrevious() -> Bool {
        false
    }

    func canSwitchToNext() -> Bool {
        false
    }

    func isViewingMostRecentBudget() -> Bool {
        false
    }

    func switchToBudget(with id: UUID) -> Bool {
        false
    }

    // MARK: - Budget Status (Historical budgets are always expired)

    var isBudgetExpired: Bool {
        true
    }

    var daysUntilBudgetEnd: Int {
        0
    }

    func checkBudgetStatus() -> BudgetStatus {
        .expired
    }

    func getNextBudgetPeriod() -> BudgetPeriod {
        budget.period
    }

    func createNextPeriodBudget() async -> Bool {
        print("⚠️ Cannot create next period from historical budget")
        return false
    }

    // MARK: - Budget Updates (Not Supported)

    func updateBudget(_ budget: Budget) -> Bool {
        print("⚠️ Cannot update historical budget")
        return false
    }

    func refreshFromSupabase() async {
        print("⚠️ Cannot refresh historical budget from Supabase")
    }
}
