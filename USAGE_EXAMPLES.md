# Database Usage Examples

## Overview

The app now includes local database functionality with **SwiftData** (latest version) for persistent storage of budgets and transactions. This allows you to record expenses to budgets regardless of the transaction date.

## Key Features

1. **CRUD Operations** for Budgets and Transactions
2. **Smart Budget Assignment** - Transactions can be assigned to the appropriate budget based on date
3. **Persistent Storage** - All data is saved locally using Core Data
4. **Date-Independent Transactions** - A transaction from August can belong to July or September budget

## Usage Examples

### 1. Creating and Managing Budgets

```swift
// Initialize the budget manager with SwiftData ModelContext
// In your SwiftUI view:
@Environment(\.modelContext) private var modelContext

let budgetManager = BudgetManager(modelContext: modelContext)

// Create a new budget
let currency = Currency(code: "USD", name: "US Dollar", symbol: "$")
let period = BudgetPeriod(startDate: Date())
let categories = Category.createDefault()

var categoryAmounts: [String: Double] = [:]
for (index, category) in categories.enumerated() {
    categoryAmounts[category.id.uuidString] = Double((index + 1) * 500)
}

let newBudget = Budget(
    period: period,
    currency: currency,
    categories: categories,
    categoryAmounts: categoryAmounts
)

// Save the budget to database
let success = budgetManager.createBudget(newBudget)
```

### 2. Adding Transactions to Specific Budgets

```swift
// Add transaction to current budget
let transaction = Transaction(
    amount: 150.0,
    notes: "Grocery Store",
    date: Date(),
    categoryId: someCategory.id
)

// This will add to the current budget
budgetManager.addTransaction(transaction)

// Add transaction to a specific budget
let specificBudgetId = someOtherBudget.id
budgetManager.addTransaction(transaction, to: specificBudgetId)
```

### 3. Smart Budget Assignment

```swift
// Add expense to the best fitting budget based on date
// For example: August transaction can go to July budget if it falls within that period
let augustTransaction = Transaction(
    amount: 200.0,
    notes: "Late payment from July",
    date: Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date(),
    categoryId: someCategory.id
)

// This will automatically find the correct budget for the transaction date
budgetManager.addExpenseToBestFitBudget(augustTransaction)
```

### 4. Retrieving Data

```swift
// Get all budgets
let allBudgets = budgetManager.getAllBudgets()

// Get transactions for a specific budget
let budgetTransactions = budgetManager.getTransactions(for: budgetId)

// Get all transactions across all budgets
let allTransactions = budgetManager.getAllTransactions()

// Find which budget a transaction date belongs to
let targetBudget = budgetManager.findBudgetForExpense(date: someDate)
```

### 5. Updating and Deleting

```swift
// Update a budget
let updatedBudget = Budget(id: existingBudget.id, ...)
budgetManager.updateBudget(updatedBudget)

// Update a transaction
let updatedTransaction = Transaction(id: existingTransaction.id, ...)
budgetManager.updateTransaction(updatedTransaction)

// Delete operations
budgetManager.deleteTransaction(transaction)
budgetManager.deleteBudget(budgetId)
```

## SwiftData Schema

### BudgetDataModel (@Model)
- `budgetId`: Unique identifier (UUID, @Attribute(.unique))
- `startDate`, `endDate`: Budget period (Date)
- `currencyCode`, `currencyName`, `currencySymbol`: Currency information (String)
- `categoriesData`: JSON-encoded categories (@Attribute(.externalStorage))
- `categoryAmountsData`: JSON-encoded budget amounts (@Attribute(.externalStorage))
- `transactions`: Related transactions (@Relationship(deleteRule: .cascade))

### TransactionDataModel (@Model)
- `transactionId`: Unique identifier (UUID, @Attribute(.unique))
- `amount`: Transaction amount (Double)
- `notes`: Transaction description (String)
- `date`: Transaction date (Date)
- `categoryId`: Associated category (UUID)
- `budget`: Related budget (Optional BudgetDataModel)

## SwiftData Features Used

- **@Model**: Modern Swift data modeling with automatic persistence
- **FetchDescriptor**: Type-safe queries with #Predicate macros
- **@Relationship**: Automatic relationship management with cascade deletion
- **@Attribute(.unique)**: Ensures unique constraints on IDs
- **@Attribute(.externalStorage)**: Efficient storage for large JSON data
- **SortDescriptor**: Built-in sorting capabilities

## Migration Notes

- Migrated from Core Data to **SwiftData** for modern Swift persistence
- Uses latest SwiftData features including #Predicate macros
- All existing UI components continue to work without changes
- Sample data is automatically created if no budgets exist
- SwiftData ModelContainer is initialized in `BudgetApp.swift`

## Testing

Use the `DatabaseTest` class to verify CRUD operations:

```swift
// In your SwiftUI view:
@Environment(\.modelContext) private var modelContext

let test = DatabaseTest(modelContext: modelContext)
await test.runTests()
```

This will test all SwiftData operations and print results.