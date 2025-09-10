import Foundation
import SwiftData

@MainActor
@Observable
class BudgetManager: BudgetManagerProtocol {
    private let databaseService: DatabaseServiceProtocol
    var currentBudget: Budget?
    var transactions: [Transaction] = []
    
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
        
        if let budget = currentBudget {
            loadTransactions()
        }
        // Note: Removed auto-creation of sample budget to allow proper onboarding flow
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
            transactions.removeAll { $0.id == transaction.id }
        }
        return success
    }
    
    func getTransactions(for budgetId: UUID) -> [Transaction] {
        return databaseService.fetchTransactions(for: budgetId)
    }
    
    func getAllTransactions() -> [Transaction] {
        return databaseService.fetchAllTransactions()
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
    
    func spentAmount(for category: Category) -> Double {
        transactions
            .filter { $0.categoryId == category.id }
            .reduce(0) { $0 + $1.amount }
    }
    
    func remainingAmount(for category: Category) -> Double {
        let allocated = budget.categoryAmounts[category.id.uuidString] ?? 0
        let spent = spentAmount(for: category)
        return max(0, allocated - spent)
    }
    
    func spentPercentage(for category: Category) -> Double {
        let allocated = budget.categoryAmounts[category.id.uuidString] ?? 0
        guard allocated > 0 else { return 0 }
        let spent = spentAmount(for: category)
        return min(1.0, spent / allocated)
    }
    
    func recentTransactions(for category: Category, limit: Int = 5) -> [Transaction] {
        transactions
            .filter { $0.categoryId == category.id }
            .sorted { $0.date > $1.date }
            .prefix(limit)
            .map { $0 }
    }
    
    // MARK: - Smart Budget Selection
    
    func findBudgetForExpense(date: Date) -> Budget? {
        return databaseService.findBudget(for: date)
    }
    
    func addExpenseToBestFitBudget(_ transaction: Transaction) -> Bool {
        guard let targetBudget = findBudgetForExpense(date: transaction.date) else {
            // If no budget exists for the transaction date, add to current budget
            return addTransaction(transaction)
        }
        
        return addTransaction(transaction, to: targetBudget.id)
    }
}