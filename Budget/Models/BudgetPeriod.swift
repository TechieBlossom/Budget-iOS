import Foundation

struct BudgetPeriod {
    let startDate: Date
    let endDate: Date
    let name: String
    
    init(startDate: Date) {
        self.startDate = startDate
        self.endDate = BudgetPeriod.calculateEndDate(from: startDate)
        self.name = BudgetPeriod.generateName(for: endDate)
    }
    
    private static func calculateEndDate(from startDate: Date) -> Date {
        let calendar = Calendar.current
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: startDate) ?? startDate
        let endDate = calendar.date(byAdding: .day, value: -1, to: nextMonth) ?? startDate
        return endDate
    }
    
    private static func generateName(for endDate: Date) -> String {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: endDate)
        
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM yyyy"
        
        if day <= 10 {
            // Previous month budget
            let previousMonth = calendar.date(byAdding: .month, value: -1, to: endDate) ?? endDate
            return "\(monthFormatter.string(from: previousMonth)) Budget"
        } else {
            // Current month budget
            return "\(monthFormatter.string(from: endDate)) Budget"
        }
    }
    
    var durationInDays: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: startDate, to: endDate)
        return (components.day ?? 0) + 1
    }
    
    var formattedDateRange: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        let startString = formatter.string(from: startDate)
        let endString = formatter.string(from: endDate)
        
        return "\(startString) - \(endString)"
    }
}

