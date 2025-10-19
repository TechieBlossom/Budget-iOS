import Foundation
import UIKit

// MARK: - Export Data Model

struct BudgetExportData: Codable {
    let version: String
    let exportDate: Date
    let budgets: [ExportableBudget]
    let transactions: [ExportableTransaction]
    
    init(budgets: [Budget], transactions: [Transaction]) {
        self.version = "1.0"
        self.exportDate = Date()
        self.budgets = budgets.map { ExportableBudget(from: $0) }
        self.transactions = transactions.map { ExportableTransaction(from: $0) }
    }
}

struct ExportableBudget: Codable, Identifiable {
    let id: String
    let budgetName: String
    let totalAmount: Double
    let currency: ExportableCurrency
    let period: ExportableBudgetPeriod
    let categories: [ExportableCategory]
    let categoryAmounts: [String: Double]
    
    init(from budget: Budget) {
        self.id = budget.id.uuidString
        self.budgetName = budget.budgetName
        self.totalAmount = budget.totalAmount
        self.currency = ExportableCurrency(from: budget.currency)
        self.period = ExportableBudgetPeriod(from: budget.period)
        self.categories = budget.categories.map { ExportableCategory(from: $0) }
        self.categoryAmounts = budget.categoryAmounts
    }

    func toBudget() -> Budget {
        let budgetId = UUID(uuidString: id) ?? UUID()
        let budgetCurrency = currency.toCurrency()
        let budgetPeriod = period.toBudgetPeriod()
        let budgetCategories = categories.map { $0.toSubCategory() }

        return Budget(
            id: budgetId,
            period: budgetPeriod,
            currency: budgetCurrency,
            categories: budgetCategories,
            categoryAmounts: categoryAmounts
        )
    }
}

struct ExportableTransaction: Codable, Identifiable {
    let id: String
    let amount: Double
    let notes: String
    let date: Date
    let categoryId: String
    
    init(from transaction: Transaction) {
        self.id = transaction.id.uuidString
        self.amount = transaction.amount
        self.notes = transaction.notes
        self.date = transaction.date
        self.categoryId = transaction.categoryId.uuidString
    }
    
    func toTransaction() -> Transaction {
        let transactionId = UUID(uuidString: id) ?? UUID()
        let transactionCategoryId = UUID(uuidString: categoryId) ?? UUID()
        
        return Transaction(
            id: transactionId,
            amount: amount,
            notes: notes,
            date: date,
            categoryId: transactionCategoryId
        )
    }
}

struct ExportableCurrency: Codable {
    let code: String
    let name: String
    let symbol: String
    
    init(from currency: Currency) {
        self.code = currency.code
        self.name = currency.name
        self.symbol = currency.symbol
    }
    
    func toCurrency() -> Currency {
        return Currency(code: code, name: name, symbol: symbol)
    }
}

struct ExportableBudgetPeriod: Codable {
    let startDate: Date
    let endDate: Date
    let name: String
    let type: ExportableBudgetType
    let wasAutoShifted: Bool
    
    init(from period: BudgetPeriod) {
        self.startDate = period.startDate
        self.endDate = period.endDate
        self.name = period.name
        self.type = ExportableBudgetType(from: period.type)
        self.wasAutoShifted = period.wasAutoShifted
    }
    
    func toBudgetPeriod() -> BudgetPeriod {
        // Use the legacy initializer to reconstruct the period
        return BudgetPeriod(startDate: startDate, endDate: endDate)
    }
}

struct ExportableBudgetType: Codable {
    let rawValue: String
    
    init(from type: BudgetType) {
        switch type {
        case .monthly:
            self.rawValue = "monthly"
        case .custom:
            self.rawValue = "custom"
        }
    }
    
    func toBudgetType() -> BudgetType {
        switch rawValue {
        case "monthly":
            return .monthly
        case "custom":
            return .custom
        default:
            return .monthly
        }
    }
}

// MARK: - Legacy Category Model (V1 - Flat Structure)

struct ExportableCategoryV1: Codable {
    let id: String
    let name: String
    let color: CategoryColor?
    let isDefault: Bool?

    struct CategoryColor: Codable {
        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double
    }

    // Map category name to appropriate CategoryGroup
    func mapToGroup() -> CategoryGroup {
        let categoryName = name.lowercased()

        // Essentials
        if ["housing", "rent", "utilities", "utility", "groceries",
            "transportation", "healthcare", "insurance"].contains(categoryName) {
            return .essentials
        }

        // Lifestyle
        if ["food & dining", "food and dining", "entertainment",
            "shopping", "fitness", "personal care", "salon"].contains(categoryName) {
            return .lifestyle
        }

        // Occasional
        if ["vacation", "education", "subscriptions", "clothing"].contains(categoryName) {
            return .occasional
        }

        // Financial Goals
        if ["savings", "investments", "investment", "retirement",
            "india transfer"].contains(categoryName) {
            return .financialGoals
        }

        // Default to miscellaneous
        return .miscellaneous
    }

    func toSubCategory() -> SubCategory {
        let categoryId = UUID(uuidString: id) ?? UUID()
        let group = mapToGroup()
        // Migration: default based on category group
        let type: CategoryType = group == .financialGoals ? .savings : .expense

        return SubCategory(
            id: categoryId,
            name: name,
            categoryGroup: group,
            categoryType: type
        )
    }
}

// MARK: - Current Category Model (V2 - Hierarchical Structure)

struct ExportableCategory: Codable, Identifiable {
    let id: String
    let name: String
    let categoryGroup: String?  // Optional for backward compatibility
    let categoryType: String?  // Optional for backward compatibility
    let isDefault: Bool?  // Made optional for backward compatibility

    // Legacy fields for V1 compatibility
    let color: CategoryColor?

    struct CategoryColor: Codable {
        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double
    }

    init(from subCategory: SubCategory) {
        self.id = subCategory.id.uuidString
        self.name = subCategory.name
        self.categoryGroup = subCategory.categoryGroup.rawValue
        self.categoryType = subCategory.categoryType.rawValue
        self.isDefault = nil  // No longer used
        self.color = nil  // No longer used
    }

    // Custom decoder to handle both old and new formats
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)

        // Try to decode categoryGroup (new format)
        categoryGroup = try? container.decode(String.self, forKey: .categoryGroup)

        // Try to decode categoryType (newest format)
        categoryType = try? container.decode(String.self, forKey: .categoryType)

        // Try to decode legacy fields (old format)
        isDefault = try? container.decode(Bool.self, forKey: .isDefault)
        color = try? container.decode(CategoryColor.self, forKey: .color)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, categoryGroup, categoryType, isDefault, color
    }

    // Custom encoder to only encode relevant fields
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        if let categoryGroup = categoryGroup {
            try container.encode(categoryGroup, forKey: .categoryGroup)
        }
        if let categoryType = categoryType {
            try container.encode(categoryType, forKey: .categoryType)
        }
        // Don't encode legacy fields (isDefault, color) in new exports
    }

    func toSubCategory() -> SubCategory {
        let categoryId = UUID(uuidString: id) ?? UUID()

        // Determine category group
        let group: CategoryGroup
        if let groupString = categoryGroup,
           let parsedGroup = CategoryGroup(rawValue: groupString) {
            group = parsedGroup
        } else {
            // Migrate from old format by mapping name to group
            group = mapCategoryNameToGroup(name)
        }

        // Determine category type
        let type: CategoryType
        if let typeString = categoryType,
           let parsedType = CategoryType(rawValue: typeString) {
            type = parsedType
        } else {
            // Migration: default based on category group
            type = group == .financialGoals ? .savings : .expense
        }

        return SubCategory(
            id: categoryId,
            name: name,
            categoryGroup: group,
            categoryType: type
        )
    }

    // Map legacy category name to appropriate CategoryGroup
    private func mapCategoryNameToGroup(_ categoryName: String) -> CategoryGroup {
        let lowercaseName = categoryName.lowercased()

        // Essentials
        if ["housing", "rent", "utilities", "utility", "groceries",
            "transportation", "healthcare", "insurance"].contains(lowercaseName) {
            return .essentials
        }

        // Lifestyle
        if ["food & dining", "food and dining", "entertainment",
            "shopping", "fitness", "personal care", "salon"].contains(lowercaseName) {
            return .lifestyle
        }

        // Occasional
        if ["vacation", "education", "subscriptions", "clothing"].contains(lowercaseName) {
            return .occasional
        }

        // Financial Goals
        if ["savings", "investments", "investment", "retirement",
            "india transfer"].contains(lowercaseName) {
            return .financialGoals
        }

        // Default to miscellaneous
        return .miscellaneous
    }
}

// MARK: - Import/Export Manager

@MainActor
class ImportExportManager: ObservableObject {
    
    func exportBudgetData(budgets: [Budget], transactions: [Transaction]) -> Data? {
        let exportData = BudgetExportData(budgets: budgets, transactions: transactions)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        return try? encoder.encode(exportData)
    }
    
    func importBudgetData(from data: Data) -> (budgets: [Budget], transactions: [Transaction])? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let exportData = try? decoder.decode(BudgetExportData.self, from: data) else {
            return nil
        }
        
        let budgets = exportData.budgets.map { $0.toBudget() }
        let transactions = exportData.transactions.map { $0.toTransaction() }
        
        return (budgets: budgets, transactions: transactions)
    }
    
    func generateFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return "Budget_Export_\(formatter.string(from: Date())).budget"
    }
}