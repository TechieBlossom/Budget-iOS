//
//  BudgetManager.swift (REFACTORED)
//  Budget
//
//  Refactored to use Supabase as single source of truth
//  Local DB is cache for offline read access only
//

import Foundation
import SwiftData

@MainActor
@Observable
class BudgetManager: BudgetManagerProtocol {
    // MARK: - Dependencies
    private let databaseService: DatabaseServiceProtocol
    private let supabaseService: SupabaseService
    private let authManager: AuthManager?
    private let networkMonitor = NetworkMonitor()

    // MARK: - State
    var currentBudget: Budget?
    var transactions: [Transaction] = []
    var isLoading: Bool = false
    var lastError: String? = nil
    var syncState: SyncState = .offline
    private var lastDeletedTransaction: Transaction?

    // MARK: - Computed Properties
    var hasActiveBudget: Bool {
        currentBudget != nil
    }

    // MARK: - Initialization
    init(modelContext: ModelContext, authManager: AuthManager? = nil) {
        self.authManager = authManager
        self.databaseService = DatabaseService(modelContext: modelContext, authManager: authManager)
        self.supabaseService = SupabaseService()

        // Load from cache immediately (optimistic UI)
        loadFromCache()

        // Set initial sync state based on authentication and network
        if authManager?.isAuthenticated == true {
            if networkMonitor.isConnected {
                syncState = .syncing
            } else {
                syncState = .offline
            }

            // Then sync in background
            Task {
                await refreshFromSupabase()
            }
        } else {
            syncState = .offline
        }
    }

    // MARK: - Optimistic UI Load Pattern

    /// Load data from local cache immediately (instant UI)
    private func loadFromCache() {
        let budgets = databaseService.fetchBudgets()
        currentBudget = budgets.sorted { $0.period.startDate > $1.period.startDate }.first

        if let budgetId = currentBudget?.id {
            transactions = databaseService.fetchTransactions(for: budgetId)
        }
    }

    /// Refresh data from Supabase in background
    func refreshFromSupabase() async {
        guard let userId = authManager?.currentUser?.id else {
            syncState = .offline
            return
        }

        guard networkMonitor.isConnected else {
            syncState = .offline
            return
        }

        syncState = .syncing

        do {
            // STEP 1: Fetch from Supabase (source of truth)
            guard let supabaseBudget = try await supabaseService.fetchActiveBudget(userId: userId) else {
                syncState = .synced(Date())
                return
            }

            let categories = try await supabaseService.fetchCategories(budgetId: supabaseBudget.id)
            let transactions = try await supabaseService.fetchTransactions(categoryIds: categories.map { $0.id })

            // STEP 2: Intelligently sync local cache (DON'T clear everything!)
            let budget = supabaseBudget.toBudget(categories: categories)

            // Sync budget: update if exists, create if new
            if databaseService.fetchBudget(by: budget.id) != nil {
                _ = databaseService.updateBudget(budget)
            } else {
                _ = databaseService.createBudget(budget)
            }

            // Sync transactions: compare and update only what changed
            let localTransactions = databaseService.fetchTransactions(for: budget.id)
            let localTransactionIds = Set(localTransactions.map { $0.id })
            let remoteTransactionIds = Set(transactions.map { $0.id })

            // Delete transactions that no longer exist in Supabase
            for localTx in localTransactions {
                if !remoteTransactionIds.contains(localTx.id) {
                    _ = databaseService.deleteTransaction(by: localTx.id)
                }
            }

            // Update existing or create new transactions
            for remoteTx in transactions {
                let transaction = remoteTx.toTransaction()
                if localTransactionIds.contains(transaction.id) {
                    _ = databaseService.updateTransaction(transaction)
                } else {
                    _ = databaseService.createTransaction(transaction, budgetId: budget.id)
                }
            }

            // STEP 3: Update in-memory state (UI updates automatically via @Observable)
            currentBudget = budget
            self.transactions = transactions.map { $0.toTransaction() }

            // STEP 4: Update sync state
            syncState = .synced(Date())

        } catch {
            lastError = "Failed to refresh: \(error.localizedDescription)"
            if !networkMonitor.isConnected {
                syncState = .offline
            } else {
                syncState = .error(error.localizedDescription)
            }
        }
    }

    // MARK: - Budget Operations

    /// Create a new budget (async write to Supabase)
    func createBudget(_ budget: Budget) async -> Bool {
        guard let userId = authManager?.currentUser?.id else {
            lastError = "Not authenticated"
            return false
        }

        guard networkMonitor.isConnected else {
            lastError = "No internet connection"
            return false
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // STEP 1: Write to Supabase
            _ = try await supabaseService.createBudget(budget, userId: userId)

            // STEP 2: Create categories in Supabase
            for category in budget.categories {
                let amount = budget.categoryAmounts[category.id.uuidString] ?? 0
                let supabaseCategory = SupabaseCategory.from(category, budgetId: budget.id, amount: amount)
                _ = try await supabaseService.createCategory(supabaseCategory)
            }

            // STEP 3: Read back from Supabase to get server state
            guard let freshBudget = try await supabaseService.fetchActiveBudget(userId: userId) else {
                throw BudgetError.supabaseFailed("Failed to read created budget")
            }
            let freshCategories = try await supabaseService.fetchCategories(budgetId: freshBudget.id)

            // STEP 4: Update local cache
            let cachedBudget = freshBudget.toBudget(categories: freshCategories)
            _ = databaseService.createBudget(cachedBudget)

            // STEP 5: Update in-memory state
            currentBudget = cachedBudget
            transactions = []

            return true
        } catch {
            lastError = "Failed to create budget: \(error.localizedDescription)"
            return false
        }
    }

    /// Synchronous version for compatibility (shows error immediately)
    func createBudget(_ budget: Budget) -> Bool {
        guard networkMonitor.isConnected else {
            lastError = "No internet connection. Please try again when online."
            return false
        }

        // Use Task to run async in sync context
        var result = false
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            result = await createBudget(budget)
            semaphore.signal()
        }

        semaphore.wait()
        return result
    }

    func updateBudget(_ budget: Budget) async -> Bool {
        print("🔄 BudgetManager.updateBudget called")

        guard let userId = authManager?.currentUser?.id else {
            lastError = "Not authenticated"
            print("   ❌ Not authenticated")
            return false
        }

        guard networkMonitor.isConnected else {
            lastError = "No internet connection"
            print("   ❌ No internet connection")
            return false
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // STEP 1: Write to Supabase
            print("   📤 Step 1: Updating budget in Supabase...")
            _ = try await supabaseService.updateBudget(budget, userId: userId)
            print("   ✅ Budget updated in Supabase")

            // STEP 2: Sync only changed categories to Supabase
            let oldCategories = currentBudget?.categories ?? []
            let oldAmounts = currentBudget?.categoryAmounts ?? [:]

            var categoriesToUpdate: [(category: SubCategory, isNew: Bool)] = []
            for category in budget.categories {
                let newAmount = budget.categoryAmounts[category.id.uuidString] ?? 0
                let oldAmount = oldAmounts[category.id.uuidString] ?? 0

                // Check if category changed
                if let oldCategory = oldCategories.first(where: { $0.id == category.id }) {
                    // Category exists - check if it changed
                    if oldCategory.name != category.name ||
                       oldCategory.categoryGroup != category.categoryGroup ||
                       oldCategory.categoryType != category.categoryType ||
                       oldAmount != newAmount {
                        categoriesToUpdate.append((category, false))
                    }
                } else {
                    // New category - needs to be created
                    categoriesToUpdate.append((category, true))
                }
            }

            var hasNewCategories = false
            if !categoriesToUpdate.isEmpty {
                print("   📤 Step 2: Syncing \(categoriesToUpdate.count) changed categories to Supabase...")
                for (category, isNew) in categoriesToUpdate {
                    let amount = budget.categoryAmounts[category.id.uuidString] ?? 0
                    let supabaseCategory = SupabaseCategory.from(category, budgetId: budget.id, amount: amount)

                    if isNew {
                        print("      ➕ Creating category: \(category.name)")
                        _ = try await supabaseService.createCategory(supabaseCategory)
                        hasNewCategories = true
                    } else {
                        print("      ✏️ Updating category: \(category.name)")
                        _ = try await supabaseService.updateCategory(supabaseCategory)
                    }
                }
                print("   ✅ Synced \(categoriesToUpdate.count) categories to Supabase")
            } else {
                print("   ✅ Step 2: No category changes detected, skipping sync")
            }

            // STEP 3: Update local cache directly (no fetch needed for simple updates!)
            print("   💾 Step 3: Updating local cache...")
            print("   Budget being saved has categoryAmounts: \(budget.categoryAmounts)")
            _ = databaseService.updateBudget(budget)
            print("   ✅ Local cache updated")

            // STEP 4: Update in-memory state
            currentBudget = budget
            print("   ✅ In-memory state updated")
            print("   currentBudget.categoryAmounts is now: \(currentBudget?.categoryAmounts ?? [:])")
            print("🎉 BudgetManager.updateBudget completed successfully (optimized - no fetch!)")

            return true
        } catch {
            lastError = "Failed to update budget: \(error.localizedDescription)"
            print("   ❌ Error: \(error.localizedDescription)")
            return false
        }
    }

    func updateBudget(_ budget: Budget) -> Bool {
        print("🔄 BudgetManager.updateBudget (sync) called")

        guard networkMonitor.isConnected else {
            lastError = "No internet connection. Please try again when online."
            print("   ❌ No internet connection")
            return false
        }

        print("   ⏳ Waiting for async updateBudget to complete...")
        var result = false
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            result = await updateBudget(budget)
            print("   ⏳ Async updateBudget returned: \(result)")
            semaphore.signal()
        }

        semaphore.wait()
        print("   ✅ Sync updateBudget returning: \(result)")
        return result
    }

    // MARK: - Category Operations

    func deleteCategory(_ categoryId: UUID) async -> Bool {
        guard networkMonitor.isConnected else {
            lastError = "No internet connection"
            return false
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // STEP 1: Delete category from Supabase
            try await supabaseService.deleteCategory(categoryId)

            // STEP 2: Delete associated transactions from Supabase
            let categoryTransactions = transactions.filter { $0.categoryId == categoryId }
            for tx in categoryTransactions {
                try await supabaseService.deleteTransaction(tx.id)
            }

            // STEP 3: Update local cache
            for tx in categoryTransactions {
                _ = databaseService.deleteTransaction(by: tx.id)
            }
            // Note: Category will be removed from cache when budget is updated

            // STEP 4: Update in-memory state
            transactions.removeAll { $0.categoryId == categoryId }
            if let budget = currentBudget {
                let newCategories = budget.categories.filter { $0.id != categoryId }
                var newAmounts = budget.categoryAmounts
                newAmounts.removeValue(forKey: categoryId.uuidString)

                let updatedBudget = Budget(
                    id: budget.id,
                    period: budget.period,
                    currency: budget.currency,
                    categories: newCategories,
                    categoryAmounts: newAmounts
                )

                currentBudget = updatedBudget

                // Update cache with new budget state
                _ = databaseService.updateBudget(updatedBudget)
            }

            return true
        } catch {
            lastError = "Failed to delete category: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Transaction Operations

    func addTransaction(_ transaction: Transaction) async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            let targetBudgetId = currentBudget?.id
            guard let targetBudgetId = targetBudgetId else { return false }

            // Find category group
            let categoryGroup = currentBudget?.categories.first(where: { $0.id == transaction.categoryId })?.categoryGroup.rawValue ?? "Miscellaneous"

            // STEP 1: Create in Supabase
            let supabaseTransaction = SupabaseTransaction.from(transaction, categoryGroup: categoryGroup)
            _ = try await supabaseService.createTransaction(supabaseTransaction)

            // STEP 2: Read back to get server state
            let categoryIds = currentBudget?.categories.map { $0.id } ?? []
            let freshTransactions = try await supabaseService.fetchTransactions(categoryIds: categoryIds)
            guard freshTransactions.contains(where: { $0.id == transaction.id }) else {
                throw BudgetError.supabaseFailed("Transaction not found after creation")
            }

            // STEP 3: Update local cache
            _ = databaseService.createTransaction(transaction, budgetId: targetBudgetId)

            // STEP 4: Update in-memory state
            transactions.append(transaction)

            return true
        } catch {
            lastError = "Failed to add transaction: \(error.localizedDescription)"
            return false
        }
    }

    func addTransaction(_ transaction: Transaction) -> Bool {
        guard networkMonitor.isConnected else {
            lastError = "No internet connection. Please try again when online."
            return false
        }

        var result = false
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            result = await addTransaction(transaction)
            semaphore.signal()
        }

        semaphore.wait()
        return result
    }

    func updateTransaction(_ transaction: Transaction) async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            // STEP 1: Convert to Supabase format
            let categoryGroup = currentBudget?.categories.first(where: { $0.id == transaction.categoryId })?.categoryGroup.rawValue ?? "Miscellaneous"
            let supabaseTransaction = SupabaseTransaction.from(transaction, categoryGroup: categoryGroup)

            // STEP 2: Update in Supabase
            _ = try await supabaseService.updateTransaction(supabaseTransaction)

            // STEP 3: Read back to get server state
            let categoryIds = currentBudget?.categories.map { $0.id } ?? []
            let freshTransactions = try await supabaseService.fetchTransactions(categoryIds: categoryIds)
            guard freshTransactions.contains(where: { $0.id == transaction.id }) else {
                throw BudgetError.supabaseFailed("Transaction not found after update")
            }

            // STEP 4: Update local cache
            _ = databaseService.updateTransaction(transaction)

            // STEP 5: Update in-memory state
            if let index = transactions.firstIndex(where: { $0.id == transaction.id }) {
                transactions[index] = transaction
            }

            return true
        } catch {
            lastError = "Failed to update transaction: \(error.localizedDescription)"
            return false
        }
    }

    func updateTransaction(_ transaction: Transaction) -> Bool {
        guard networkMonitor.isConnected else {
            lastError = "No internet connection. Please try again when online."
            return false
        }

        var result = false
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            result = await updateTransaction(transaction)
            semaphore.signal()
        }

        semaphore.wait()
        return result
    }

    func deleteTransaction(_ transaction: Transaction) async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            // STEP 1: Delete from Supabase
            try await supabaseService.deleteTransaction(transaction.id)

            // STEP 2: Update local cache
            _ = databaseService.deleteTransaction(by: transaction.id)

            // STEP 3: Update in-memory state
            transactions.removeAll { $0.id == transaction.id }
            lastDeletedTransaction = transaction

            return true
        } catch {
            lastError = "Failed to delete transaction: \(error.localizedDescription)"
            return false
        }
    }

    func deleteTransaction(_ transaction: Transaction) -> Bool {
        guard networkMonitor.isConnected else {
            lastError = "No internet connection. Please try again when online."
            return false
        }

        var result = false
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            result = await deleteTransaction(transaction)
            semaphore.signal()
        }

        semaphore.wait()
        return result
    }

    func deleteAllTransactions(for subCategory: SubCategory) -> Bool {
        lastDeletedTransaction = nil
        let categoryTransactions = transactions.filter { $0.categoryId == subCategory.id }
        var allSuccess = true

        for transaction in categoryTransactions {
            if !deleteTransaction(transaction) {
                allSuccess = false
            }
        }

        return allSuccess
    }

    // MARK: - Legacy Methods (keeping for compatibility)

    func loadCurrentBudget() {
        loadFromCache()
    }

    func hasExistingBudgets() -> Bool {
        return !databaseService.fetchBudgets().isEmpty
    }

    func deleteBudget(_ budgetId: UUID) -> Bool {
        // This should deactivate on Supabase, but keeping simple for now
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

    func getTransactions(for budgetId: UUID) -> [Transaction] {
        return databaseService.fetchTransactions(for: budgetId)
    }

    func getAllTransactions() -> [Transaction] {
        return transactions
    }

    func getAllTransactionsAcrossAllBudgets() -> [Transaction] {
        return databaseService.fetchAllTransactions()
    }

    // MARK: - Undo Operations

    func undoLastTransaction() -> Bool {
        guard let deletedTransaction = lastDeletedTransaction else { return false }

        let success = addTransaction(deletedTransaction)
        if success {
            lastDeletedTransaction = nil
        }
        return success
    }

    func canUndo() -> Bool {
        return lastDeletedTransaction != nil
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
        return totalSpent / budget.totalAmount
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
        return spent / budgetAmount
    }

    // MARK: - Budget Analysis with Category Group Filtering

    func totalBudgetAmount(excludingSavings: Bool, selectedGroups: Set<CategoryGroup>) -> Double {
        let categories = budget.categories.filter { category in
            let matchesGroup = selectedGroups.contains(category.categoryGroup)
            let matchesType = !excludingSavings || category.categoryType == .expense
            return matchesGroup && matchesType
        }
        return categories.reduce(0.0) { total, category in
            total + (budget.categoryAmounts[category.id.uuidString] ?? 0)
        }
    }

    func totalSpent(excludingSavings: Bool, selectedGroups: Set<CategoryGroup>) -> Double {
        let categories = budget.categories.filter { category in
            let matchesGroup = selectedGroups.contains(category.categoryGroup)
            let matchesType = !excludingSavings || category.categoryType == .expense
            return matchesGroup && matchesType
        }
        let categoryIds = Set(categories.map { $0.id })
        return transactions
            .filter { categoryIds.contains($0.categoryId) }
            .reduce(0.0) { $0 + $1.amount }
    }

    func totalRemains(excludingSavings: Bool, selectedGroups: Set<CategoryGroup>) -> Double {
        let spent = totalSpent(excludingSavings: excludingSavings, selectedGroups: selectedGroups)
        let budgetAmount = totalBudgetAmount(excludingSavings: excludingSavings, selectedGroups: selectedGroups)
        return max(0, budgetAmount - spent)
    }

    func spentPercentage(excludingSavings: Bool, selectedGroups: Set<CategoryGroup>) -> Double {
        let budgetAmount = totalBudgetAmount(excludingSavings: excludingSavings, selectedGroups: selectedGroups)
        guard budgetAmount > 0 else { return 0 }
        let spent = totalSpent(excludingSavings: excludingSavings, selectedGroups: selectedGroups)
        return spent / budgetAmount
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
        return spent / allocated
    }

    func recentTransactions(for subCategory: SubCategory, limit: Int = 5) -> [Transaction] {
        transactions
            .filter { $0.categoryId == subCategory.id }
            .sorted { $0.amount > $1.amount }
            .prefix(limit)
            .map { $0 }
    }

    func subCategories(for group: CategoryGroup) -> [SubCategory] {
        let filteredCategories = budget.categories.filter { $0.categoryGroup == group }

        return filteredCategories.sorted { cat1, cat2 in
            let percentage1 = spentPercentage(for: cat1)
            let percentage2 = spentPercentage(for: cat2)
            return percentage1 > percentage2
        }
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
        return spent / allocated
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

        let previousIndex = currentIndex + 1
        guard previousIndex < allBudgets.count else { return false }

        currentBudget = allBudgets[previousIndex]
        if let budgetId = currentBudget?.id {
            transactions = databaseService.fetchTransactions(for: budgetId)
        }
        return true
    }

    func switchToNextBudget() -> Bool {
        guard let currentIndex = getCurrentBudgetIndex() else { return false }
        let allBudgets = getAllBudgetsSorted()

        let nextIndex = currentIndex - 1
        guard nextIndex >= 0 else { return false }

        currentBudget = allBudgets[nextIndex]
        if let budgetId = currentBudget?.id {
            transactions = databaseService.fetchTransactions(for: budgetId)
        }
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
        return currentIndex == 0
    }

    func switchToBudget(with id: UUID) -> Bool {
        let allBudgets = getAllBudgetsSorted()
        guard let targetBudget = allBudgets.first(where: { $0.id == id }) else { return false }

        currentBudget = targetBudget
        transactions = databaseService.fetchTransactions(for: targetBudget.id)
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
            return BudgetPeriod(startDate: Date())
        }

        let calendar = Calendar.current
        let currentPeriod = currentBudget.period

        switch currentPeriod.type {
        case .monthly:
            let nextStartDate = calendar.date(byAdding: .day, value: 1, to: currentPeriod.endDate) ?? Date()
            return BudgetPeriod(type: .monthly, startDate: nextStartDate)

        case .custom:
            let duration = currentPeriod.durationInDays
            let nextStartDate = calendar.date(byAdding: .day, value: 1, to: currentPeriod.endDate) ?? Date()
            let nextEndDate = calendar.date(byAdding: .day, value: duration - 1, to: nextStartDate) ?? nextStartDate

            let customName = BudgetPeriod.generateCustomName(for: nextStartDate, endDate: nextEndDate)
            return BudgetPeriod(type: .custom, startDate: nextStartDate, endDate: nextEndDate, customName: customName)
        }
    }

    func createNextPeriodBudget() async -> Bool {
        guard let currentBudget = currentBudget else { return false }
        guard let userId = authManager?.currentUser?.id else { return false }

        // Deactivate current budget
        do {
            try await supabaseService.deactivateBudget(currentBudget.id)
        } catch {
            lastError = "Failed to deactivate current budget: \(error.localizedDescription)"
            return false
        }

        let nextPeriod = getNextBudgetPeriod()

        // Create NEW categories with NEW IDs
        let newCategories = currentBudget.categories.map { oldCategory in
            SubCategory(
                name: oldCategory.name,
                categoryGroup: oldCategory.categoryGroup,
                categoryType: oldCategory.categoryType
            )
        }

        // Map old category amounts to new category IDs
        let newCategoryAmounts = Dictionary(uniqueKeysWithValues:
            zip(newCategories, currentBudget.categories).map { (newCat, oldCat) in
                let oldAmount = currentBudget.categoryAmounts[oldCat.id.uuidString] ?? 0
                return (newCat.id.uuidString, oldAmount)
            }
        )

        let nextBudget = Budget(
            period: nextPeriod,
            currency: currentBudget.currency,
            categories: newCategories,
            categoryAmounts: newCategoryAmounts
        )

        return await createBudget(nextBudget)
    }

    // MARK: - Data Cleanup

    func clearAllData() throws {
        print("🧹 BudgetManager.clearAllData() called")

        guard let databaseService = databaseService as? DatabaseService else {
            throw BudgetError.localDBFailed("Database service not available")
        }

        try databaseService.clearAllLocalData()

        currentBudget = nil
        transactions = []
        lastDeletedTransaction = nil
        syncState = .offline

        print("✅ BudgetManager: All data cleared successfully")
    }
}
