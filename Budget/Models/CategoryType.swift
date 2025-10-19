import Foundation

enum CategoryType: String, Codable, CaseIterable {
    case expense = "expense"
    case savings = "savings"

    var displayName: String {
        switch self {
        case .expense:
            return "Expense"
        case .savings:
            return "Savings"
        }
    }
}
