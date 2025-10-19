import Foundation

// Mock BudgetManager for SwiftUI previews
@Observable
class MockBudgetManager: BudgetManagerProtocol {
    var currentBudget: Budget?
    var transactions: [Transaction] = []
    private var lastDeletedTransaction: Transaction?
    
    init(budget: Budget) {
        self.currentBudget = budget
        generateSampleTransactions()
    }
    
    // MARK: - Budget Analysis (Computed Properties)

    var budget: Budget {
        return currentBudget ?? Budget.createSample()
    }

    var totalSpent: Double {
        transactions.reduce(0) { $0 + $1.amount }
    }

    var totalRemains: Double {
        max(0, budget.totalAmount - totalSpent)
    }

    var spentPercentage: Double {
        guard budget.totalAmount > 0 else { return 0 }
        return min(1.0, totalSpent / budget.totalAmount)
    }

    // MARK: - Budget Analysis

    func totalBudgetAmount(excludingSavings: Bool) -> Double {
        return budget.totalAmount(excludingSavings: excludingSavings)
    }

    func totalSpent(excludingSavings: Bool) -> Double {
        if excludingSavings {
            let expenseCategoryIds = Set(budget.categories.filter { $0.categoryType == .expense }.map { $0.id })
            return transactions.filter { expenseCategoryIds.contains($0.categoryId) }.reduce(0) { $0 + $1.amount }
        }
        return totalSpent
    }

    func totalRemains(excludingSavings: Bool) -> Double {
        let spent = totalSpent(excludingSavings: excludingSavings)
        let budgetAmount = totalBudgetAmount(excludingSavings: excludingSavings)
        return max(0, budgetAmount - spent)
    }

    func spentPercentage(excludingSavings: Bool) -> Double {
        let budgetAmount = totalBudgetAmount(excludingSavings: excludingSavings)
        guard budgetAmount > 0 else { return 0 }
        let spent = totalSpent(excludingSavings: excludingSavings)
        return min(1.0, spent / budgetAmount)
    }

    // MARK: - Sub-Category Level Calculations

    func spentAmount(for subCategory: SubCategory) -> Double {
        transactions
            .filter { $0.categoryId == subCategory.id }
            .reduce(0) { $0 + $1.amount }
    }

    func remainingAmount(for subCategory: SubCategory) -> Double {
        let allocated = budget.categoryAmounts[subCategory.id.uuidString] ?? 0
        let spent = spentAmount(for: subCategory)
        return max(0, allocated - spent)
    }

    func spentPercentage(for subCategory: SubCategory) -> Double {
        let allocated = budget.categoryAmounts[subCategory.id.uuidString] ?? 0
        guard allocated > 0 else { return 0 }
        let spent = spentAmount(for: subCategory)
        return min(1.0, spent / allocated)
    }

    func recentTransactions(for subCategory: SubCategory, limit: Int = 5) -> [Transaction] {
        transactions
            .filter { $0.categoryId == subCategory.id }
            .sorted { $0.date > $1.date }
            .prefix(limit)
            .map { $0 }
    }

    func subCategories(for group: CategoryGroup) -> [SubCategory] {
        budget.categories.filter { $0.categoryGroup == group }
    }

    // MARK: - Category Group Level Calculations

    func spentAmount(for group: CategoryGroup, excludingSavings: Bool = false) -> Double {
        var subCategoriesInGroup = budget.categories.filter { $0.categoryGroup == group }
        if excludingSavings {
            subCategoriesInGroup = subCategoriesInGroup.filter { $0.categoryType == .expense }
        }
        return subCategoriesInGroup.reduce(0.0) { total, subCategory in
            total + spentAmount(for: subCategory)
        }
    }

    func allocatedAmount(for group: CategoryGroup, excludingSavings: Bool = false) -> Double {
        return budget.totalAmount(for: group, excludingSavings: excludingSavings)
    }

    func remainingAmount(for group: CategoryGroup, excludingSavings: Bool = false) -> Double {
        let allocated = allocatedAmount(for: group, excludingSavings: excludingSavings)
        let spent = spentAmount(for: group, excludingSavings: excludingSavings)
        return max(0, allocated - spent)
    }

    func spentPercentage(for group: CategoryGroup, excludingSavings: Bool = false) -> Double {
        let allocated = allocatedAmount(for: group, excludingSavings: excludingSavings)
        guard allocated > 0 else { return 0 }
        let spent = spentAmount(for: group, excludingSavings: excludingSavings)
        return min(1.0, spent / allocated)
    }

    func transactions(for subCategory: SubCategory) -> [Transaction] {
        transactions.filter { $0.categoryId == subCategory.id }
    }

    func transactions(for group: CategoryGroup) -> [Transaction] {
        let subCategoryIds = Set(subCategories(for: group).map { $0.id })
        return transactions.filter { subCategoryIds.contains($0.categoryId) }
    }

    func recentTransactions(for group: CategoryGroup, limit: Int = 5) -> [Transaction] {
        transactions(for: group)
            .sorted { $0.date > $1.date }
            .prefix(limit)
            .map { $0 }
    }
    
    func getAllTransactions() -> [Transaction] {
        return transactions
    }

    func getAllTransactionsAcrossAllBudgets() -> [Transaction] {
        // For mock, same as getAllTransactions since we only have one budget
        return transactions
    }

    // Mock methods (do nothing in preview)
    func addTransaction(_ transaction: Transaction) -> Bool {
        transactions.append(transaction)
        return true
    }
    
    func updateTransaction(_ transaction: Transaction) -> Bool {
        if let index = transactions.firstIndex(where: { $0.id == transaction.id }) {
            transactions[index] = transaction
        }
        return true
    }
    
    func deleteTransaction(_ transaction: Transaction) -> Bool {
        lastDeletedTransaction = transaction
        transactions.removeAll { $0.id == transaction.id }
        return true
    }

    func deleteAllTransactions(for subCategory: SubCategory) -> Bool {
        // For simplicity, only track single transaction undo for now
        lastDeletedTransaction = nil
        transactions.removeAll { $0.categoryId == subCategory.id }
        return true
    }

    // MARK: - Undo Operations

    func undoLastTransaction() -> Bool {
        guard let deletedTransaction = lastDeletedTransaction else { return false }
        transactions.append(deletedTransaction)
        lastDeletedTransaction = nil
        return true
    }

    func canUndo() -> Bool {
        return lastDeletedTransaction != nil
    }

    // MARK: - Budget Status Management (Mock Implementation)

    var isBudgetExpired: Bool {
        // For preview, simulate an expired budget
        return true
    }

    var daysUntilBudgetEnd: Int {
        return -2 // Simulate budget ended 2 days ago
    }

    func checkBudgetStatus() -> BudgetStatus {
        return .expired
    }

    func getNextBudgetPeriod() -> BudgetPeriod {
        return BudgetPeriod(startDate: Date())
    }

    func createNextPeriodBudget() -> Bool {
        return true
    }

    // MARK: - Budget Navigation (Mock Implementation)

    func getAllBudgetsSorted() -> [Budget] {
        return [budget]
    }

    func getCurrentBudgetIndex() -> Int? {
        return 0
    }

    func switchToPreviousBudget() -> Bool {
        return false // No previous budgets in mock
    }

    func switchToNextBudget() -> Bool {
        return false // No next budgets in mock
    }

    func canSwitchToPrevious() -> Bool {
        return false
    }

    func canSwitchToNext() -> Bool {
        return false
    }

    func isViewingMostRecentBudget() -> Bool {
        return true // Mock always views the most recent (only) budget
    }

    func switchToBudget(with id: UUID) -> Bool {
        return id == budget.id
    }
    
    private func generateSampleTransactions() {
        guard let firstCategory = budget.categories.first else { return }
        
        // Add some sample transactions for demo
        transactions = [
            Transaction(amount: 150.0, notes: "Grocery Store", date: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(), categoryId: firstCategory.id),
            Transaction(amount: 75.0, notes: "Gas Station", date: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date(), categoryId: firstCategory.id),
            Transaction(amount: 200.0, notes: "Restaurant", date: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date(), categoryId: firstCategory.id),
        ]
    }
}