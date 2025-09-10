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
    
    var index: Int {
        switch self {
        case .monthly:
            return 0
        case .custom:
            return 1
        }
    }
    
    static func fromIndex(_ index: Int) -> BudgetType {
        switch index {
        case 1:
            return .custom
        default:
            return .monthly
        }
    }
}