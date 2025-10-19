import Foundation
import SwiftUI

enum CategoryGroup: String, Codable, CaseIterable, Identifiable {
    case essentials = "Essentials"
    case lifestyle = "Lifestyle"
    case occasional = "Occasional"
    case financialGoals = "Financial Goals"
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
        case .miscellaneous:
            return ["Others"]
        }
    }
}
