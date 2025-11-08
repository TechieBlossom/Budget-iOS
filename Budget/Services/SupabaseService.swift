//
//  SupabaseService.swift
//  Budget
//
//  Direct Supabase operations - Single source of truth
//

import Foundation
import Supabase

@MainActor
class SupabaseService {
    private let supabase = SupabaseClientManager.shared.client

    // MARK: - Budget Operations

    /// Create a new budget
    func createBudget(_ budget: Budget, userId: UUID) async throws -> SupabaseBudget {
        let supabaseBudget = SupabaseBudget(
            id: budget.id,
            userId: userId,
            startDate: budget.period.startDate,
            endDate: budget.period.endDate,
            budgetType: budget.period.type.rawValue,
            budgetName: budget.period.name,
            currencyCode: budget.currency.code,
            currencyName: budget.currency.name,
            currencySymbol: budget.currency.symbol,
            isActive: true,
            createdAt: Date(),
            updatedAt: Date()
        )

        try await supabase
            .from("budgets")
            .insert(supabaseBudget)
            .execute()

        return supabaseBudget
    }

    /// Update an existing budget
    func updateBudget(_ budget: Budget, userId: UUID) async throws -> SupabaseBudget {
        let supabaseBudget = SupabaseBudget(
            id: budget.id,
            userId: userId,
            startDate: budget.period.startDate,
            endDate: budget.period.endDate,
            budgetType: budget.period.type.rawValue,
            budgetName: budget.period.name,
            currencyCode: budget.currency.code,
            currencyName: budget.currency.name,
            currencySymbol: budget.currency.symbol,
            isActive: true,
            createdAt: Date(), // Will be overwritten by server
            updatedAt: Date()
        )

        try await supabase
            .from("budgets")
            .update(supabaseBudget)
            .eq("id", value: budget.id)
            .execute()

        return supabaseBudget
    }

    /// Fetch active budget for a user
    func fetchActiveBudget(userId: UUID) async throws -> SupabaseBudget? {
        let budgets: [SupabaseBudget] = try await supabase
            .from("budgets")
            .select()
            .eq("user_id", value: userId)
            .eq("is_active", value: true)
            .execute()
            .value

        return budgets.first
    }

    /// Deactivate a budget
    func deactivateBudget(_ budgetId: UUID) async throws {
        struct BudgetUpdate: Encodable {
            let is_active: Bool
            let updated_at: String
        }

        let updates = BudgetUpdate(
            is_active: false,
            updated_at: Date().iso8601String
        )

        try await supabase
            .from("budgets")
            .update(updates)
            .eq("id", value: budgetId)
            .execute()
    }

    // MARK: - Category Operations

    /// Create a new category
    func createCategory(_ category: SupabaseCategory) async throws -> SupabaseCategory {
        let response: [SupabaseCategory] = try await supabase
            .from("categories")
            .insert(category)
            .select()
            .execute()
            .value

        // Return the created category from Supabase (includes server-generated fields)
        guard let createdCategory = response.first else {
            throw NSError(domain: "SupabaseService", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to get created category from Supabase"
            ])
        }

        return createdCategory
    }

    /// Update an existing category
    func updateCategory(_ category: SupabaseCategory) async throws -> SupabaseCategory {
        try await supabase
            .from("categories")
            .update(category)
            .eq("id", value: category.id)
            .execute()

        return category
    }

    /// Delete a category
    func deleteCategory(_ categoryId: UUID) async throws {
        try await supabase
            .from("categories")
            .delete()
            .eq("id", value: categoryId)
            .execute()
    }

    /// Fetch all categories for a budget
    func fetchCategories(budgetId: UUID) async throws -> [SupabaseCategory] {
        let categories: [SupabaseCategory] = try await supabase
            .from("categories")
            .select()
            .eq("budget_id", value: budgetId)
            .execute()
            .value

        return categories
    }

    // MARK: - Transaction Operations

    /// Create a new transaction
    func createTransaction(_ transaction: SupabaseTransaction) async throws -> SupabaseTransaction {
        try await supabase
            .from("transactions")
            .insert(transaction)
            .execute()

        return transaction
    }

    /// Update an existing transaction
    func updateTransaction(_ transaction: SupabaseTransaction) async throws -> SupabaseTransaction {
        try await supabase
            .from("transactions")
            .update(transaction)
            .eq("id", value: transaction.id)
            .execute()

        return transaction
    }

    /// Delete a transaction
    func deleteTransaction(_ transactionId: UUID) async throws {
        try await supabase
            .from("transactions")
            .delete()
            .eq("id", value: transactionId)
            .execute()
    }

    /// Fetch all transactions for specific categories
    func fetchTransactions(categoryIds: [UUID]) async throws -> [SupabaseTransaction] {
        guard !categoryIds.isEmpty else { return [] }

        let transactions: [SupabaseTransaction] = try await supabase
            .from("transactions")
            .select()
            .in("category_id", values: categoryIds)
            .execute()
            .value

        return transactions
    }

    /// Fetch all transactions for a budget
    func fetchTransactions(budgetId: UUID) async throws -> [SupabaseTransaction] {
        let transactions: [SupabaseTransaction] = try await supabase
            .from("transactions")
            .select()
            .eq("budget_id", value: budgetId)
            .execute()
            .value

        return transactions
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
