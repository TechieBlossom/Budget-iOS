import Foundation
import SwiftData

// Test class for database operations
@MainActor
class DatabaseTest {
    private let databaseService: DatabaseService
    
    init(modelContext: ModelContext) {
        self.databaseService = DatabaseService(modelContext: modelContext)
    }
    
    func runTests() {
        print("🧪 Starting SwiftData database tests...")
        
        // Test 1: Create and fetch budget
        testBudgetCRUD()
        
        // Test 2: Create and fetch transactions
        testTransactionCRUD()
        
        // Test 3: Find budget for transaction date
        testFindBudgetForDate()
        
        print("✅ All SwiftData database tests completed!")
    }
    
    private func testBudgetCRUD() {
        print("📊 Testing Budget CRUD operations...")
        
        // Create a test budget
        let testBudget = createTestBudget()
        
        // Test CREATE
        let createSuccess = databaseService.createBudget(testBudget)
        print("Create Budget: \(createSuccess ? "✅" : "❌")")
        
        // Test READ
        let fetchedBudgets = databaseService.fetchBudgets()
        print("Fetch Budgets: \(fetchedBudgets.count > 0 ? "✅" : "❌")")
        
        // Test READ by ID
        let budgetById = databaseService.fetchBudget(by: testBudget.id)
        print("Fetch Budget by ID: \(budgetById != nil ? "✅" : "❌")")
        
        // Test UPDATE
        if var budget = budgetById {
            // Update category amounts
            var newCategoryAmounts = budget.categoryAmounts
            newCategoryAmounts[budget.categories.first?.id.uuidString ?? ""] = 1000.0
            
            let updatedBudget = Budget(
                id: budget.id,
                period: budget.period,
                currency: budget.currency,
                categories: budget.categories,
                categoryAmounts: newCategoryAmounts
            )
            
            let updateSuccess = databaseService.updateBudget(updatedBudget)
            print("Update Budget: \(updateSuccess ? "✅" : "❌")")
        }
        
        // Test DELETE
        let deleteSuccess = databaseService.deleteBudget(by: testBudget.id)
        print("Delete Budget: \(deleteSuccess ? "✅" : "❌")")
    }
    
    private func testTransactionCRUD() {
        print("💳 Testing Transaction CRUD operations...")
        
        // Create a test budget first
        let testBudget = createTestBudget()
        _ = databaseService.createBudget(testBudget)
        
        // Create a test transaction
        let testTransaction = Transaction(
            amount: 50.0,
            notes: "Test transaction",
            date: Date(),
            categoryId: testBudget.categories.first?.id ?? UUID()
        )
        
        // Test CREATE
        let createSuccess = databaseService.createTransaction(testTransaction, budgetId: testBudget.id)
        print("Create Transaction: \(createSuccess ? "✅" : "❌")")
        
        // Test READ
        let fetchedTransactions = databaseService.fetchTransactions(for: testBudget.id)
        print("Fetch Transactions: \(fetchedTransactions.count > 0 ? "✅" : "❌")")
        
        // Test UPDATE
        if let transaction = fetchedTransactions.first {
            let updatedTransaction = Transaction(
                id: transaction.id,
                amount: 75.0,
                notes: "Updated transaction",
                date: transaction.date,
                categoryId: transaction.categoryId
            )
            
            let updateSuccess = databaseService.updateTransaction(updatedTransaction)
            print("Update Transaction: \(updateSuccess ? "✅" : "❌")")
        }
        
        // Test DELETE
        if let transaction = fetchedTransactions.first {
            let deleteSuccess = databaseService.deleteTransaction(by: transaction.id)
            print("Delete Transaction: \(deleteSuccess ? "✅" : "❌")")
        }
        
        // Cleanup
        _ = databaseService.deleteBudget(by: testBudget.id)
    }
    
    private func testFindBudgetForDate() {
        print("🔍 Testing find budget for date...")
        
        // Create a test budget
        let testBudget = createTestBudget()
        _ = databaseService.createBudget(testBudget)
        
        // Test finding budget for a date within the period
        let testDate = Calendar.current.date(byAdding: .day, value: 5, to: testBudget.period.startDate) ?? Date()
        let foundBudget = databaseService.findBudget(for: testDate)
        
        print("Find Budget for Date: \(foundBudget != nil ? "✅" : "❌")")
        
        // Cleanup
        _ = databaseService.deleteBudget(by: testBudget.id)
    }
    
    private func createTestBudget() -> Budget {
        let startDate = Date()
        let period = BudgetPeriod(startDate: startDate)
        let currency = Currency(code: "USD", name: "US Dollar", symbol: "$")
        let categories = Category.createDefault()
        
        var categoryAmounts: [String: Double] = [:]
        for (index, category) in categories.enumerated() {
            categoryAmounts[category.id.uuidString] = Double((index + 1) * 100)
        }
        
        return Budget(
            period: period,
            currency: currency,
            categories: categories,
            categoryAmounts: categoryAmounts
        )
    }
}