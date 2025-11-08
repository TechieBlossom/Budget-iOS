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

    // Data cleanup
    func clearAllLocalData() throws
}

@MainActor
class DatabaseService: DatabaseServiceProtocol {
    private let modelContext: ModelContext
    private var authManager: AuthManager?

    init(modelContext: ModelContext, authManager: AuthManager? = nil) {
        self.modelContext = modelContext
        self.authManager = authManager
    }

    /// Set auth manager (for dependency injection)
    func setAuthManager(_ authManager: AuthManager) {
        self.authManager = authManager
    }

    /// Get current user ID
    private var currentUserId: UUID? {
        return authManager?.currentUser?.id
    }

    // MARK: - Budget CRUD Operations

    func createBudget(_ budget: Budget) -> Bool {
        do {
            let budgetDataModel = BudgetDataModel.from(budget, userId: currentUserId)
            budgetDataModel.updatedAt = Date()

            modelContext.insert(budgetDataModel)

            // Create CategoryDataModel entries for each category with allocated amounts
            for category in budget.categories {
                let allocatedAmount = budget.categoryAmounts[category.id.uuidString] ?? 0.0
                let categoryDataModel = CategoryDataModel.from(
                    category,
                    budgetId: budget.id,
                    allocatedAmount: allocatedAmount
                )
                categoryDataModel.budget = budgetDataModel
                modelContext.insert(categoryDataModel)
            }

            try modelContext.save()
            return true
        } catch {
            print("Failed to create budget: \(error)")
            return false
        }
    }

    func fetchBudgets() -> [Budget] {
        do {
            // Filter by current user if authenticated
            let userId = currentUserId
            let descriptor: FetchDescriptor<BudgetDataModel>

            if let userId = userId {
                descriptor = FetchDescriptor<BudgetDataModel>(
                    predicate: #Predicate { budget in
                        budget.userId == userId
                    },
                    sortBy: [SortDescriptor(\.startDate, order: .reverse)]
                )
            } else {
                // No user logged in - fetch all (for backward compatibility)
                descriptor = FetchDescriptor<BudgetDataModel>(
                    sortBy: [SortDescriptor(\.startDate, order: .reverse)]
                )
            }

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
            let userId = currentUserId
            let descriptor: FetchDescriptor<BudgetDataModel>

            if let userId = userId {
                descriptor = FetchDescriptor<BudgetDataModel>(
                    predicate: #Predicate<BudgetDataModel> { budgetModel in
                        budgetModel.budgetId == idToFind && budgetModel.userId == userId
                    }
                )
            } else {
                // No user logged in - fetch without user filter (for backward compatibility)
                descriptor = FetchDescriptor<BudgetDataModel>(
                    predicate: #Predicate<BudgetDataModel> { budgetModel in
                        budgetModel.budgetId == idToFind
                    }
                )
            }

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
            budgetDataModel.budgetType = budget.period.type.rawValue
            budgetDataModel.budgetName = budget.period.name
            budgetDataModel.updatedAt = Date()

            // Update categories using CategoryDataModel
            let existingCategories = budgetDataModel.categories
            let existingCategoryMap = Dictionary(uniqueKeysWithValues: existingCategories.map { ($0.categoryId, $0) })
            var categoriesToKeep = Set<UUID>()

            // Update or create categories
            for category in budget.categories {
                categoriesToKeep.insert(category.id)
                let allocatedAmount = budget.categoryAmounts[category.id.uuidString] ?? 0.0

                if let existingCategory = existingCategoryMap[category.id] {
                    // Update existing category
                    existingCategory.name = category.name
                    existingCategory.categoryGroup = category.categoryGroup.rawValue
                    existingCategory.categoryType = category.categoryType.rawValue
                    existingCategory.allocatedAmount = allocatedAmount
                    existingCategory.updatedAt = Date()
                } else {
                    // Create new category
                    let newCategory = CategoryDataModel.from(category, budgetId: budget.id, allocatedAmount: allocatedAmount)
                    newCategory.budget = budgetDataModel
                    modelContext.insert(newCategory)
                }
            }

            // Delete categories that are no longer in the budget
            for existingCategory in existingCategories {
                if !categoriesToKeep.contains(existingCategory.categoryId) {
                    modelContext.delete(existingCategory)
                }
            }

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

            // Find the category to get its group
            let categoryIdToFind = transaction.categoryId
            let categoryDescriptor = FetchDescriptor<CategoryDataModel>(
                predicate: #Predicate<CategoryDataModel> { categoryModel in
                    categoryModel.categoryId == categoryIdToFind && categoryModel.budgetId == budgetIdToFind
                }
            )
            let categories = try modelContext.fetch(categoryDescriptor)
            let categoryGroup = categories.first?.categoryGroup ?? "Miscellaneous"

            let transactionDataModel = TransactionDataModel.from(transaction, categoryGroup: categoryGroup)
            transactionDataModel.budget = budget
            transactionDataModel.updatedAt = Date()

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

            // Find the category to get its group
            let categoryIdToFind = transaction.categoryId
            let budgetId = transactionDataModel.budget?.budgetId
            let categoryDescriptor = FetchDescriptor<CategoryDataModel>(
                predicate: #Predicate<CategoryDataModel> { categoryModel in
                    categoryModel.categoryId == categoryIdToFind && (budgetId == nil || categoryModel.budgetId == budgetId!)
                }
            )
            let categories = try modelContext.fetch(categoryDescriptor)
            let categoryGroup = categories.first?.categoryGroup ?? "Miscellaneous"

            transactionDataModel.amount = transaction.amount
            transactionDataModel.name = transaction.name
            transactionDataModel.notes = transaction.notes
            transactionDataModel.date = transaction.date
            transactionDataModel.categoryId = transaction.categoryId
            transactionDataModel.categoryGroup = categoryGroup
            transactionDataModel.updatedAt = Date()

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
            let userId = currentUserId
            let descriptor: FetchDescriptor<BudgetDataModel>

            if let userId = userId {
                descriptor = FetchDescriptor<BudgetDataModel>(
                    predicate: #Predicate { budgetModel in
                        transactionDate >= budgetModel.startDate &&
                        transactionDate <= budgetModel.endDate &&
                        budgetModel.userId == userId
                    }
                )
            } else {
                // No user logged in - fetch without user filter (for backward compatibility)
                descriptor = FetchDescriptor<BudgetDataModel>(
                    predicate: #Predicate { budgetModel in
                        transactionDate >= budgetModel.startDate && transactionDate <= budgetModel.endDate
                    }
                )
            }

            let budgetDataModels = try modelContext.fetch(descriptor)
            return budgetDataModels.first?.toBudget()
        } catch {
            print("Failed to find budget for date: \(error)")
            return nil
        }
    }

    // MARK: - Data Cleanup Methods

    /// Clear all local data (budgets, categories, transactions)
    /// Use this when user logs out to ensure data privacy
    func clearAllLocalData() throws {
        print("🗑️ Clearing all local data...")

        // Delete all transactions
        let transactionDescriptor = FetchDescriptor<TransactionDataModel>()
        let transactions = try modelContext.fetch(transactionDescriptor)
        for transaction in transactions {
            modelContext.delete(transaction)
        }
        print("   ✅ Deleted \(transactions.count) transactions")

        // Delete all categories
        let categoryDescriptor = FetchDescriptor<CategoryDataModel>()
        let categories = try modelContext.fetch(categoryDescriptor)
        for category in categories {
            modelContext.delete(category)
        }
        print("   ✅ Deleted \(categories.count) categories")

        // Delete all budgets
        let budgetDescriptor = FetchDescriptor<BudgetDataModel>()
        let budgets = try modelContext.fetch(budgetDescriptor)
        for budget in budgets {
            modelContext.delete(budget)
        }
        print("   ✅ Deleted \(budgets.count) budgets")

        // Save changes
        try modelContext.save()
        print("   ✅ All local data cleared successfully")
    }
}
