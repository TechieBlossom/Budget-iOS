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
            let budgetDataModel = try BudgetDataModel.from(budget)

            // Set user ID from auth manager
            budgetDataModel.userId = currentUserId

            // Mark as needing sync
            budgetDataModel.needsSync = true
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
                categoryDataModel.needsSync = true
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

            // Update categories using CategoryDataModel (new approach)
            // Get existing categories
            let existingCategories = budgetDataModel.categories

            // Create a map of existing categories by ID
            let existingCategoryMap = Dictionary(uniqueKeysWithValues: existingCategories.map { ($0.categoryId, $0) })

            // Track categories to keep
            var categoriesToKeep = Set<UUID>()

            // Update or create categories
            for category in budget.categories {
                categoriesToKeep.insert(category.id)
                let allocatedAmount = budget.categoryAmounts[category.id.uuidString] ?? 0.0

                if let existingCategory = existingCategoryMap[category.id] {
                    // Update existing category
                    let hasNameChanged = existingCategory.name != category.name
                    let hasGroupChanged = existingCategory.categoryGroup != category.categoryGroup.rawValue
                    let hasTypeChanged = existingCategory.categoryType != category.categoryType.rawValue
                    let hasAmountChanged = existingCategory.allocatedAmount != allocatedAmount

                    if hasNameChanged || hasGroupChanged || hasTypeChanged || hasAmountChanged {
                        print("📝 Updating category '\(existingCategory.name)' (ID: \(category.id))")
                        if hasNameChanged { print("   Name: '\(existingCategory.name)' → '\(category.name)'") }
                        if hasGroupChanged { print("   Group: '\(existingCategory.categoryGroup)' → '\(category.categoryGroup.rawValue)'") }
                        if hasTypeChanged { print("   Type: '\(existingCategory.categoryType)' → '\(category.categoryType.rawValue)'") }
                        if hasAmountChanged { print("   Amount: \(existingCategory.allocatedAmount) → \(allocatedAmount)") }

                        existingCategory.name = category.name
                        existingCategory.categoryGroup = category.categoryGroup.rawValue
                        existingCategory.categoryType = category.categoryType.rawValue
                        existingCategory.allocatedAmount = allocatedAmount
                        existingCategory.needsSync = true
                        existingCategory.updatedAt = Date()
                        print("   ✅ Marked category as needing sync")
                    }
                } else {
                    // Create new category
                    print("➕ Creating new category '\(category.name)' (ID: \(category.id))")
                    let newCategory = CategoryDataModel.from(category, budgetId: budget.id, allocatedAmount: allocatedAmount)
                    newCategory.budget = budgetDataModel
                    newCategory.needsSync = true
                    modelContext.insert(newCategory)
                    print("   ✅ Marked new category as needing sync")
                }
            }

            // Delete categories that are no longer in the budget
            for existingCategory in existingCategories {
                if !categoriesToKeep.contains(existingCategory.categoryId) {
                    modelContext.delete(existingCategory)
                }
            }

            // Also update legacy JSON data for backward compatibility
            budgetDataModel.categoriesData = try JSONEncoder().encode(budget.categories.map { CategoryData(from: $0) })
            budgetDataModel.categoryAmountsData = try JSONEncoder().encode(budget.categoryAmounts)

            // Mark as needing sync
            budgetDataModel.needsSync = true
            budgetDataModel.updatedAt = Date()

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
            // Mark as needing sync
            transactionDataModel.needsSync = true
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
            transactionDataModel.categoryGroup = categoryGroup  // Update category group
            // Mark as needing sync
            transactionDataModel.needsSync = true
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

    // MARK: - Category Management Methods

    /// Fetch all categories for a budget
    func fetchCategories(for budgetId: UUID) -> [CategoryDataModel] {
        do {
            let descriptor = FetchDescriptor<CategoryDataModel>(
                predicate: #Predicate { category in
                    category.budgetId == budgetId
                }
            )
            return try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch categories: \(error)")
            return []
        }
    }

    /// Update category allocated amount
    func updateCategoryAmount(_ categoryId: UUID, amount: Double) -> Bool {
        do {
            let descriptor = FetchDescriptor<CategoryDataModel>(
                predicate: #Predicate { category in
                    category.categoryId == categoryId
                }
            )
            let categories = try modelContext.fetch(descriptor)
            guard let category = categories.first else { return false }

            category.allocatedAmount = amount
            category.needsSync = true
            category.updatedAt = Date()

            try modelContext.save()
            return true
        } catch {
            print("Failed to update category amount: \(error)")
            return false
        }
    }

    /// Create a new category for a budget
    func createCategory(_ subCategory: SubCategory, budgetId: UUID, allocatedAmount: Double = 0) -> Bool {
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

            let categoryDataModel = CategoryDataModel.from(subCategory, budgetId: budgetId, allocatedAmount: allocatedAmount)
            categoryDataModel.budget = budget
            categoryDataModel.needsSync = true

            modelContext.insert(categoryDataModel)
            try modelContext.save()
            return true
        } catch {
            print("Failed to create category: \(error)")
            return false
        }
    }

    /// Delete a category
    func deleteCategory(by id: UUID) -> Bool {
        do {
            let descriptor = FetchDescriptor<CategoryDataModel>(
                predicate: #Predicate { category in
                    category.categoryId == id
                }
            )
            let categories = try modelContext.fetch(descriptor)
            guard let category = categories.first else { return false }

            modelContext.delete(category)
            try modelContext.save()
            return true
        } catch {
            print("Failed to delete category: \(error)")
            return false
        }
    }

    // MARK: - Sync Support Methods

    /// Fetch active budget for current user
    func fetchActiveBudget(userId: UUID) -> Budget? {
        do {
            let descriptor = FetchDescriptor<BudgetDataModel>(
                predicate: #Predicate { budget in
                    budget.userId == userId && budget.isActive == true
                }
            )
            let budgetDataModels = try modelContext.fetch(descriptor)
            return budgetDataModels.first?.toBudget()
        } catch {
            print("Failed to fetch active budget: \(error)")
            return nil
        }
    }

    /// Fetch budgets needing sync
    func fetchUnsyncedBudgets() -> [BudgetDataModel] {
        do {
            let descriptor = FetchDescriptor<BudgetDataModel>(
                predicate: #Predicate { $0.needsSync == true }
            )
            return try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch unsynced budgets: \(error)")
            return []
        }
    }

    /// Fetch categories needing sync
    func fetchUnsyncedCategories() -> [CategoryDataModel] {
        do {
            let descriptor = FetchDescriptor<CategoryDataModel>(
                predicate: #Predicate { $0.needsSync == true }
            )
            return try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch unsynced categories: \(error)")
            return []
        }
    }

    /// Fetch transactions needing sync
    func fetchUnsyncedTransactions() -> [TransactionDataModel] {
        do {
            let descriptor = FetchDescriptor<TransactionDataModel>(
                predicate: #Predicate { $0.needsSync == true }
            )
            return try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch unsynced transactions: \(error)")
            return []
        }
    }

    /// Mark budget as synced
    func markBudgetAsSynced(_ id: UUID) {
        do {
            let descriptor = FetchDescriptor<BudgetDataModel>(
                predicate: #Predicate { $0.budgetId == id }
            )
            let budgets = try modelContext.fetch(descriptor)
            if let budget = budgets.first {
                budget.needsSync = false
                budget.lastSyncedAt = Date()
                try modelContext.save()
            }
        } catch {
            print("Failed to mark budget as synced: \(error)")
        }
    }

    /// Mark category as synced
    func markCategoryAsSynced(_ id: UUID) {
        do {
            let descriptor = FetchDescriptor<CategoryDataModel>(
                predicate: #Predicate { $0.categoryId == id }
            )
            let categories = try modelContext.fetch(descriptor)
            if let category = categories.first {
                category.needsSync = false
                category.lastSyncedAt = Date()
                try modelContext.save()
            }
        } catch {
            print("Failed to mark category as synced: \(error)")
        }
    }

    /// Mark transaction as synced
    func markTransactionAsSynced(_ id: UUID) {
        do {
            let descriptor = FetchDescriptor<TransactionDataModel>(
                predicate: #Predicate { $0.transactionId == id }
            )
            let transactions = try modelContext.fetch(descriptor)
            if let transaction = transactions.first {
                transaction.needsSync = false
                transaction.lastSyncedAt = Date()
                try modelContext.save()
            }
        } catch {
            print("Failed to mark transaction as synced: \(error)")
        }
    }

    /// Set user ID for budget (used during migration)
    func setUserIdForBudget(_ budgetId: UUID, userId: UUID) {
        do {
            let descriptor = FetchDescriptor<BudgetDataModel>(
                predicate: #Predicate { $0.budgetId == budgetId }
            )
            let budgets = try modelContext.fetch(descriptor)
            if let budget = budgets.first {
                budget.userId = userId
                budget.needsSync = true
                try modelContext.save()
            }
        } catch {
            print("Failed to set user ID for budget: \(error)")
        }
    }
}