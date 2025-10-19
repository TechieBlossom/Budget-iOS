import SwiftUI

struct EditTransactionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    let transaction: Transaction
    let categories: [SubCategory]
    let currency: Currency
    let budgetPeriod: BudgetPeriod
    let budgetName: String
    let onUpdateTransaction: (Transaction) -> Void
    let onDeleteTransaction: ((Transaction) -> Void)?
    
    @State private var name: String
    @State private var amount: String
    @State private var notes: String
    @State private var selectedCategory: SubCategory?
    @State private var selectedDate: Date
    
    init(transaction: Transaction, categories: [SubCategory], currency: Currency, budgetPeriod: BudgetPeriod, budgetName: String, onUpdateTransaction: @escaping (Transaction) -> Void, onDeleteTransaction: ((Transaction) -> Void)? = nil) {
        self.transaction = transaction
        self.categories = categories
        self.currency = currency
        self.budgetPeriod = budgetPeriod
        self.budgetName = budgetName
        self.onUpdateTransaction = onUpdateTransaction
        self.onDeleteTransaction = onDeleteTransaction
        
        // Initialize state with existing transaction data
        // Try to parse existing notes into name and notes if they contain a separator
        let existingNotes = transaction.notes
        let (parsedName, parsedNotes) = EditTransactionSheet.parseTransactionNotes(existingNotes)
        
        self._name = State(initialValue: parsedName)
        self._amount = State(initialValue: transaction.formattedAmount)
        self._notes = State(initialValue: parsedNotes)
        self._selectedCategory = State(initialValue: categories.first { $0.id == transaction.categoryId })
        self._selectedDate = State(initialValue: transaction.date)
    }
    
    var body: some View {
        return VStack(spacing: 0) {
            DSHeader(
                title: "Edit Expense",
                subtitle: budgetName,
                onBack: {
                    dismiss()
                }
            )
                
                ScrollView {
                    VStack(spacing: DSSpacing.xl) {
                        // Date Section
                        HorizontalDatePicker(selectedDate: $selectedDate, budgetPeriod: budgetPeriod)
                        
                        // Name Section
                        VStack(alignment: .leading, spacing: DSSpacing.xs) {
                            DSText("Expense Name", font: .dsBody, color: theme.colors.textPrimary)
                            DSTextField("e.g., Coffee, Groceries, Gas", text: $name, autocapitalization: .words)
                        }.padding(.horizontal, DSSpacing.md)
                        
                        // Amount Section
                        VStack(alignment: .leading, spacing: DSSpacing.xs) {
                            DSText("Amount", font: .dsBody, color: theme.colors.textPrimary)
                            DSTextField("Enter amount (e.g., 25.50)", text: $amount, keyboardType: .decimalPad)
                        }.padding(.horizontal, DSSpacing.md)
                        
                        // Category Section
                        VStack(alignment: .leading, spacing: DSSpacing.xs) {
                            DSText("Category", font: .dsBody, color: theme.colors.textPrimary)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: DSSpacing.sm) {
                                ForEach(categories) { category in
                                    CategorySelectionCard(
                                        category: category,
                                        isSelected: selectedCategory?.id == category.id
                                    ) {
                                        HapticManager.shared.categorySelected()
                                        selectedCategory = category
                                    }
                                }
                            }
                        }.padding(.horizontal, DSSpacing.md)
                        
                        // Notes Section
                        VStack(alignment: .leading, spacing: DSSpacing.xs) {
                            DSText("Notes (Optional)", font: .dsBody, color: theme.colors.textPrimary)
                            
                            DSTextField("e.g., Lunch with colleagues, Receipt #1234", text: $notes, autocapitalization: .words)
                        }.padding(.horizontal, DSSpacing.md)
                        
                        // Bottom spacing for sticky buttons
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 20)
                    }
                }
                
                // Sticky bottom buttons
                VStack(spacing: 0) {
                    Divider()
                        .background(theme.colors.divider)

                    if onDeleteTransaction != nil {
                        // Two button layout when delete is available
                        HStack(spacing: DSSpacing.sm) {
                            DSButton("Delete", style: .outline) {
                                deleteTransaction()
                            }

                            DSButton("Update", style: .primary) {
                                updateTransaction()
                            }
                            .disabled(!isFormValid)
                            .opacity(isFormValid ? 1.0 : 0.6)
                        }
                        .padding(.vertical, DSSpacing.md)
                        .padding(.horizontal, DSSpacing.md)
                        .background(theme.colors.background)
                    } else {
                        // Single button layout when delete is not available
                        DSButton("Update", style: .primary, fullWidth: true) {
                            updateTransaction()
                        }
                        .disabled(!isFormValid)
                        .opacity(isFormValid ? 1.0 : 0.6)
                        .padding(.vertical, DSSpacing.md)
                        .padding(.horizontal, DSSpacing.md)
                        .background(theme.colors.background)
                    }
                }
        }
        .background(theme.colors.background)
        .navigationBarBackButtonHidden(true)
            .enableSwipeBack()
    }
    
    private var isFormValid: Bool {
        !name.isEmpty &&
        !amount.isEmpty && 
        selectedCategory != nil &&
        Double(amount) != nil &&
        Double(amount) ?? 0 > 0
    }
    
    private func updateTransaction() {
        guard let category = selectedCategory,
              let amountValue = Double(amount),
              amountValue > 0 else { return }
        
        // Combine name and notes appropriately
        let finalNotes: String
        if !name.isEmpty && !notes.isEmpty {
            finalNotes = "\(name) - \(notes)"
        } else if !name.isEmpty {
            finalNotes = name
        } else if !notes.isEmpty {
            finalNotes = notes
        } else {
            finalNotes = "" // Will show as "Expense" in the UI
        }
        
        let updatedTransaction = Transaction(
            id: transaction.id,  // Keep the same ID
            amount: amountValue,
            notes: finalNotes,
            date: selectedDate,
            categoryId: category.id
        )
        
        onUpdateTransaction(updatedTransaction)
        dismiss()
    }

    private func deleteTransaction() {
        onDeleteTransaction?(transaction)
        dismiss()
    }
    
    // Helper method to parse existing transaction notes into name and notes
    static func parseTransactionNotes(_ notes: String) -> (name: String, notes: String) {
        if notes.isEmpty {
            return ("", "")
        }
        
        // Check if notes contain the separator we use when combining name and notes
        if notes.contains(" - ") {
            let components = notes.components(separatedBy: " - ")
            if components.count >= 2 {
                let name = components[0].trimmingCharacters(in: .whitespaces)
                let remainingNotes = components.dropFirst().joined(separator: " - ").trimmingCharacters(in: .whitespaces)
                return (name, remainingNotes)
            }
        }
        
        // If no separator found, treat the entire string as the name
        return (notes, "")
    }
}

// Preview temporarily disabled due to compiler caching issue
// #Preview {
//     let budgetPeriod = BudgetPeriod(startDate: Date())
//     let categories: [SubCategory] = SubCategory.createDefault()
//     let transaction = Transaction(
//         amount: 50.0,
//         notes: "Sample transaction",
//         date: Date(),
//         categoryId: categories.first!.id
//     )
//
//     EditTransactionSheet(
//         transaction: transaction,
//         categories: categories,
//         currency: Currency(code: "USD", name: "US Dollar", symbol: "$"),
//         budgetPeriod: budgetPeriod,
//         budgetName: budgetPeriod.name,
//         onUpdateTransaction: { updatedTransaction in
//             print("Updated transaction: \(updatedTransaction)")
//         },
//         onDeleteTransaction: { transaction in
//             print("Deleted transaction: \(transaction)")
//         }
//     )
// }
