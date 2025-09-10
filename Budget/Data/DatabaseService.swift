import Foundation
import SwiftData

@MainActor
protocol DatabaseServiceProtocol {
    // Budget CRUD operations
    func createBudget(_ budget: Budget) -> Bool
    func fetchBudgets() -> [Budget]
    func fetchBudget(by id: UUID) -> Budget?
    func updateBudget(_ budget: Budget) -> Bool
    func deleteBudget(by id: UUID) -> Bool
    
    // Transaction CRUD operations
    func createTransaction(_ transaction: Transaction, budgetId: UUID) -> Bool
    func fetchTransactions(for budgetId: UUID) -> [Transaction]
    func fetchAllTransactions() -> [Transaction]
    func updateTransaction(_ transaction: Transaction) -> Bool
    func deleteTransaction(by id: UUID) -> Bool
    
    // Find budget for transaction date
    func findBudget(for transactionDate: Date) -> Budget?
}

@MainActor
class DatabaseService: DatabaseServiceProtocol {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Budget CRUD Operations
    
    func createBudget(_ budget: Budget) -> Bool {
        do {
            let budgetDataModel = try BudgetDataModel.from(budget)
            modelContext.insert(budgetDataModel)
            try modelContext.save()
            return true
        } catch {
            print("Failed to create budget: \(error)")
            return false
        }
    }
    
    func fetchBudgets() -> [Budget] {
        do {
            let descriptor = FetchDescriptor<BudgetDataModel>(
                sortBy: [SortDescriptor(\.startDate, order: .reverse)]
            )
            let budgetDataModels = try modelContext.fetch(descriptor)
            return budgetDataModels.compactMap { $0.toBudget() }
        } catch {
            print("Failed to fetch budgets: \(error)")
            return []
        }
    }
    
    func fetchBudget(by id: UUID) -> Budget? {
        do {
            let idToFind = id
            let descriptor = FetchDescriptor<BudgetDataModel>(
                predicate: #Predicate<BudgetDataModel> { budgetModel in
                    budgetModel.budgetId == idToFind
                }
            )
            let budgetDataModels = try modelContext.fetch(descriptor)
            return budgetDataModels.first?.toBudget()
        } catch {
            print("Failed to fetch budget: \(error)")
            return nil
        }
    }
    
    func updateBudget(_ budget: Budget) -> Bool {
        do {
            let budgetIdToFind = budget.id
            let descriptor = FetchDescriptor<BudgetDataModel>(
                predicate: #Predicate<BudgetDataModel> { budgetModel in
                    budgetModel.budgetId == budgetIdToFind
                }
            )
            let budgetDataModels = try modelContext.fetch(descriptor)
            guard let budgetDataModel = budgetDataModels.first else { return false }
            
            // Update properties
            budgetDataModel.startDate = budget.period.startDate
            budgetDataModel.endDate = budget.period.endDate
            budgetDataModel.currencyCode = budget.currency.code
            budgetDataModel.currencyName = budget.currency.name
            budgetDataModel.currencySymbol = budget.currency.symbol
            
            // Update encoded data
            budgetDataModel.categoriesData = try JSONEncoder().encode(budget.categories.map { CategoryData(from: $0) })
            budgetDataModel.categoryAmountsData = try JSONEncoder().encode(budget.categoryAmounts)
            
            try modelContext.save()
            return true
        } catch {
            print("Failed to update budget: \(error)")
            return false
        }
    }
    
    func deleteBudget(by id: UUID) -> Bool {
        do {
            let idToDelete = id
            let descriptor = FetchDescriptor<BudgetDataModel>(
                predicate: #Predicate<BudgetDataModel> { budgetModel in
                    budgetModel.budgetId == idToDelete
                }
            )
            let budgetDataModels = try modelContext.fetch(descriptor)
            guard let budgetDataModel = budgetDataModels.first else { return false }
            
            modelContext.delete(budgetDataModel)
            try modelContext.save()
            return true
        } catch {
            print("Failed to delete budget: \(error)")
            return false
        }
    }
    
    // MARK: - Transaction CRUD Operations
    
    func createTransaction(_ transaction: Transaction, budgetId: UUID) -> Bool {
        do {
            // Find the budget
            let budgetIdToFind = budgetId
            let budgetDescriptor = FetchDescriptor<BudgetDataModel>(
                predicate: #Predicate<BudgetDataModel> { budgetModel in
                    budgetModel.budgetId == budgetIdToFind
                }
            )
            let budgets = try modelContext.fetch(budgetDescriptor)
            guard let budget = budgets.first else { return false }
            
            let transactionDataModel = TransactionDataModel.from(transaction)
            transactionDataModel.budget = budget
            
            modelContext.insert(transactionDataModel)
            try modelContext.save()
            return true
        } catch {
            print("Failed to create transaction: \(error)")
            return false
        }
    }
    
    func fetchTransactions(for budgetId: UUID) -> [Transaction] {
        do {
            let budgetIdToMatch = budgetId
            let descriptor = FetchDescriptor<TransactionDataModel>(
                predicate: #Predicate<TransactionDataModel> { transactionModel in
                    transactionModel.budget?.budgetId == budgetIdToMatch
                },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            let transactionDataModels = try modelContext.fetch(descriptor)
            return transactionDataModels.map { $0.toTransaction() }
        } catch {
            print("Failed to fetch transactions: \(error)")
            return []
        }
    }
    
    func fetchAllTransactions() -> [Transaction] {
        do {
            let descriptor = FetchDescriptor<TransactionDataModel>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            let transactionDataModels = try modelContext.fetch(descriptor)
            return transactionDataModels.map { $0.toTransaction() }
        } catch {
            print("Failed to fetch all transactions: \(error)")
            return []
        }
    }
    
    func updateTransaction(_ transaction: Transaction) -> Bool {
        do {
            let transactionIdToFind = transaction.id
            let descriptor = FetchDescriptor<TransactionDataModel>(
                predicate: #Predicate<TransactionDataModel> { transactionModel in
                    transactionModel.transactionId == transactionIdToFind
                }
            )
            let transactionDataModels = try modelContext.fetch(descriptor)
            guard let transactionDataModel = transactionDataModels.first else { return false }
            
            transactionDataModel.amount = transaction.amount
            transactionDataModel.notes = transaction.notes
            transactionDataModel.date = transaction.date
            transactionDataModel.categoryId = transaction.categoryId
            
            try modelContext.save()
            return true
        } catch {
            print("Failed to update transaction: \(error)")
            return false
        }
    }
    
    func deleteTransaction(by id: UUID) -> Bool {
        do {
            let idToDelete = id
            let descriptor = FetchDescriptor<TransactionDataModel>(
                predicate: #Predicate<TransactionDataModel> { transactionModel in
                    transactionModel.transactionId == idToDelete
                }
            )
            let transactionDataModels = try modelContext.fetch(descriptor)
            guard let transactionDataModel = transactionDataModels.first else { return false }
            
            modelContext.delete(transactionDataModel)
            try modelContext.save()
            return true
        } catch {
            print("Failed to delete transaction: \(error)")
            return false
        }
    }
    
    // MARK: - Helper Methods
    
    func findBudget(for transactionDate: Date) -> Budget? {
        do {
            let descriptor = FetchDescriptor<BudgetDataModel>(
                predicate: #Predicate { budgetModel in
                    transactionDate >= budgetModel.startDate && transactionDate <= budgetModel.endDate
                }
            )
            let budgetDataModels = try modelContext.fetch(descriptor)
            return budgetDataModels.first?.toBudget()
        } catch {
            print("Failed to find budget for date: \(error)")
            return nil
        }
    }
}