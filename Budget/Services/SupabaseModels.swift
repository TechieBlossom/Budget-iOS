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
        case "Debt & Obligations": return "debtObligations"
        case "Business Expenses": return "businessExpenses"
        case "Family & Dependents": return "familyDependents"
        case "Home & Property": return "homeProperty"
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
        case "debtObligations": return "Debt & Obligations"
        case "businessExpenses": return "Business Expenses"
        case "familyDependents": return "Family & Dependents"
        case "homeProperty": return "Home & Property"
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
    let budgetId: UUID
    let categoryId: UUID
    let categoryGroup: String
    let amount: Double
    let name: String  // Expense name
    let notes: String  // Optional notes/description
    let transactionDate: Date
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case budgetId = "budget_id"
        case categoryId = "category_id"
        case categoryGroup = "category_group"
        case amount
        case name
        case notes
        case transactionDate = "transaction_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Conversion Extensions

extension SupabaseBudget {
    /// Convert to domain Budget model with categories
    func toBudget(categories: [SupabaseCategory]) -> Budget {
        let subcategories = categories.map { category in
            let group = CategoryGroup(rawValue: category.categoryGroup.toDisplayCategoryGroup) ?? .miscellaneous
            let type = CategoryType(rawValue: category.categoryType) ?? .expense
            return SubCategory(
                id: category.id,
                name: category.name,
                categoryGroup: group,
                categoryType: type
            )
        }

        let categoryAmounts = Dictionary(
            uniqueKeysWithValues: categories.map { ($0.id.uuidString, $0.allocatedAmount) }
        )

        let currency = Currency(code: currencyCode, name: currencyName, symbol: currencySymbol)
        let type = BudgetType(rawValue: budgetType) ?? .monthly
        let period = BudgetPeriod(type: type, startDate: startDate, endDate: endDate, customName: budgetName)

        return Budget(
            id: id,
            period: period,
            currency: currency,
            categories: subcategories,
            categoryAmounts: categoryAmounts
        )
    }

    /// Convert to BudgetDataModel (for local cache)
    func toBudgetDataModel() -> BudgetDataModel {
        let model = BudgetDataModel(
            budgetId: id,
            userId: userId,
            isActive: isActive,
            startDate: startDate,
            endDate: endDate,
            budgetType: budgetType,
            budgetName: budgetName,
            currencyCode: currencyCode,
            currencyName: currencyName,
            currencySymbol: currencySymbol
        )

        model.createdAt = createdAt
        model.updatedAt = updatedAt

        return model
    }

    /// Create from domain Budget model
    static func from(_ budget: Budget, userId: UUID) -> SupabaseBudget {
        return SupabaseBudget(
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
    }
}

extension SupabaseCategory {
    /// Convert to CategoryDataModel (for local cache)
    func toCategoryDataModel() -> CategoryDataModel {
        let model = CategoryDataModel(
            categoryId: id,
            budgetId: budgetId,
            name: name,
            categoryGroup: categoryGroup.toDisplayCategoryGroup,
            categoryType: categoryType,
            allocatedAmount: allocatedAmount
        )

        model.createdAt = createdAt
        model.updatedAt = updatedAt

        return model
    }

    /// Convert to domain model SubCategory
    func toSubCategory() -> SubCategory {
        let group = CategoryGroup(rawValue: categoryGroup.toDisplayCategoryGroup) ?? .miscellaneous
        let type = CategoryType(rawValue: categoryType) ?? .expense
        return SubCategory(
            id: id,
            name: name,
            categoryGroup: group,
            categoryType: type
        )
    }

    /// Create from SubCategory with budget context
    static func from(_ subCategory: SubCategory, budgetId: UUID, amount: Double) -> SupabaseCategory {
        return SupabaseCategory(
            id: subCategory.id,
            budgetId: budgetId,
            name: subCategory.name,
            categoryGroup: subCategory.categoryGroup.rawValue.toDatabaseCategoryGroup,
            categoryType: subCategory.categoryType.rawValue,
            allocatedAmount: amount,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

extension SupabaseTransaction {
    /// Convert to TransactionDataModel (for local cache)
    func toTransactionDataModel() -> TransactionDataModel {
        let model = TransactionDataModel(
            transactionId: id,
            budgetId: budgetId,
            categoryId: categoryId,
            categoryGroup: categoryGroup.toDisplayCategoryGroup,
            amount: amount,
            name: name,
            notes: notes,
            date: transactionDate
        )

        model.createdAt = createdAt
        model.updatedAt = updatedAt

        return model
    }

    /// Convert to domain model Transaction
    func toTransaction() -> Transaction {
        return Transaction(
            id: id,
            amount: amount,
            name: name,
            notes: notes,
            date: transactionDate,
            categoryId: categoryId,
            budgetId: budgetId
        )
    }

    /// Create from domain Transaction with category group
    static func from(_ transaction: Transaction, categoryGroup: String) -> SupabaseTransaction {
        return SupabaseTransaction(
            id: transaction.id,
            budgetId: transaction.budgetId,
            categoryId: transaction.categoryId,
            categoryGroup: categoryGroup.toDatabaseCategoryGroup,
            amount: transaction.amount,
            name: transaction.name,
            notes: transaction.notes,
            transactionDate: transaction.date,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
