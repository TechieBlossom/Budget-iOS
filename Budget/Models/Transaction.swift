import Foundation

struct Transaction: Identifiable, Hashable {
    let id: UUID
    let amount: Double
    let notes: String
    let date: Date
    let categoryId: UUID
    
    init(amount: Double, notes: String, date: Date = Date(), categoryId: UUID) {
        self.id = UUID()
        self.amount = amount
        self.notes = notes
        self.date = date
        self.categoryId = categoryId
    }
    
    init(id: UUID, amount: Double, notes: String, date: Date, categoryId: UUID) {
        self.id = id
        self.amount = amount
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

