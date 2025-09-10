import Foundation

@MainActor
protocol BudgetManagerProtocol {
    var budget: Budget { get }
    var totalSpent: Double { get }
    var totalRemains: Double { get }
    var spentPercentage: Double { get }
    
    func spentAmount(for category: Category) -> Double
    func remainingAmount(for category: Category) -> Double
    func spentPercentage(for category: Category) -> Double
    func recentTransactions(for category: Category, limit: Int) -> [Transaction]
    func getAllTransactions() -> [Transaction]
    func addTransaction(_ transaction: Transaction) -> Bool
    func deleteTransaction(_ transaction: Transaction) -> Bool
}