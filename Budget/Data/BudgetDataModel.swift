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
    
    // Store complex data as encoded JSON
    @Attribute(.externalStorage) var categoriesData: Data
    @Attribute(.externalStorage) var categoryAmountsData: Data
    
    // Relationship to transactions
    @Relationship(deleteRule: .cascade, inverse: \TransactionDataModel.budget)
    var transactions: [TransactionDataModel] = []
    
    init(budgetId: UUID, startDate: Date, endDate: Date, budgetType: String, budgetName: String, currencyCode: String, currencyName: String, currencySymbol: String, categoriesData: Data, categoryAmountsData: Data) {
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
    }
}

@Model
final class TransactionDataModel {
    @Attribute(.unique) var transactionId: UUID
    var amount: Double
    var notes: String
    var date: Date
    var categoryId: UUID
    var isRecurring: Bool
    var recurrenceType: String

    // Relationship to budget
    var budget: BudgetDataModel?

    init(transactionId: UUID, amount: Double, notes: String, date: Date, categoryId: UUID, isRecurring: Bool = false, recurrenceType: String = "None") {
        self.transactionId = transactionId
        self.amount = amount
        self.notes = notes
        self.date = date
        self.categoryId = categoryId
        self.isRecurring = isRecurring
        self.recurrenceType = recurrenceType
    }
}

// MARK: - Extensions for converting between domain models and data models

extension BudgetDataModel {
    func toBudget() -> Budget? {
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
            print("Failed to convert BudgetDataModel to Budget: \(error)")
            return nil
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
            notes: notes,
            date: date,
            categoryId: categoryId,
            isRecurring: isRecurring,
            recurrenceType: recurrence
        )
    }

    static func from(_ transaction: Transaction) -> TransactionDataModel {
        return TransactionDataModel(
            transactionId: transaction.id,
            amount: transaction.amount,
            notes: transaction.notes,
            date: transaction.date,
            categoryId: transaction.categoryId,
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