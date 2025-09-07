import Foundation

struct Budget: Identifiable {
    let id = UUID()
    let period: BudgetPeriod
    let currency: Currency
    let categories: [Category]
    let categoryAmounts: [String: Double]
    
    init(period: BudgetPeriod, currency: Currency, categories: [Category], categoryAmounts: [String: Double]) {
        self.period = period
        self.currency = currency
        self.categories = categories
        self.categoryAmounts = categoryAmounts
    }
    
    var totalAmount: Double {
        categoryAmounts.values.reduce(0, +)
    }
    
    var formattedTotalAmount: String {
        return String(format: "%.2f", totalAmount)
    }
    
    var budgetName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: period.startDate)
    }
    
    static func createSample() -> Budget {
        let startDate = Calendar.current.date(byAdding: .day, value: -15, to: Date()) ?? Date()
        let period = BudgetPeriod(startDate: startDate)
        let currency = Currency(code: "USD", name: "US Dollar", symbol: "$")
        let categories = Category.createDefault()
        
        var categoryAmounts: [String: Double] = [:]
        for (index, category) in categories.enumerated() {
            categoryAmounts[category.id.uuidString] = Double((index + 1) * 500) // Sample amounts
        }
        
        return Budget(
            period: period,
            currency: currency,
            categories: categories,
            categoryAmounts: categoryAmounts
        )
    }
}