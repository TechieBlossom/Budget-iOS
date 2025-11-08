import Foundation
import SwiftUI

enum CategoryGroup: String, Codable, CaseIterable, Identifiable {
    case essentials = "Essentials"
    case lifestyle = "Lifestyle"
    case occasional = "Occasional"
    case financialGoals = "Financial Goals"
    case debtObligations = "Debt & Obligations"
    case businessExpenses = "Business Expenses"
    case familyDependents = "Family & Dependents"
    case homeProperty = "Home & Property"
    case miscellaneous = "Miscellaneous"

    var id: String { rawValue }

    var displayName: String {
        rawValue
    }

    var color: Color {
        switch self {
        case .essentials:
            return Color(hex: "#FF6B6B")  // Red
        case .lifestyle:
            return Color(hex: "#DDA0DD")  // Purple
        case .occasional:
            return Color(hex: "#45B7D1")  // Blue
        case .financialGoals:
            return Color(hex: "#96CEB4")  // Green
        case .debtObligations:
            return Color(hex: "#FF8C42")  // Orange
        case .businessExpenses:
            return Color(hex: "#6C5CE7")  // Indigo
        case .familyDependents:
            return Color(hex: "#FD79A8")  // Pink
        case .homeProperty:
            return Color(hex: "#00B894")  // Teal
        case .miscellaneous:
            return Color(hex: "#F7DC6F")  // Yellow
        }
    }

    var description: String {
        switch self {
        case .essentials:
            return "Essential living expenses like rent, utilities, and groceries"
        case .lifestyle:
            return "Personal and leisure spending like dining and entertainment"
        case .occasional:
            return "Infrequent planned expenses like vacation and education"
        case .financialGoals:
            return "Savings, investments, and retirement contributions"
        case .debtObligations:
            return "Debt payments, loans, credit cards, and financial obligations"
        case .businessExpenses:
            return "Work-related expenses and business costs"
        case .familyDependents:
            return "Family care, childcare, education, and dependent expenses"
        case .homeProperty:
            return "Mortgage, property maintenance, and home-related costs"
        case .miscellaneous:
            return "Other miscellaneous expenses"
        }
    }

    // Default sub-categories for each group
    static func defaultSubCategories(for group: CategoryGroup) -> [String] {
        switch group {
        case .essentials:
            return ["Rent", "Utilities", "Groceries", "Transportation", "Insurance", "Healthcare"]
        case .lifestyle:
            return ["Food & Dining", "Entertainment", "Shopping", "Fitness", "Personal Care"]
        case .occasional:
            return ["Vacation", "Education", "Subscriptions"]
        case .financialGoals:
            return ["Savings", "Investments", "Retirement"]
        case .debtObligations:
            return []  // Empty - user adds as needed
        case .businessExpenses:
            return []  // Empty - user adds as needed
        case .familyDependents:
            return []  // Empty - user adds as needed
        case .homeProperty:
            return []  // Empty - user adds as needed
        case .miscellaneous:
            return ["Others"]
        }
    }
}
