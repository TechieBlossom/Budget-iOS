import Foundation

@MainActor
protocol BudgetManagerProtocol {
    var budget: Budget { get }
    var totalSpent: Double { get }
    var totalRemains: Double { get }
    var spentPercentage: Double { get }

    // Budget analysis with category type filtering
    func totalBudgetAmount(excludingSavings: Bool) -> Double
    func totalSpent(excludingSavings: Bool) -> Double
    func totalRemains(excludingSavings: Bool) -> Double
    func spentPercentage(excludingSavings: Bool) -> Double

    // Sub-Category Level Methods
    func spentAmount(for subCategory: SubCategory) -> Double
    func remainingAmount(for subCategory: SubCategory) -> Double
    func spentPercentage(for subCategory: SubCategory) -> Double
    func recentTransactions(for subCategory: SubCategory, limit: Int) -> [Transaction]

    // Category Group Level Methods
    func spentAmount(for group: CategoryGroup, excludingSavings: Bool) -> Double
    func allocatedAmount(for group: CategoryGroup, excludingSavings: Bool) -> Double
    func remainingAmount(for group: CategoryGroup, excludingSavings: Bool) -> Double
    func spentPercentage(for group: CategoryGroup, excludingSavings: Bool) -> Double
    func subCategories(for group: CategoryGroup) -> [SubCategory]
    func transactions(for subCategory: SubCategory) -> [Transaction]
    func transactions(for group: CategoryGroup) -> [Transaction]
    func recentTransactions(for group: CategoryGroup, limit: Int) -> [Transaction]

    func getAllTransactions() -> [Transaction]
    func getAllTransactionsAcrossAllBudgets() -> [Transaction]
    func addTransaction(_ transaction: Transaction) -> Bool
    func updateTransaction(_ transaction: Transaction) -> Bool
    func deleteTransaction(_ transaction: Transaction) -> Bool
    func deleteAllTransactions(for subCategory: SubCategory) -> Bool

    // Undo operations
    func undoLastTransaction() -> Bool
    func canUndo() -> Bool

    // Budget navigation
    func getAllBudgetsSorted() -> [Budget]
    func getCurrentBudgetIndex() -> Int?
    func switchToPreviousBudget() -> Bool
    func switchToNextBudget() -> Bool
    func canSwitchToPrevious() -> Bool
    func canSwitchToNext() -> Bool
    func isViewingMostRecentBudget() -> Bool
    func switchToBudget(with id: UUID) -> Bool

    // Budget status management
    var isBudgetExpired: Bool { get }
    var daysUntilBudgetEnd: Int { get }
    func checkBudgetStatus() -> BudgetStatus
    func getNextBudgetPeriod() -> BudgetPeriod
    func createNextPeriodBudget() async -> Bool

    // Budget updates and sync
    func updateBudget(_ budget: Budget) -> Bool
    func refreshFromSupabase() async
}

// MARK: - Default Parameter Extensions
extension BudgetManagerProtocol {
    func spentAmount(for group: CategoryGroup) -> Double {
        spentAmount(for: group, excludingSavings: false)
    }

    func allocatedAmount(for group: CategoryGroup) -> Double {
        allocatedAmount(for: group, excludingSavings: false)
    }

    func remainingAmount(for group: CategoryGroup) -> Double {
        remainingAmount(for: group, excludingSavings: false)
    }

    func spentPercentage(for group: CategoryGroup) -> Double {
        spentPercentage(for: group, excludingSavings: false)
    }
}