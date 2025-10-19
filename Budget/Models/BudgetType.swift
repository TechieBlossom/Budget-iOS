import Foundation

enum BudgetType: String, CaseIterable, Codable {
    case monthly = "monthly"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .monthly:
            return "Monthly"
        case .custom:
            return "Custom"
        }
    }
    
    var description: String {
        switch self {
        case .monthly:
            return "Monthly budget periods"
        case .custom:
            return "Set your own date range"
        }
    }
}