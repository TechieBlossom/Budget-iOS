import Foundation

struct BudgetPeriod {
    let startDate: Date
    let endDate: Date
    let name: String
    let type: BudgetType
    let wasAutoShifted: Bool
    
    // Monthly budget initializer (existing logic)
    init(startDate: Date) {
        self.type = .monthly
        let calendar = Calendar.current
        let today = Date()
        
        // Normalize dates and compare start date to today
        let startOfStartDate = calendar.startOfDay(for: startDate)
        let startOfToday = calendar.startOfDay(for: today)
        
        if calendar.compare(startOfStartDate, to: startOfToday, toGranularity: .day) == .orderedDescending {
            // Start date is in the future - shift back one month for better usability
            let shiftedStartDate = calendar.date(byAdding: .month, value: -1, to: startDate) ?? startDate
            self.startDate = shiftedStartDate
            self.endDate = BudgetPeriod.calculateMonthlyEndDate(from: shiftedStartDate)
            self.wasAutoShifted = true
        } else {
            // Start date is today or in the past - use current month
            self.startDate = startDate
            self.endDate = BudgetPeriod.calculateMonthlyEndDate(from: startDate)
            self.wasAutoShifted = false
        }
        
        self.name = BudgetPeriod.generateMonthlyName(for: startDate, endDate: self.endDate)
    }
    
    // Type-specific initializer
    init(type: BudgetType, startDate: Date, customName: String? = nil) {
        self.type = type
        
        switch type {
        case .monthly:
            let calendar = Calendar.current
            let today = Date()
            
            // Normalize dates and compare start date to today  
            let startOfStartDate = calendar.startOfDay(for: startDate)
            let startOfToday = calendar.startOfDay(for: today)
            
            if calendar.compare(startOfStartDate, to: startOfToday, toGranularity: .day) == .orderedDescending {
                // Start date is in the future - shift back one month for better usability
                let shiftedStartDate = calendar.date(byAdding: .month, value: -1, to: startDate) ?? startDate
                self.startDate = shiftedStartDate
                self.endDate = BudgetPeriod.calculateMonthlyEndDate(from: shiftedStartDate)
                self.wasAutoShifted = true
            } else {
                // Start date is today or in the past - use current month
                self.startDate = startDate
                self.endDate = BudgetPeriod.calculateMonthlyEndDate(from: startDate)
                self.wasAutoShifted = false
            }
            
            self.name = customName ?? BudgetPeriod.generateMonthlyName(for: startDate, endDate: self.endDate)
            
        case .custom:
            fatalError("Use init(type:startDate:endDate:customName:) for custom budget type")
        }
    }
    
    // Custom budget initializer
    init(type: BudgetType, startDate: Date, endDate: Date, customName: String) {
        self.type = type
        
        let calendar = Calendar.current
        let today = Date()
        
        // Normalize dates and compare start date to today
        let startOfStartDate = calendar.startOfDay(for: startDate)
        let startOfToday = calendar.startOfDay(for: today)
        
        if calendar.compare(startOfStartDate, to: startOfToday, toGranularity: .day) == .orderedDescending {
            // Start date is in the future - shift back one month for better usability
            let shiftedStartDate = calendar.date(byAdding: .month, value: -1, to: startDate) ?? startDate
            let shiftedEndDate = calendar.date(byAdding: .month, value: -1, to: endDate) ?? endDate
            self.startDate = shiftedStartDate
            self.endDate = shiftedEndDate
            self.wasAutoShifted = true
        } else {
            // Start date is today or in the past - use dates as-is
            self.startDate = startDate
            self.endDate = endDate
            self.wasAutoShifted = false
        }
        
        self.name = customName
    }
    
    // Legacy initializer for backward compatibility
    init(startDate: Date, endDate: Date) {
        self.startDate = startDate
        self.endDate = endDate
        self.name = BudgetPeriod.generateMonthlyName(for: startDate, endDate: endDate)
        self.type = .monthly
        self.wasAutoShifted = false
    }
    
    private static func calculateMonthlyEndDate(from startDate: Date) -> Date {
        let calendar = Calendar.current
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: startDate) ?? startDate
        let endDate = calendar.date(byAdding: .day, value: -1, to: nextMonth) ?? startDate
        return endDate
    }
    
    
    private static func generateMonthlyName(for startDate: Date, endDate: Date) -> String {
        let calendar = Calendar.current
        let today = Date()
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM yyyy"
        
        // Normalize both dates to start of day to avoid time component issues
        let startOfStartDate = calendar.startOfDay(for: startDate)
        let startOfToday = calendar.startOfDay(for: today)
        
        // Use the same logic as date shifting to determine budget name
        if calendar.compare(startOfStartDate, to: startOfToday, toGranularity: .day) == .orderedDescending {
            // Start date is in the future - this is a previous month budget
            let previousMonth = calendar.date(byAdding: .month, value: -1, to: today) ?? today
            return "\(monthFormatter.string(from: previousMonth)) Budget"
        } else {
            // Start date is today or in the past - this is a current month budget
            return "\(monthFormatter.string(from: today)) Budget"
        }
    }
    
    static func generateCustomName(for startDate: Date, endDate: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        let calendar = Calendar.current
        let startMonth = calendar.component(.month, from: startDate)
        let endMonth = calendar.component(.month, from: endDate)
        
        if startMonth == endMonth {
            // Same month: "Sep 5-15, 2024"
            formatter.dateFormat = "d"
            let startDay = formatter.string(from: startDate)
            let endDay = formatter.string(from: endDate)
            
            formatter.dateFormat = "MMM"
            let month = formatter.string(from: startDate)
            let year = calendar.component(.year, from: startDate)
            
            return "\(month) \(startDay)-\(endDay), \(year)"
        } else {
            // Different months: "Aug 28 - Sep 15, 2024"
            let startStr = formatter.string(from: startDate)
            let endStr = formatter.string(from: endDate)
            let year = calendar.component(.year, from: startDate)
            
            return "\(startStr) - \(endStr), \(year)"
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

