import Foundation

struct Transaction: Identifiable, Hashable {
    let id: UUID
    let budgetId: UUID  // Direct reference to budget for performance and data integrity
    let amount: Double
    let name: String  // Expense name (e.g., "Coffee", "Groceries")
    let notes: String  // Optional notes/description
    let date: Date
    let categoryId: UUID

    init(amount: Double, name: String = "", notes: String = "", date: Date = Date(), categoryId: UUID, budgetId: UUID) {
        self.id = UUID()
        self.budgetId = budgetId
        self.amount = amount
        self.name = name
        self.notes = notes
        self.date = date
        self.categoryId = categoryId
    }

    init(id: UUID, amount: Double, name: String = "", notes: String = "", date: Date, categoryId: UUID, budgetId: UUID) {
        self.id = id
        self.budgetId = budgetId
        self.amount = amount
        self.name = name
        self.notes = notes
        self.date = date
        self.categoryId = categoryId
    }
    
    var formattedAmount: String {
        return String(format: "%.2f", amount)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

