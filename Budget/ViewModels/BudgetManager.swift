import Foundation
import SwiftData

@MainActor
@Observable
class BudgetManager: BudgetManagerProtocol {
    private let databaseService: DatabaseServiceProtocol
    var currentBudget: Budget?
    var transactions: [Transaction] = []
    private var lastDeletedTransaction: Transaction?
    
    init(modelContext: ModelContext) {
        self.databaseService = DatabaseService(modelContext: modelContext)
        loadCurrentBudget()
    }
    
    // MARK: - Budget Operations
    
    func createBudget(_ budget: Budget) -> Bool {
        let success = databaseService.createBudget(budget)
        if success {
            currentBudget = budget
            loadTransactions()
        }
        return success
    }
    
    func loadCurrentBudget() {
        let budgets = databaseService.fetchBudgets()
        // Load the most recent budget (don't auto-create sample for fresh installs)
        currentBudget = budgets.sorted { $0.period.startDate > $1.period.startDate }.first

        if currentBudget != nil {
            loadTransactions()
        }
    }
    
    func hasExistingBudgets() -> Bool {
        return !databaseService.fetchBudgets().isEmpty
    }
    
    func updateBudget(_ budget: Budget) -> Bool {
        let success = databaseService.updateBudget(budget)
        if success {
            currentBudget = budget
        }
        return success
    }
    
    func deleteBudget(_ budgetId: UUID) -> Bool {
        let success = databaseService.deleteBudget(by: budgetId)
        if success && currentBudget?.id == budgetId {
            currentBudget = nil
            transactions = []
        }
        return success
    }
    
    func getAllBudgets() -> [Budget] {
        return databaseService.fetchBudgets()
    }
    
    // MARK: - Transaction Operations
    
    private func loadTransactions() {
        guard let budgetId = currentBudget?.id else {
            transactions = []
            return
        }
        transactions = databaseService.fetchTransactions(for: budgetId)
    }
    
    func addTransaction(_ transaction: Transaction, to budgetId: UUID? = nil) -> Bool {
        let targetBudgetId: UUID
        
        if let budgetId = budgetId {
            targetBudgetId = budgetId
        } else if let currentBudgetId = currentBudget?.id {
            targetBudgetId = currentBudgetId
        } else {
            // Try to find appropriate budget for transaction date
            guard let appropriateBudget = databaseService.findBudget(for: transaction.date) else {
                return false
            }
            targetBudgetId = appropriateBudget.id
        }
        
        let success = databaseService.createTransaction(transaction, budgetId: targetBudgetId)
        if success {
            if targetBudgetId == currentBudget?.id {
                transactions.append(transaction)
            }
        }
        return success
    }
    
    func addTransaction(_ transaction: Transaction) -> Bool {
        return addTransaction(transaction, to: nil)
    }
    
    func updateTransaction(_ transaction: Transaction) -> Bool {
        let success = databaseService.updateTransaction(transaction)
        if success {
            if let index = transactions.firstIndex(where: { $0.id == transaction.id }) {
                transactions[index] = transaction
            }
        }
        return success
    }
    
    func deleteTransaction(_ transaction: Transaction) -> Bool {
        let success = databaseService.deleteTransaction(by: transaction.id)
        if success {
            lastDeletedTransaction = transaction
            transactions.removeAll { $0.id == transaction.id }
        }
        return success
    }

    func deleteAllTransactions(for subCategory: SubCategory) -> Bool {
        // For simplicity, only track single transaction undo for now
        lastDeletedTransaction = nil
        let categoryTransactions = getAllTransactions().filter { $0.categoryId == subCategory.id }
        var allSuccess = true

        for transaction in categoryTransactions {
            let success = databaseService.deleteTransaction(by: transaction.id)
            if success {
                transactions.removeAll { $0.id == transaction.id }
            } else {
                allSuccess = false
            }
        }

        return allSuccess
    }

    // MARK: - Undo Operations

    func undoLastTransaction() -> Bool {
        guard let deletedTransaction = lastDeletedTransaction,
              let currentBudgetId = currentBudget?.id else { return false }

        let success = databaseService.createTransaction(deletedTransaction, budgetId: currentBudgetId)
        if success {
            transactions.append(deletedTransaction)
            lastDeletedTransaction = nil
        }
        return success
    }

    func canUndo() -> Bool {
        return lastDeletedTransaction != nil
    }
    
    func getTransactions(for budgetId: UUID) -> [Transaction] {
        return databaseService.fetchTransactions(for: budgetId)
    }
    
    func getAllTransactions() -> [Transaction] {
        // Return transactions for the current budget only
        return transactions
    }

    func getAllTransactionsAcrossAllBudgets() -> [Transaction] {
        // Return all transactions across all budgets (used for trends, insights, export)
        return databaseService.fetchAllTransactions()
    }
    
    // MARK: - Budget Analysis (Computed Properties)

    var budget: Budget {
        return currentBudget ?? Budget.createSample()
    }

    var totalSpent: Double {
        transactions.reduce(0) { $0 + $1.amount }
    }

    var totalSpentExpenses: Double {
        let expenseCategoryIds = Set(budget.categories.filter { $0.categoryType == .expense }.map { $0.id })
        return transactions.filter { expenseCategoryIds.contains($0.categoryId) }.reduce(0) { $0 + $1.amount }
    }

    var totalSpentSavings: Double {
        let savingsCategoryIds = Set(budget.categories.filter { $0.categoryType == .savings }.map { $0.id })
        return transactions.filter { savingsCategoryIds.contains($0.categoryId) }.reduce(0) { $0 + $1.amount }
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
            return totalSpentExpenses
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
    
    // MARK: - Budget Navigation

    func getAllBudgetsSorted() -> [Budget] {
        return databaseService.fetchBudgets().sorted { $0.period.startDate > $1.period.startDate }
    }

    func getCurrentBudgetIndex() -> Int? {
        guard let currentBudget = currentBudget else { return nil }
        let allBudgets = getAllBudgetsSorted()
        return allBudgets.firstIndex { $0.id == currentBudget.id }
    }

    func switchToPreviousBudget() -> Bool {
        guard let currentIndex = getCurrentBudgetIndex() else { return false }
        let allBudgets = getAllBudgetsSorted()

        let previousIndex = currentIndex + 1 // Since sorted descending, next index is "previous" chronologically
        guard previousIndex < allBudgets.count else { return false }

        currentBudget = allBudgets[previousIndex]
        loadTransactions()
        return true
    }

    func switchToNextBudget() -> Bool {
        guard let currentIndex = getCurrentBudgetIndex() else { return false }
        let allBudgets = getAllBudgetsSorted()

        let nextIndex = currentIndex - 1 // Since sorted descending, previous index is "next" chronologically
        guard nextIndex >= 0 else { return false }

        currentBudget = allBudgets[nextIndex]
        loadTransactions()
        return true
    }

    func canSwitchToPrevious() -> Bool {
        guard let currentIndex = getCurrentBudgetIndex() else { return false }
        let allBudgets = getAllBudgetsSorted()
        return currentIndex + 1 < allBudgets.count
    }

    func canSwitchToNext() -> Bool {
        guard let currentIndex = getCurrentBudgetIndex() else { return false }
        return currentIndex > 0
    }

    func isViewingMostRecentBudget() -> Bool {
        guard let currentIndex = getCurrentBudgetIndex() else { return false }
        return currentIndex == 0 // Index 0 is the most recent budget
    }

    func switchToBudget(with id: UUID) -> Bool {
        let allBudgets = getAllBudgetsSorted()
        guard let targetBudget = allBudgets.first(where: { $0.id == id }) else { return false }

        currentBudget = targetBudget
        loadTransactions()
        return true
    }

    // MARK: - Budget Status Management

    var isBudgetExpired: Bool {
        guard let currentBudget = currentBudget else { return false }
        let today = Date()
        let calendar = Calendar.current
        let endOfBudgetDay = calendar.endOfDay(for: currentBudget.period.endDate) ?? currentBudget.period.endDate
        return today > endOfBudgetDay
    }

    var daysUntilBudgetEnd: Int {
        guard let currentBudget = currentBudget else { return 0 }
        let today = Date()
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: today)
        let startOfEndDate = calendar.startOfDay(for: currentBudget.period.endDate)

        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfEndDate)
        return max(0, components.day ?? 0)
    }

    func checkBudgetStatus() -> BudgetStatus {
        guard currentBudget != nil else { return .noBudget }

        if isBudgetExpired {
            return .expired
        }

        let daysLeft = daysUntilBudgetEnd
        if daysLeft <= 1 {
            return .endingSoon(daysLeft: daysLeft)
        }

        return .active
    }

    func getNextBudgetPeriod() -> BudgetPeriod {
        guard let currentBudget = currentBudget else {
            // Fallback to creating a new monthly budget starting today
            return BudgetPeriod(startDate: Date())
        }

        let calendar = Calendar.current
        let currentPeriod = currentBudget.period

        switch currentPeriod.type {
        case .monthly:
            // Next month budget: start day after current budget ends
            let nextStartDate = calendar.date(byAdding: .day, value: 1, to: currentPeriod.endDate) ?? Date()
            return BudgetPeriod(type: .monthly, startDate: nextStartDate)

        case .custom:
            // For custom budgets, create the same duration starting after current budget ends
            let duration = currentPeriod.durationInDays
            let nextStartDate = calendar.date(byAdding: .day, value: 1, to: currentPeriod.endDate) ?? Date()
            let nextEndDate = calendar.date(byAdding: .day, value: duration - 1, to: nextStartDate) ?? nextStartDate

            let customName = BudgetPeriod.generateCustomName(for: nextStartDate, endDate: nextEndDate)
            return BudgetPeriod(type: .custom, startDate: nextStartDate, endDate: nextEndDate, customName: customName)
        }
    }

    func createNextPeriodBudget() -> Bool {
        guard let currentBudget = currentBudget else { return false }

        let nextPeriod = getNextBudgetPeriod()
        let nextBudget = Budget(
            period: nextPeriod,
            currency: currentBudget.currency,
            categories: currentBudget.categories,
            categoryAmounts: currentBudget.categoryAmounts
        )

        return createBudget(nextBudget)
    }

}