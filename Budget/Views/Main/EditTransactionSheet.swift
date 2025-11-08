import SwiftUI

struct EditTransactionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    let transaction: Transaction
    let categories: [SubCategory]
    let currency: Currency
    let budgetPeriod: BudgetPeriod
    let budgetName: String
    let budgetManager: any BudgetManagerProtocol
    let onSuccess: () -> Void

    @State private var name: String
    @State private var amount: String
    @State private var notes: String
    @State private var selectedCategory: SubCategory?
    @State private var selectedDate: Date
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showingDeleteConfirmation = false
    
    init(transaction: Transaction, categories: [SubCategory], currency: Currency, budgetPeriod: BudgetPeriod, budgetName: String, budgetManager: any BudgetManagerProtocol, onSuccess: @escaping () -> Void) {
        self.transaction = transaction
        self.categories = categories
        self.currency = currency
        self.budgetPeriod = budgetPeriod
        self.budgetName = budgetName
        self.budgetManager = budgetManager
        self.onSuccess = onSuccess

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
        return ZStack {
            VStack(spacing: 0) {
                DSHeader(
                    title: "Edit Expense",
                    subtitle: budgetName,
                    onBack: {
                        if !isSaving {
                            dismiss()
                        }
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
                                .disabled(isSaving)
                        }.padding(.horizontal, DSSpacing.md)

                        // Amount Section
                        VStack(alignment: .leading, spacing: DSSpacing.xs) {
                            DSText("Amount", font: .dsBody, color: theme.colors.textPrimary)
                            DSTextField("Enter amount (e.g., 25.50)", text: $amount, keyboardType: .decimalPad)
                                .disabled(isSaving)
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
                                .disabled(isSaving)
                        }.padding(.horizontal, DSSpacing.md)

                        // Error Message
                        if let errorMessage = errorMessage {
                            DSText(errorMessage, font: .dsCaption, color: .red)
                                .padding(.horizontal, DSSpacing.md)
                        }

                        // Bottom spacing for sticky buttons
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 20)
                    }
                }
                .scrollDismissesKeyboard(.interactively)

                // Sticky bottom buttons
                VStack(spacing: 0) {
                    Divider()
                        .background(theme.colors.divider)

                    // Two button layout
                    HStack(spacing: DSSpacing.sm) {
                        DSButton("Delete", style: .outline) {
                            if !isSaving {
                                showingDeleteConfirmation = true
                            }
                        }
                        .disabled(isSaving)

                        DSButton("Update", style: .primary) {
                            if !isSaving {
                                updateTransaction()
                            }
                        }
                        .disabled(!isFormValid || isSaving)
                        .opacity(isFormValid && !isSaving ? 1.0 : 0.6)
                    }
                    .padding(.vertical, DSSpacing.md)
                    .padding(.horizontal, DSSpacing.md)
                    .background(theme.colors.background)
                }
            }
            .background(theme.colors.background)

            // Loading Overlay
            if isSaving {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()

                VStack(spacing: DSSpacing.md) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(theme.colors.primary)
                    DSText("Saving...", font: .dsBody, color: theme.colors.textPrimary)
                }
                .padding(DSSpacing.xl)
                .background(theme.colors.surface)
                .cornerRadius(12)
            }
        }
        .navigationBarBackButtonHidden(true)
        .enableSwipeBack()
        .alert("Delete Transaction", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteTransaction()
            }
        } message: {
            Text("Are you sure you want to delete this transaction? This action cannot be undone.")
        }
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
            categoryId: category.id,
            budgetId: transaction.budgetId  // Preserve existing budgetId
        )

        isSaving = true
        errorMessage = nil

        Task {
            print("📝 EditTransactionSheet: Updating transaction...")

            let success: Bool
            if let manager = budgetManager as? BudgetManager {
                success = await manager.updateTransaction(updatedTransaction)
            } else {
                success = budgetManager.updateTransaction(updatedTransaction)
            }

            if !success {
                print("   ❌ Update failed")
                isSaving = false
                if let manager = budgetManager as? BudgetManager {
                    errorMessage = manager.lastError ?? "Failed to update transaction"
                    print("   Error: \(manager.lastError ?? "unknown")")
                } else {
                    errorMessage = "Failed to update transaction"
                }
                return
            }

            print("   ✅ Update succeeded")

            // Force a refresh to ensure UI has latest data
            if let manager = budgetManager as? BudgetManager {
                print("   🔄 Forcing refresh from Supabase to sync UI...")
                await manager.refreshFromSupabase()
                print("   ✅ Refresh complete")
            }

            print("   ✅ Dismissing sheet")
            isSaving = false
            onSuccess()
            dismiss()
        }
    }

    private func deleteTransaction() {
        isSaving = true
        errorMessage = nil

        Task {
            print("🗑️ EditTransactionSheet: Deleting transaction...")

            let success: Bool
            if let manager = budgetManager as? BudgetManager {
                success = await manager.deleteTransaction(transaction)
            } else {
                success = budgetManager.deleteTransaction(transaction)
            }

            if !success {
                print("   ❌ Delete failed")
                isSaving = false
                if let manager = budgetManager as? BudgetManager {
                    errorMessage = manager.lastError ?? "Failed to delete transaction"
                    print("   Error: \(manager.lastError ?? "unknown")")
                } else {
                    errorMessage = "Failed to delete transaction"
                }
                return
            }

            print("   ✅ Delete succeeded")

            // Force a refresh to ensure UI has latest data
            if let manager = budgetManager as? BudgetManager {
                print("   🔄 Forcing refresh from Supabase to sync UI...")
                await manager.refreshFromSupabase()
                print("   ✅ Refresh complete")
            }

            print("   ✅ Dismissing sheet")
            isSaving = false
            onSuccess()
            dismiss()
        }
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
