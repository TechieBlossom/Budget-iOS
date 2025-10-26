//
//  SupabaseModels.swift
//  Budget
//
//  Created for Supabase integration
//

import Foundation

// MARK: - Category Group Conversion

fileprivate extension String {
    /// Convert category group from display format to database format
    /// "Essentials" -> "essentials", "Financial Goals" -> "financialGoals"
    var toDatabaseCategoryGroup: String {
        switch self {
        case "Essentials": return "essentials"
        case "Lifestyle": return "lifestyle"
        case "Occasional": return "occasional"
        case "Financial Goals": return "financialGoals"
        case "Miscellaneous": return "miscellaneous"
        default:
            // Fallback: convert to camelCase
            let components = self.components(separatedBy: " ")
            if components.count > 1 {
                let first = components[0].lowercased()
                let rest = components.dropFirst().map { $0.capitalized }.joined()
                return first + rest
            }
            return self.lowercased()
        }
    }

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

// MARK: - Supabase Budget Model

struct SupabaseBudget: Codable, Hashable {
    let id: UUID
    let userId: UUID
    let startDate: Date
    let endDate: Date
    let budgetType: String
    let budgetName: String
    let currencyCode: String
    let currencyName: String
    let currencySymbol: String
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case startDate = "start_date"
        case endDate = "end_date"
        case budgetType = "budget_type"
        case budgetName = "budget_name"
        case currencyCode = "currency_code"
        case currencyName = "currency_name"
        case currencySymbol = "currency_symbol"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Supabase Category Model

struct SupabaseCategory: Codable {
    let id: UUID
    let budgetId: UUID
    let name: String
    let categoryGroup: String
    let categoryType: String
    let allocatedAmount: Double
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case budgetId = "budget_id"
        case name
        case categoryGroup = "category_group"
        case categoryType = "category_type"
        case allocatedAmount = "allocated_amount"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Supabase Transaction Model

struct SupabaseTransaction: Codable {
    let id: UUID
    let categoryId: UUID
    let categoryGroup: String
    let amount: Double
    let name: String  // Expense name
    let notes: String  // Optional notes/description
    let transactionDate: Date
    let isRecurring: Bool
    let recurrenceType: String
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case categoryId = "category_id"
        case categoryGroup = "category_group"
        case amount
        case name
        case notes
        case transactionDate = "transaction_date"
        case isRecurring = "is_recurring"
        case recurrenceType = "recurrence_type"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Conversion Extensions

extension SupabaseBudget {
    /// Convert to BudgetDataModel
    func toBudgetDataModel() -> BudgetDataModel {
        // Create empty data for legacy fields
        let emptyCategories = Data()
        let emptyAmounts = Data()

        let model = BudgetDataModel(
            budgetId: id,
            startDate: startDate,
            endDate: endDate,
            budgetType: budgetType,
            budgetName: budgetName,
            currencyCode: currencyCode,
            currencyName: currencyName,
            currencySymbol: currencySymbol,
            categoriesData: emptyCategories,
            categoryAmountsData: emptyAmounts,
            userId: userId,
            isActive: isActive
        )

        // Set sync metadata
        model.lastSyncedAt = Date()
        model.needsSync = false
        model.createdAt = createdAt
        model.updatedAt = updatedAt

        return model
    }

    /// Create from BudgetDataModel
    static func from(_ model: BudgetDataModel, userId: UUID) -> SupabaseBudget {
        return SupabaseBudget(
            id: model.budgetId,
            userId: userId,
            startDate: model.startDate,
            endDate: model.endDate,
            budgetType: model.budgetType,
            budgetName: model.budgetName,
            currencyCode: model.currencyCode,
            currencyName: model.currencyName,
            currencySymbol: model.currencySymbol,
            isActive: model.isActive,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }
}

extension SupabaseCategory {
    /// Convert to CategoryDataModel
    func toCategoryDataModel() -> CategoryDataModel {
        let model = CategoryDataModel(
            categoryId: id,
            budgetId: budgetId,
            name: name,
            categoryGroup: categoryGroup.toDisplayCategoryGroup, // Convert from DB format
            categoryType: categoryType,
            allocatedAmount: allocatedAmount
        )

        // Set sync metadata
        model.lastSyncedAt = Date()
        model.needsSync = false
        model.createdAt = createdAt
        model.updatedAt = updatedAt

        return model
    }

    /// Create from CategoryDataModel
    static func from(_ model: CategoryDataModel) -> SupabaseCategory {
        return SupabaseCategory(
            id: model.categoryId,
            budgetId: model.budgetId,
            name: model.name,
            categoryGroup: model.categoryGroup.toDatabaseCategoryGroup, // Convert to DB format
            categoryType: model.categoryType,
            allocatedAmount: model.allocatedAmount,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }
}

extension SupabaseTransaction {
    /// Convert to TransactionDataModel
    func toTransactionDataModel() -> TransactionDataModel {
        let model = TransactionDataModel(
            transactionId: id,
            amount: amount,
            name: name,
            notes: notes,
            date: transactionDate,
            categoryId: categoryId,
            categoryGroup: categoryGroup.toDisplayCategoryGroup, // Convert from DB format
            isRecurring: isRecurring,
            recurrenceType: recurrenceType
        )

        // Set sync metadata
        model.lastSyncedAt = Date()
        model.needsSync = false
        model.createdAt = createdAt
        model.updatedAt = updatedAt

        return model
    }

    /// Create from TransactionDataModel
    static func from(_ model: TransactionDataModel) -> SupabaseTransaction {
        return SupabaseTransaction(
            id: model.transactionId,
            categoryId: model.categoryId,
            categoryGroup: model.categoryGroup.toDatabaseCategoryGroup, // Convert to DB format
            amount: model.amount,
            name: model.name,
            notes: model.notes,
            transactionDate: model.date,
            isRecurring: model.isRecurring,
            recurrenceType: model.recurrenceType,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }
}
