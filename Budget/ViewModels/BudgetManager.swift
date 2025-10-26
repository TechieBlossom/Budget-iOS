import Foundation
import SwiftData

@MainActor
@Observable
class BudgetManager: BudgetManagerProtocol {
    private let databaseService: DatabaseServiceProtocol
    var currentBudget: Budget?
    var transactions: [Transaction] = []
    private var lastDeletedTransaction: Transaction?

    // Sync properties
    var syncState: SyncState = .idle
    private var syncManager: SupabaseSyncManager?
    private let networkMonitor = NetworkMonitor()
    private var authManager: AuthManager?

    /// Whether an active budget exists
    var hasActiveBudget: Bool {
        currentBudget != nil
    }

    init(modelContext: ModelContext, authManager: AuthManager? = nil, syncManager: SupabaseSyncManager? = nil) {
        self.authManager = authManager
        self.databaseService = DatabaseService(modelContext: modelContext, authManager: authManager)
        self.syncManager = syncManager ?? SupabaseSyncManager(modelContext: modelContext)

        // Load active budget from local DB first (instant)
        loadCurrentBudget()

        // Sync state from sync manager
        updateSyncState()

        // Then sync in background if authenticated
        if authManager?.isAuthenticated == true {
            Task {
                await syncActiveBudget()
            }
        }
    }
    
    // MARK: - Budget Operations

    func createBudget(_ budget: Budget) -> Bool {
        let success = databaseService.createBudget(budget)
        if success {
            currentBudget = budget
            loadTransactions()

            // Trigger sync if online
            triggerSync()
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
        print("🔄 BudgetManager: Updating budget \(budget.id)")
        let success = databaseService.updateBudget(budget)
        if success {
            print("   ✅ Database update successful")
            currentBudget = budget

            // Trigger sync if online
            print("   🌐 Triggering sync...")
            triggerSync()
        } else {
            print("   ❌ Database update failed")
        }
        return success
    }
    
    func deleteBudget(_ budgetId: UUID) -> Bool {
        let success = databaseService.deleteBudget(by: budgetId)
        if success && currentBudget?.id == budgetId {
            currentBudget = nil
            transactions = []

            // Trigger sync if online
            triggerSync()
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
        let targetBudget: Budget?

        if let budgetId = budgetId {
            targetBudgetId = budgetId
            targetBudget = databaseService.fetchBudget(by: budgetId)
        } else if let currentBudget = currentBudget {
            targetBudgetId = currentBudget.id
            targetBudget = currentBudget
        } else {
            // Try to find appropriate budget for transaction date
            guard let appropriateBudget = databaseService.findBudget(for: transaction.date) else {
                return false
            }
            targetBudgetId = appropriateBudget.id
            targetBudget = appropriateBudget
        }

        // Validate transaction date is within budget period
        if let budget = targetBudget {
            guard transaction.date >= budget.period.startDate &&
                  transaction.date <= budget.period.endDate else {
                print("❌ Transaction date must be within budget period (\(budget.period.startDate) - \(budget.period.endDate))")
                return false
            }
        }

        let success = databaseService.createTransaction(transaction, budgetId: targetBudgetId)
        if success {
            if targetBudgetId == currentBudget?.id {
                transactions.append(transaction)
            }

            // Trigger sync if online
            triggerSync()
        }
        return success
    }
    
    func addTransaction(_ transaction: Transaction) -> Bool {
        return addTransaction(transaction, to: nil)
    }
    
    func updateTransaction(_ transaction: Transaction) -> Bool {
        // Validate transaction date is within budget period if current budget
        if let currentBudget = currentBudget {
            guard transaction.date >= currentBudget.period.startDate &&
                  transaction.date <= currentBudget.period.endDate else {
                print("❌ Transaction date must be within budget period (\(currentBudget.period.startDate) - \(currentBudget.period.endDate))")
                return false
            }
        }

        let success = databaseService.updateTransaction(transaction)
        if success {
            if let index = transactions.firstIndex(where: { $0.id == transaction.id }) {
                transactions[index] = transaction
            }

            // Trigger sync if online
            triggerSync()
        }
        return success
    }
    
    func deleteTransaction(_ transaction: Transaction) -> Bool {
        let success = databaseService.deleteTransaction(by: transaction.id)
        if success {
            lastDeletedTransaction = transaction
            transactions.removeAll { $0.id == transaction.id }

            // Trigger sync if online
            triggerSync()
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

        // Trigger sync if online and at least one deletion succeeded
        if allSuccess {
            triggerSync()
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

            // Trigger sync if online
            triggerSync()
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
            .sorted { $0.amount > $1.amount }
            .prefix(limit)
            .map { $0 }
    }

    func subCategories(for group: CategoryGroup) -> [SubCategory] {
        let filteredCategories = budget.categories.filter { $0.categoryGroup == group }

        // Sort by spending percentage (highest first)
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

    func createNextPeriodBudget() async -> Bool {
        guard let currentBudget = currentBudget else { return false }

        // Deactivate current budget if authenticated
        if authManager?.isAuthenticated == true {
            do {
                try await syncManager?.deactivateCurrentBudget()
            } catch {
                print("Failed to deactivate current budget: \(error)")
                return false
            }
        }

        let nextPeriod = getNextBudgetPeriod()
        let nextBudget = Budget(
            period: nextPeriod,
            currency: currentBudget.currency,
            categories: currentBudget.categories,
            categoryAmounts: currentBudget.categoryAmounts
        )

        let success = createBudget(nextBudget)

        // Sync new budget to server
        if success && authManager?.isAuthenticated == true {
            await syncActiveBudget()
        }

        return success
    }

    // MARK: - Sync Methods

    /// Sync active budget with Supabase
    func syncActiveBudget() async {
        guard let syncManager = syncManager else {
            print("   ⚠️ Sync skipped: No sync manager available")
            return
        }

        print("🔄 BudgetManager: Starting sync with Supabase...")
        do {
            try await syncManager.syncActiveBudget()
            print("   ✅ Sync completed successfully")
            updateSyncState()
            // Reload local data after sync
            loadCurrentBudget()
        } catch {
            print("   ❌ Sync failed: \(error)")
            syncState = .error(error.localizedDescription)
        }
    }

    /// Update sync state from sync manager
    private func updateSyncState() {
        guard let syncManager = syncManager else { return }
        syncState = syncManager.syncState
    }

    /// Trigger sync after data changes
    private func triggerSync() {
        guard networkMonitor.isConnected else {
            print("   ⚠️ Sync skipped: No network connection")
            return
        }
        guard authManager?.isAuthenticated == true else {
            print("   ⚠️ Sync skipped: User not authenticated")
            return
        }

        print("   ✅ Network connected and authenticated, starting sync task...")
        Task {
            await syncActiveBudget()
        }
    }

    /// Force a full sync
    func forceSync() async {
        guard let syncManager = syncManager else { return }

        do {
            try await syncManager.forceSync()
            updateSyncState()
            loadCurrentBudget()
        } catch {
            print("Force sync failed: \(error)")
            syncState = .error(error.localizedDescription)
        }
    }

    /// Reset sync flags and force sync (for recovery from failed syncs)
    func resetAndSync() async {
        guard let syncManager = syncManager else { return }

        do {
            print("🔄 Forcing full re-sync from Supabase...")
            try await syncManager.forceSync()
            updateSyncState()
            loadCurrentBudget()
            print("✅ Force sync completed, budget reloaded")
        } catch {
            print("Reset and sync failed: \(error)")
            syncState = .error(error.localizedDescription)
        }
    }

}