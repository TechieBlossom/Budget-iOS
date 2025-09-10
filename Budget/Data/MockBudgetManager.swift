import Foundation

// Mock BudgetManager for SwiftUI previews
@Observable
class MockBudgetManager: BudgetManagerProtocol {
    var currentBudget: Budget?
    var transactions: [Transaction] = []
    
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
    
    func getAllTransactions() -> [Transaction] {
        return transactions
    }
    
    // Mock methods (do nothing in preview)
    func addTransaction(_ transaction: Transaction) -> Bool {
        transactions.append(transaction)
        return true
    }
    
    func deleteTransaction(_ transaction: Transaction) -> Bool {
        transactions.removeAll { $0.id == transaction.id }
        return true
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