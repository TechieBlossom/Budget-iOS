import Foundation
import SwiftData

@Model
final class BudgetDataModel {
    @Attribute(.unique) var budgetId: UUID
    var userId: UUID?
    var isActive: Bool
    var startDate: Date
    var endDate: Date
    var budgetType: String
    var budgetName: String
    var currencyCode: String
    var currencyName: String
    var currencySymbol: String
    var createdAt: Date
    var updatedAt: Date

    // Relationships
    @Relationship(deleteRule: .cascade) var categories: [CategoryDataModel]
    @Relationship(deleteRule: .cascade) var transactions: [TransactionDataModel]

    init(budgetId: UUID, userId: UUID? = nil, isActive: Bool = true, startDate: Date, endDate: Date, budgetType: String, budgetName: String, currencyCode: String, currencyName: String, currencySymbol: String) {
        self.budgetId = budgetId
        self.userId = userId
        self.isActive = isActive
        self.startDate = startDate
        self.endDate = endDate
        self.budgetType = budgetType
        self.budgetName = budgetName
        self.currencyCode = currencyCode
        self.currencyName = currencyName
        self.currencySymbol = currencySymbol
        self.createdAt = Date()
        self.updatedAt = Date()
        self.categories = []
        self.transactions = []
    }
}

@Model
final class TransactionDataModel {
    @Attribute(.unique) var transactionId: UUID
    var budgetId: UUID
    var categoryId: UUID
    var categoryGroup: String
    var amount: Double
    var name: String
    var notes: String
    var date: Date
    var createdAt: Date
    var updatedAt: Date

    var budget: BudgetDataModel?

    init(transactionId: UUID, budgetId: UUID, categoryId: UUID, categoryGroup: String = "Miscellaneous", amount: Double, name: String = "", notes: String = "", date: Date) {
        self.transactionId = transactionId
        self.budgetId = budgetId
        self.categoryId = categoryId
        self.categoryGroup = categoryGroup
        self.amount = amount
        self.name = name
        self.notes = notes
        self.date = date
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Extensions for converting between domain models and data models

extension BudgetDataModel {
    func toBudget() -> Budget? {
        // Load from CategoryDataModel relationship
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
    }

    static func from(_ budget: Budget, userId: UUID?) -> BudgetDataModel {
        return BudgetDataModel(
            budgetId: budget.id,
            userId: userId,
            isActive: true,
            startDate: budget.period.startDate,
            endDate: budget.period.endDate,
            budgetType: budget.period.type.rawValue,
            budgetName: budget.period.name,
            currencyCode: budget.currency.code,
            currencyName: budget.currency.name,
            currencySymbol: budget.currency.symbol
        )
    }
}

extension TransactionDataModel {
    func toTransaction() -> Transaction {
        return Transaction(
            id: transactionId,
            amount: amount,
            name: name,
            notes: notes,
            date: date,
            categoryId: categoryId,
            budgetId: budgetId
        )
    }

    static func from(_ transaction: Transaction, categoryGroup: String) -> TransactionDataModel {
        return TransactionDataModel(
            transactionId: transaction.id,
            budgetId: transaction.budgetId,
            categoryId: transaction.categoryId,
            categoryGroup: categoryGroup,
            amount: transaction.amount,
            name: transaction.name,
            notes: transaction.notes,
            date: transaction.date
        )
    }
}