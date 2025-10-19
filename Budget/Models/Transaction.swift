import Foundation

enum RecurrenceType: String, Codable, CaseIterable {
    case none = "None"
    case weekly = "Weekly"
    case monthly = "Monthly"

    var displayName: String {
        rawValue
    }
}

struct Transaction: Identifiable, Hashable {
    let id: UUID
    let amount: Double
    let notes: String
    let date: Date
    let categoryId: UUID
    let isRecurring: Bool
    let recurrenceType: RecurrenceType

    init(amount: Double, notes: String, date: Date = Date(), categoryId: UUID, isRecurring: Bool = false, recurrenceType: RecurrenceType = .none) {
        self.id = UUID()
        self.amount = amount
        self.notes = notes
        self.date = date
        self.categoryId = categoryId
        self.isRecurring = isRecurring
        self.recurrenceType = recurrenceType
    }

    init(id: UUID, amount: Double, notes: String, date: Date, categoryId: UUID, isRecurring: Bool = false, recurrenceType: RecurrenceType = .none) {
        self.id = id
        self.amount = amount
        self.notes = notes
        self.date = date
        self.categoryId = categoryId
        self.isRecurring = isRecurring
        self.recurrenceType = recurrenceType
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

