import Foundation
import SwiftData

@Model
final class BudgetDataModel {
    @Attribute(.unique) var budgetId: UUID
    var startDate: Date
    var endDate: Date
    var budgetType: String  // Store as String for persistence
    var budgetName: String  // Store custom budget names
    var currencyCode: String
    var currencyName: String
    var currencySymbol: String

    // Sync metadata - NEW for Supabase integration
    var userId: UUID?  // Link to authenticated user
    var isActive: Bool  // Only one active budget per user
    var lastSyncedAt: Date?  // Track last successful sync
    var needsSync: Bool  // Dirty flag for pending changes
    var createdAt: Date  // Track creation timestamp
    var updatedAt: Date  // Track last update timestamp

    // Store complex data as encoded JSON (DEPRECATED - will migrate to CategoryDataModel)
    @Attribute(.externalStorage) var categoriesData: Data
    @Attribute(.externalStorage) var categoryAmountsData: Data

    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \TransactionDataModel.budget)
    var transactions: [TransactionDataModel] = []

    @Relationship(deleteRule: .cascade, inverse: \CategoryDataModel.budget)
    var categories: [CategoryDataModel] = []

    init(budgetId: UUID, startDate: Date, endDate: Date, budgetType: String, budgetName: String, currencyCode: String, currencyName: String, currencySymbol: String, categoriesData: Data, categoryAmountsData: Data, userId: UUID? = nil, isActive: Bool = true) {
        self.budgetId = budgetId
        self.startDate = startDate
        self.endDate = endDate
        self.budgetType = budgetType
        self.budgetName = budgetName
        self.currencyCode = currencyCode
        self.currencyName = currencyName
        self.currencySymbol = currencySymbol
        self.categoriesData = categoriesData
        self.categoryAmountsData = categoryAmountsData

        // Initialize sync metadata
        self.userId = userId
        self.isActive = isActive
        self.lastSyncedAt = nil
        self.needsSync = true
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

@Model
final class TransactionDataModel {
    @Attribute(.unique) var transactionId: UUID
    var amount: Double
    var name: String  // Expense name
    var notes: String  // Optional notes/description
    var date: Date
    var categoryId: UUID
    var isRecurring: Bool
    var recurrenceType: String

    // Sync metadata - NEW for Supabase integration
    var categoryGroup: String  // Denormalized for query performance
    var lastSyncedAt: Date?  // Track last successful sync
    var needsSync: Bool  // Dirty flag for pending changes
    var createdAt: Date  // Track creation timestamp
    var updatedAt: Date  // Track last update timestamp

    // Relationship to budget
    var budget: BudgetDataModel?

    init(transactionId: UUID, amount: Double, name: String = "", notes: String = "", date: Date, categoryId: UUID, categoryGroup: String = "miscellaneous", isRecurring: Bool = false, recurrenceType: String = "None") {
        self.transactionId = transactionId
        self.amount = amount
        self.name = name
        self.notes = notes
        self.date = date
        self.categoryId = categoryId
        self.isRecurring = isRecurring
        self.recurrenceType = recurrenceType

        // Initialize sync metadata
        self.categoryGroup = categoryGroup
        self.lastSyncedAt = nil
        self.needsSync = true
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Extensions for converting between domain models and data models

extension BudgetDataModel {
    func toBudget() -> Budget? {
        // Try to load from CategoryDataModel relationship first
        if !categories.isEmpty {
            // New path: Load from CategoryDataModel relationship
            let subcategories = categories.map { $0.toSubCategory() }
            let categoryAmounts = Dictionary(
                uniqueKeysWithValues: categories.map { ($0.categoryId.uuidString, $0.allocatedAmount) }
            )

            let currency = Currency(code: currencyCode, name: currencyName, symbol: currencySymbol)
            let type = BudgetType(rawValue: budgetType) ?? .monthly
            let period = BudgetPeriod(type: type, startDate: startDate, endDate: endDate, customName: budgetName)

            return Budget(
                id: budgetId,
                period: period,
                currency: currency,
                categories: subcategories,
                categoryAmounts: categoryAmounts
            )
        } else {
            // Legacy path: Try loading from JSON-encoded data for backward compatibility
            do {
                let categories = try JSONDecoder().decode([CategoryData].self, from: categoriesData).map { $0.toCategory() }
                let categoryAmounts = try JSONDecoder().decode([String: Double].self, from: categoryAmountsData)

                let currency = Currency(code: currencyCode, name: currencyName, symbol: currencySymbol)
                let type = BudgetType(rawValue: budgetType) ?? .monthly
                let period = BudgetPeriod(type: type, startDate: startDate, endDate: endDate, customName: budgetName)

                return Budget(
                    id: budgetId,
                    period: period,
                    currency: currency,
                    categories: categories,
                    categoryAmounts: categoryAmounts
                )
            } catch {
                print("Failed to convert BudgetDataModel to Budget (legacy): \(error)")
                return nil
            }
        }
    }
    
    static func from(_ budget: Budget) throws -> BudgetDataModel {
        let categoriesData = try JSONEncoder().encode(budget.categories.map { CategoryData(from: $0) })
        let categoryAmountsData = try JSONEncoder().encode(budget.categoryAmounts)
        
        return BudgetDataModel(
            budgetId: budget.id,
            startDate: budget.period.startDate,
            endDate: budget.period.endDate,
            budgetType: budget.period.type.rawValue,
            budgetName: budget.period.name,
            currencyCode: budget.currency.code,
            currencyName: budget.currency.name,
            currencySymbol: budget.currency.symbol,
            categoriesData: categoriesData,
            categoryAmountsData: categoryAmountsData
        )
    }
}

extension TransactionDataModel {
    func toTransaction() -> Transaction {
        let recurrence = RecurrenceType(rawValue: recurrenceType) ?? .none
        return Transaction(
            id: transactionId,
            amount: amount,
            name: name,
            notes: notes,
            date: date,
            categoryId: categoryId,
            isRecurring: isRecurring,
            recurrenceType: recurrence
        )
    }

    static func from(_ transaction: Transaction, categoryGroup: String? = nil) -> TransactionDataModel {
        return TransactionDataModel(
            transactionId: transaction.id,
            amount: transaction.amount,
            name: transaction.name,
            notes: transaction.notes,
            date: transaction.date,
            categoryId: transaction.categoryId,
            categoryGroup: categoryGroup ?? "Miscellaneous",  // Use provided or default to Miscellaneous
            isRecurring: transaction.isRecurring,
            recurrenceType: transaction.recurrenceType.rawValue
        )
    }
}

// MARK: - Helper struct for encoding/decoding categories

struct CategoryData: Codable {
    let id: UUID
    let name: String
    let categoryGroup: String  // Store group as string
    // Legacy fields for backward compatibility
    let isDefault: Bool?  // Made optional for backward compatibility
    let colorHex: String?
    let type: String?

    init(from subCategory: SubCategory) {
        self.id = subCategory.id
        self.name = subCategory.name
        self.categoryGroup = subCategory.categoryGroup.rawValue
        self.isDefault = nil  // No longer used
        self.colorHex = nil  // No longer used
        self.type = nil  // No longer used
    }

    func toCategory() -> SubCategory {
        let group = CategoryGroup(rawValue: categoryGroup) ?? .miscellaneous
        return SubCategory(id: id, name: name, categoryGroup: group)
    }
}