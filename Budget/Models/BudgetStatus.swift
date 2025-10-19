import Foundation

enum BudgetStatus: Equatable {
    case noBudget
    case active
    case endingSoon(daysLeft: Int)
    case expired

    var description: String {
        switch self {
        case .noBudget:
            return "No budget found"
        case .active:
            return "Budget is active"
        case .endingSoon(let daysLeft):
            if daysLeft == 0 {
                return "Budget ends today"
            } else {
                return "Budget ends in \(daysLeft) day\(daysLeft == 1 ? "" : "s")"
            }
        case .expired:
            return "Budget has expired"
        }
    }

    var needsAttention: Bool {
        switch self {
        case .noBudget, .expired, .endingSoon:
            return true
        case .active:
            return false
        }
    }
}