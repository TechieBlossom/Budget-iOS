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
    
    // Relationship to budget
    var budget: BudgetDataModel?
    
    init(transactionId: UUID, amount: Double, notes: String, date: Date, categoryId: UUID) {
        self.transactionId = transactionId
        self.amount = amount
        self.notes = notes
        self.date = date
        self.categoryId = categoryId
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
        return Transaction(
            id: transactionId,
            amount: amount,
            notes: notes,
            date: date,
            categoryId: categoryId
        )
    }
    
    static func from(_ transaction: Transaction) -> TransactionDataModel {
        return TransactionDataModel(
            transactionId: transaction.id,
            amount: transaction.amount,
            notes: transaction.notes,
            date: transaction.date,
            categoryId: transaction.categoryId
        )
    }
}

// MARK: - Helper struct for encoding/decoding categories

struct CategoryData: Codable {
    let id: UUID
    let name: String
    let colorHex: String
    let isDefault: Bool
    
    init(from category: Category) {
        self.id = category.id
        self.name = category.name
        self.colorHex = category.color.hex
        self.isDefault = category.isDefault
    }
    
    func toCategory() -> Category {
        let color = CategoryColor.allCases.first { $0.hex == colorHex } ?? .color1
        return Category(id: id, name: name, color: color, isDefault: isDefault)
    }
}