//
//  SupabaseSyncManager.swift
//  Budget
//
//  Created for Supabase integration
//

import Foundation
import SwiftData
import Supabase

// MARK: - Sync State

enum SyncState: Equatable {
    case idle
    case syncing
    case success(Date)
    case error(String)
    case offline

    static func == (lhs: SyncState, rhs: SyncState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.syncing, .syncing), (.offline, .offline):
            return true
        case (.success(let d1), .success(let d2)):
            return d1 == d2
        case (.error(let e1), .error(let e2)):
            return e1 == e2
        default:
            return false
        }
    }
}

// MARK: - Sync Manager

@MainActor
@Observable
class SupabaseSyncManager {
    // MARK: - Properties

    /// Current sync state
    private(set) var syncState: SyncState = .idle

    /// Last successful sync timestamp
    private(set) var lastSyncTimestamp: Date?

    /// Supabase client
    private let supabase = SupabaseClientManager.shared.client

    /// Network monitor
    private let networkMonitor = NetworkMonitor()

    /// Model context for SwiftData
    private var modelContext: ModelContext

    /// Maximum retry attempts
    private let maxRetries = 3

    /// Batch size for sync operations
    private let batchSize = 100

    // MARK: - Initialization

    init(modelContext: ModelContext) {
        self.modelContext = modelContext

        // Load last sync timestamp
        if let timestamp = UserDefaults.standard.object(forKey: "lastSyncTimestamp") as? Date {
            self.lastSyncTimestamp = timestamp
        }

        // Set up network monitoring
        networkMonitor.onConnectionChange = { [weak self] isConnected in
            Task { @MainActor [weak self] in
                if isConnected {
                    // Auto-sync when connection is restored
                    try? await self?.syncActiveBudget()
                }
            }
        }
    }

    // MARK: - Main Sync Methods

    /// Sync active budget (pull then push) with retry logic
    func syncActiveBudget(retryCount: Int = 0) async throws {
        print("🔄 Starting sync - retryCount: \(retryCount)")

        guard networkMonitor.isConnected else {
            print("⚠️ Sync skipped - no network connection")
            syncState = .offline
            return
        }

        syncState = .syncing
        print("📡 Network connected, syncing...")

        do {
            // Get current user ID from auth
            let session = try await supabase.auth.session
            let userId = session.user.id

            print("   🔐 Auth Session Info:")
            print("      - User ID: \(userId)")
            print("      - Email: \(session.user.email ?? "N/A")")
            print("      - Access Token: \(session.accessToken.prefix(20))...")

            // Pull changes from server first
            try await pullActiveBudget(userId: userId)

            // Then push local changes
            try await pushLocalChanges(userId: userId)

            // Update sync state
            let now = Date()
            lastSyncTimestamp = now
            UserDefaults.standard.set(now, forKey: "lastSyncTimestamp")
            syncState = .success(now)

        } catch {
            // Handle different error types
            let errorMessage = handleSyncError(error)
            syncState = .error(errorMessage)

            // Retry logic for network errors
            if retryCount < maxRetries && isRetryableError(error) {
                // Exponential backoff: 2^retryCount seconds
                let delaySeconds = pow(2.0, Double(retryCount))
                try? await Task.sleep(for: .seconds(delaySeconds))

                // Retry
                try await syncActiveBudget(retryCount: retryCount + 1)
            } else {
                throw error
            }
        }
    }

    /// Check if error is retryable
    private func isRetryableError(_ error: Error) -> Bool {
        let nsError = error as NSError

        // Network timeout or connection errors
        if nsError.domain == NSURLErrorDomain {
            return [
                NSURLErrorTimedOut,
                NSURLErrorCannotConnectToHost,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorNotConnectedToInternet
            ].contains(nsError.code)
        }

        // Supabase 5xx errors (server errors)
        if let statusCode = (error as? URLError)?.errorCode {
            return statusCode >= 500 && statusCode < 600
        }

        return false
    }

    /// Handle and format sync errors
    private func handleSyncError(_ error: Error) -> String {
        let nsError = error as NSError

        // Network errors
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet:
                return "No internet connection"
            case NSURLErrorTimedOut:
                return "Request timed out"
            case NSURLErrorCannotConnectToHost:
                return "Cannot connect to server"
            default:
                return "Network error: \(nsError.localizedDescription)"
            }
        }

        // Auth errors
        if nsError.domain == "AuthError" || error.localizedDescription.contains("auth") {
            return "Authentication error. Please sign in again."
        }

        // RLS/Permission errors
        if error.localizedDescription.contains("RLS") ||
           error.localizedDescription.contains("permission") {
            return "Permission denied. Please contact support."
        }

        // Default
        return "Sync failed: \(error.localizedDescription)"
    }

    // MARK: - Pull Methods

    /// Pull active budget from Supabase with delta sync
    private func pullActiveBudget(userId: UUID) async throws {
        print("📥 Pulling from Supabase")
        print("   User ID: \(userId)")
        print("   Last sync timestamp: \(lastSyncTimestamp?.description ?? "Never synced")")

        // Fetch active budget - use delta sync only if we have a previous sync
        let budgets: [SupabaseBudget]
        if let lastSync = lastSyncTimestamp {
            // Delta sync - only fetch budgets updated since last sync
            print("   Using delta sync with timestamp: \(lastSync.iso8601String)")
            budgets = try await supabase
                .from("budgets")
                .select()
                .eq("user_id", value: userId)
                .eq("is_active", value: true)
                .gte("updated_at", value: lastSync.iso8601String)
                .execute()
                .value
        } else {
            // First sync - fetch all active budgets for this user
            print("   First sync - fetching all active budgets")
            budgets = try await supabase
                .from("budgets")
                .select()
                .eq("user_id", value: userId)
                .eq("is_active", value: true)
                .execute()
                .value
        }

        print("   Found \(budgets.count) budgets from Supabase")

        guard let activeBudget = budgets.first else {
            // No active budget on server or no changes
            print("   ⚠️ No active budget found or no changes since last sync")
            return
        }

        print("   Active budget: \(activeBudget.budgetName)")

        // Fetch categories for this budget - use delta sync only if we have a previous sync
        let categories: [SupabaseCategory]
        if let lastSync = lastSyncTimestamp {
            // Delta sync for categories
            categories = try await supabase
                .from("categories")
                .select()
                .eq("budget_id", value: activeBudget.id)
                .gte("updated_at", value: lastSync.iso8601String)
                .execute()
                .value
        } else {
            // First sync - fetch all categories for this budget
            categories = try await supabase
                .from("categories")
                .select()
                .eq("budget_id", value: activeBudget.id)
                .execute()
                .value
        }

        print("   Found \(categories.count) categories from Supabase")

        // Fetch transactions with pagination for large datasets
        let transactions = try await fetchTransactionsPaginated(
            categoryIds: categories.map { $0.id },
            lastSync: lastSyncTimestamp
        )

        print("📥 Fetched \(transactions.count) transactions from Supabase")
        if let firstTx = transactions.first {
            print("   Sample transaction: ID=\(firstTx.id), Name='\(firstTx.name)', Amount=\(firstTx.amount)")
        }

        // Save to local database
        try await saveBudgetLocally(
            budget: activeBudget,
            categories: categories,
            transactions: transactions
        )
    }

    /// Fetch transactions with pagination support
    private func fetchTransactionsPaginated(
        categoryIds: [UUID],
        lastSync: Date?
    ) async throws -> [SupabaseTransaction] {
        guard !categoryIds.isEmpty else {
            print("   ⚠️ No category IDs provided for transaction fetch")
            return []
        }

        var allTransactions: [SupabaseTransaction] = []
        var offset = 0
        let pageSize = batchSize // Use same batch size as push operations

        while true {
            let query = supabase
                .from("transactions")
                .select()
                .in("category_id", values: categoryIds)

            // Apply delta sync filter only if we have a previous sync
            let finalQuery: PostgrestFilterBuilder
            if let lastSync = lastSync {
                finalQuery = query.gte("updated_at", value: lastSync.iso8601String)
            } else {
                finalQuery = query
            }

            let transactions: [SupabaseTransaction] = try await finalQuery
                .order("updated_at")
                .range(from: offset, to: offset + pageSize - 1)
                .execute()
                .value

            if transactions.isEmpty {
                break
            }

            allTransactions.append(contentsOf: transactions)

            // If we got less than a full page, we're done
            if transactions.count < pageSize {
                break
            }

            offset += pageSize
        }

        return allTransactions
    }

    /// Save budget data to local SwiftData
    private func saveBudgetLocally(
        budget: SupabaseBudget,
        categories: [SupabaseCategory],
        transactions: [SupabaseTransaction]
    ) async throws {
        // Check if budget already exists
        let descriptor = FetchDescriptor<BudgetDataModel>(
            predicate: #Predicate { $0.budgetId == budget.id }
        )

        let existingBudgets = try modelContext.fetch(descriptor)

        let budgetModel: BudgetDataModel
        if let existing = existingBudgets.first {
            // Update existing
            existing.startDate = budget.startDate
            existing.endDate = budget.endDate
            existing.budgetType = budget.budgetType
            existing.budgetName = budget.budgetName
            existing.currencyCode = budget.currencyCode
            existing.currencyName = budget.currencyName
            existing.currencySymbol = budget.currencySymbol
            existing.isActive = budget.isActive
            existing.userId = budget.userId
            existing.lastSyncedAt = Date()
            existing.needsSync = false
            existing.updatedAt = budget.updatedAt
            budgetModel = existing
        } else {
            // Create new
            budgetModel = budget.toBudgetDataModel()
            modelContext.insert(budgetModel)
        }

        // Sync categories
        for categoryData in categories {
            let categoryDescriptor = FetchDescriptor<CategoryDataModel>(
                predicate: #Predicate { $0.categoryId == categoryData.id }
            )
            let existingCategories = try modelContext.fetch(categoryDescriptor)

            if let existing = existingCategories.first {
                // Update existing - convert from DB format to display format
                existing.name = categoryData.name
                existing.categoryGroup = categoryData.categoryGroup.toDisplayCategoryGroup  // Convert from DB format
                existing.categoryType = categoryData.categoryType
                existing.allocatedAmount = categoryData.allocatedAmount
                existing.lastSyncedAt = Date()
                existing.needsSync = false
                existing.updatedAt = categoryData.updatedAt
            } else {
                // Create new
                let categoryModel = categoryData.toCategoryDataModel()
                categoryModel.budget = budgetModel
                modelContext.insert(categoryModel)
            }
        }

        // Sync transactions
        for transactionData in transactions {
            let transactionDescriptor = FetchDescriptor<TransactionDataModel>(
                predicate: #Predicate { $0.transactionId == transactionData.id }
            )
            let existingTransactions = try modelContext.fetch(transactionDescriptor)

            if let existing = existingTransactions.first {
                // Update existing - convert from DB format to display format
                print("📝 Syncing transaction: ID=\(transactionData.id), Name='\(transactionData.name)', Amount=\(transactionData.amount)")
                existing.amount = transactionData.amount
                existing.name = transactionData.name
                existing.notes = transactionData.notes
                existing.date = transactionData.transactionDate
                existing.categoryId = transactionData.categoryId
                existing.categoryGroup = transactionData.categoryGroup.toDisplayCategoryGroup  // Convert from DB format
                existing.isRecurring = transactionData.isRecurring
                existing.recurrenceType = transactionData.recurrenceType
                existing.lastSyncedAt = Date()
                existing.needsSync = false
                existing.updatedAt = transactionData.updatedAt
            } else {
                // Create new
                print("➕ Creating new transaction: ID=\(transactionData.id), Name='\(transactionData.name)', Amount=\(transactionData.amount)")
                let transactionModel = transactionData.toTransactionDataModel()
                transactionModel.budget = budgetModel
                modelContext.insert(transactionModel)
            }
        }

        // Save context
        try modelContext.save()
    }

    // MARK: - Push Methods

    /// Push local changes to Supabase with error handling
    private func pushLocalChanges(userId: UUID) async throws {
        // Collect all errors to report at the end
        var errors: [Error] = []

        // Push budgets that need sync
        do {
            try await pushBudgets(userId: userId)
        } catch {
            print("⚠️ Failed to push budgets: \(error.localizedDescription)")
            errors.append(error)
        }

        // Push categories that need sync
        do {
            try await pushCategories()
        } catch {
            print("⚠️ Failed to push categories: \(error.localizedDescription)")
            errors.append(error)
        }

        // Push transactions that need sync
        do {
            try await pushTransactions()
        } catch {
            print("⚠️ Failed to push transactions: \(error.localizedDescription)")
            errors.append(error)
        }

        // If any errors occurred, throw the first one
        if let firstError = errors.first {
            throw firstError
        }
    }

    /// Queue changes for sync when back online
    func queueChangesForSync() {
        // All changes are automatically queued via the needsSync flag
        // This method can be used to trigger a notification or UI update
        print("📝 Changes queued for sync when connection is restored")
    }

    /// Push budgets to Supabase
    private func pushBudgets(userId: UUID) async throws {
        let descriptor = FetchDescriptor<BudgetDataModel>(
            predicate: #Predicate { budget in
                budget.needsSync == true && budget.userId == userId
            }
        )

        let budgetsToSync = try modelContext.fetch(descriptor)
        print("📤 Pushing \(budgetsToSync.count) budgets to Supabase")

        for budgetModel in budgetsToSync {
            let supabaseBudget = SupabaseBudget.from(budgetModel, userId: userId)

            // Debug: Print the data being sent
            print("   🔍 Budget to sync:")
            print("      - Budget ID: \(supabaseBudget.id)")
            print("      - User ID: \(supabaseBudget.userId)")
            print("      - Budget Name: \(supabaseBudget.budgetName)")

            // Upsert to Supabase
            try await supabase
                .from("budgets")
                .upsert(supabaseBudget)
                .execute()

            // Mark as synced
            budgetModel.lastSyncedAt = Date()
            budgetModel.needsSync = false
            print("   ✅ Budget synced successfully")
        }

        try modelContext.save()
    }

    /// Push categories to Supabase
    private func pushCategories() async throws {
        let descriptor = FetchDescriptor<CategoryDataModel>(
            predicate: #Predicate { $0.needsSync == true }
        )

        let categoriesToSync = try modelContext.fetch(descriptor)
        print("📤 Pushing \(categoriesToSync.count) categories to Supabase")

        for categoryModel in categoriesToSync {
            let supabaseCategory = SupabaseCategory.from(categoryModel)

            do {
                // Upsert to Supabase
                try await supabase
                    .from("categories")
                    .upsert(supabaseCategory)
                    .execute()

                // Mark as synced ONLY if successful
                categoryModel.lastSyncedAt = Date()
                categoryModel.needsSync = false
                print("✅ Synced category: \(categoryModel.name)")
            } catch {
                print("❌ Failed to sync category \(categoryModel.name): \(error)")
                throw error // Re-throw to stop processing
            }
        }

        try modelContext.save()
    }

    /// Push transactions to Supabase
    private func pushTransactions() async throws {
        let descriptor = FetchDescriptor<TransactionDataModel>(
            predicate: #Predicate { $0.needsSync == true }
        )

        let transactionsToSync = try modelContext.fetch(descriptor)
        print("📤 Pushing \(transactionsToSync.count) transactions to Supabase")

        // Process in batches
        for batch in transactionsToSync.chunked(into: batchSize) {
            let supabaseTransactions = batch.map { SupabaseTransaction.from($0) }

            do {
                // Batch upsert to Supabase
                try await supabase
                    .from("transactions")
                    .upsert(supabaseTransactions)
                    .execute()

                // Mark as synced ONLY if successful
                for transaction in batch {
                    transaction.lastSyncedAt = Date()
                    transaction.needsSync = false
                }
                print("✅ Synced \(batch.count) transactions")
            } catch {
                print("❌ Failed to sync transaction batch: \(error)")
                throw error // Re-throw to stop processing
            }
        }

        try modelContext.save()
    }

    // MARK: - Budget Management

    /// Deactivate current budget and delete from local
    func deactivateCurrentBudget() async throws {
        guard networkMonitor.isConnected else {
            throw NSError(domain: "SyncManager", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Cannot deactivate budget while offline"
            ])
        }

        // Get current user
        let session = try await supabase.auth.session
        let userId = session.user.id

        // Get active budget
        let descriptor = FetchDescriptor<BudgetDataModel>(
            predicate: #Predicate { budget in
                budget.isActive == true && budget.userId == userId
            }
        )

        let activeBudgets = try modelContext.fetch(descriptor)

        for budget in activeBudgets {
            // Mark as inactive on server
            let updates = ["is_active": false]
            try await supabase
                .from("budgets")
                .update(updates)
                .eq("id", value: budget.budgetId)
                .execute()

            // Delete from local
            modelContext.delete(budget)
        }

        try modelContext.save()
    }

    // MARK: - Manual Sync

    /// Force a full sync (useful for debugging or user-initiated sync)
    func forceSync() async throws {
        lastSyncTimestamp = nil
        UserDefaults.standard.removeObject(forKey: "lastSyncTimestamp")
        try await syncActiveBudget()
    }

    /// Re-mark all local data as needing sync (for recovery from failed syncs)
    func resetSyncFlags() throws {
        print("🔄 Resetting sync flags for all local data...")

        // Get all budgets
        let budgetDescriptor = FetchDescriptor<BudgetDataModel>()
        let budgets = try modelContext.fetch(budgetDescriptor)
        for budget in budgets {
            budget.needsSync = true
            budget.lastSyncedAt = nil
        }
        print("   Marked \(budgets.count) budgets for sync")

        // Get all categories
        let categoryDescriptor = FetchDescriptor<CategoryDataModel>()
        let categories = try modelContext.fetch(categoryDescriptor)
        for category in categories {
            category.needsSync = true
            category.lastSyncedAt = nil
        }
        print("   Marked \(categories.count) categories for sync")

        // Get all transactions
        let transactionDescriptor = FetchDescriptor<TransactionDataModel>()
        let transactions = try modelContext.fetch(transactionDescriptor)
        for transaction in transactions {
            transaction.needsSync = true
            transaction.lastSyncedAt = nil
        }
        print("   Marked \(transactions.count) transactions for sync")

        try modelContext.save()
        print("✅ All data marked for sync")
    }

}

// MARK: - Array Extension for Batching

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Date Extension for ISO 8601

extension Date {
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }
}

// MARK: - String Extension for Category Group Conversion

fileprivate extension String {
    /// Convert category group from database format to display format
    /// "essentials" -> "Essentials", "financialGoals" -> "Financial Goals"
    var toDisplayCategoryGroup: String {
        switch self {
        case "essentials": return "Essentials"
        case "lifestyle": return "Lifestyle"
        case "occasional": return "Occasional"
        case "financialGoals": return "Financial Goals"
        case "miscellaneous": return "Miscellaneous"
        default: return self.capitalized
        }
    }
}
