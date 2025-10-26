import SwiftUI

struct AddTransactionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    let budgetId: UUID
    let categories: [SubCategory]
    let currency: Currency
    let budgetPeriod: BudgetPeriod
    let budgetName: String
    let categoryAmounts: [String: Double]
    let existingTransaction: Transaction?
    let onSaveTransaction: (Transaction) -> Void
    let onUpdateBudget: ((Budget) -> Bool)?
    let onDeleteTransaction: ((Transaction) -> Void)?

    @State private var name: String = ""
    @State private var amount: String = ""
    @State private var notes: String = ""
    @State private var selectedSubCategory: SubCategory?
    @State private var selectedDate = Date() // Defaults to today
    @State private var showingZeroBudgetAlert = false
    @State private var pendingTransaction: Transaction?
    @State private var isRecurring: Bool = false
    @State private var selectedRecurrenceIndex: Int = 0  // 0 = Weekly, 1 = Monthly
    @State private var showingDeleteConfirmation = false
    @State private var showingSubCategoryPicker = false

    private var isEditMode: Bool {
        existingTransaction != nil
    }

    init(budgetId: UUID, categories: [SubCategory], currency: Currency, budgetPeriod: BudgetPeriod, budgetName: String, categoryAmounts: [String: Double], existingTransaction: Transaction? = nil, onSaveTransaction: @escaping (Transaction) -> Void, onUpdateBudget: ((Budget) -> Bool)? = nil, onDeleteTransaction: ((Transaction) -> Void)? = nil) {
        self.budgetId = budgetId
        self.categories = categories
        self.currency = currency
        self.budgetPeriod = budgetPeriod
        self.budgetName = budgetName
        self.categoryAmounts = categoryAmounts
        self.existingTransaction = existingTransaction
        self.onSaveTransaction = onSaveTransaction
        self.onUpdateBudget = onUpdateBudget
        self.onDeleteTransaction = onDeleteTransaction

        // Initialize state from existing transaction if in edit mode
        if let transaction = existingTransaction {
            _name = State(initialValue: transaction.name)
            _amount = State(initialValue: String(format: "%.2f", transaction.amount))
            _notes = State(initialValue: transaction.notes)
            _selectedDate = State(initialValue: transaction.date)
            _isRecurring = State(initialValue: transaction.isRecurring)
            _selectedRecurrenceIndex = State(initialValue: transaction.recurrenceType == .weekly ? 0 : 1)
            _selectedSubCategory = State(initialValue: categories.first(where: { $0.id == transaction.categoryId }))
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: DSSpacing.xl) {
                        // Top spacing
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 8)

                        // Date Section
                        HorizontalDatePicker(selectedDate: $selectedDate, budgetPeriod: budgetPeriod)

                        // Name Section
                        VStack(alignment: .leading, spacing: DSSpacing.xs) {
                            DSText("Expense Name", font: .dsHeadline, color: theme.colors.textPrimary)
                            DSTextField("e.g., Coffee, Groceries, Gas", text: $name, autocapitalization: .words)
                        }.padding(.horizontal, DSSpacing.md)

                        // Amount Section
                        VStack(alignment: .leading, spacing: DSSpacing.xs) {
                            DSText("Amount", font: .dsHeadline, color: theme.colors.textPrimary)
                            DSTextField("Enter amount (e.g., 25.50)", text: $amount, keyboardType: .decimalPad)
                        }.padding(.horizontal, DSSpacing.md)

                        // Recurring Transaction Section
                        VStack(alignment: .leading, spacing: DSSpacing.sm) {
                            DSText("Recurring Transaction", font: .dsHeadline, color: theme.colors.textPrimary)


                                HStack(spacing: DSSpacing.md) {
                                    DSFilterChip("One-time", isSelected: !isRecurring) {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            isRecurring = false
                                        }
                                    }

                                    DSFilterChip("Weekly", isSelected: isRecurring && selectedRecurrenceIndex == 0) {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            isRecurring = true
                                            selectedRecurrenceIndex = 0
                                        }
                                    }

                                    DSFilterChip("Monthly", isSelected: isRecurring && selectedRecurrenceIndex == 1) {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            isRecurring = true
                                            selectedRecurrenceIndex = 1
                                        }
                                    }
                                }
                            }
                        .frame(height: 40)
                        .padding(.horizontal, DSSpacing.md)

                        // Notes Section
                        VStack(alignment: .leading, spacing: DSSpacing.xs) {
                            DSText("Notes (Optional)", font: .dsHeadline, color: theme.colors.textPrimary)

                            DSTextField("e.g., Lunch with colleagues, Receipt #1234", text: $notes, autocapitalization: .words)
                        }.padding(.horizontal, DSSpacing.md)

                        // Category Section
                        VStack(alignment: .leading, spacing: DSSpacing.xs) {
                            DSText("Category", font: .dsHeadline, color: theme.colors.textPrimary)

                            Button(action: {
                                showingSubCategoryPicker = true
                            }) {
                                HStack(spacing: DSSpacing.sm) {
                                    if let subCategory = selectedSubCategory {
                                        Circle()
                                            .fill(subCategory.categoryGroup.color)
                                            .frame(width: 12, height: 12)

                                        VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                                            DSText(subCategory.name, font: .dsHeadline, color: theme.colors.textPrimary)
                                            DSText(subCategory.categoryGroup.displayName, font: .dsCaption, color: theme.colors.textSecondary)
                                        }
                                    } else {
                                        DSText("Select Category", font: .dsHeadline, color: theme.colors.textSecondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.dsSubtitle)
                                        .foregroundColor(theme.colors.textSecondary)
                                }
                                .padding(DSSpacing.md)
                                .background(theme.colors.surface)
                                .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }.padding(.horizontal, DSSpacing.md)

                        // Bottom spacing
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 20)
                    }
                }
            }
            .background(theme.colors.background)
            .navigationTitle(isEditMode ? "Edit Expense" : "Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .customNavigationBarAppearance()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Image(systemName: "xmark")
                        .font(.dsHeadline)
                        .foregroundColor(theme.colors.textPrimary)
                        .onTapGesture {
                            dismiss()
                        }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    if isEditMode, onDeleteTransaction != nil {
                        Button(action: {
                            showingDeleteConfirmation = true
                        }) {
                            Image(systemName: "trash")
                                .font(.dsHeadline)
                                .foregroundColor(.red)
                        }
                    }

                    Button(action: {
                        saveTransaction()
                    }) {
                        Image(systemName: "checkmark")
                            .font(.dsHeadline)
                            .foregroundColor(isFormValid ? theme.colors.primary : theme.colors.textSecondary)
                    }
                    .disabled(!isFormValid)
                }
            }
        }
        .alert("Delete Transaction", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let transaction = existingTransaction {
                    onDeleteTransaction?(transaction)
                    dismiss()
                }
            }
        } message: {
            Text("Are you sure you want to delete this transaction? This action cannot be undone.")
        }
        .alert("Category Not in Budget", isPresented: $showingZeroBudgetAlert) {
            Button("Cancel", role: .cancel) {
                pendingTransaction = nil
            }
            Button("Add to Budget") {
                addTransactionWithBudgetUpdate()
            }
        } message: {
            Text("This category is not currently in your budget. Adding this transaction will add the category to your budget with a budget amount of \(pendingTransaction?.formattedAmount ?? "0.00") \(currency.code).")
        }
        .sheet(isPresented: $showingSubCategoryPicker) {
            SubCategorySelectionSheet(
                subCategories: categories,
                selectedSubCategory: $selectedSubCategory,
                onSelect: { subCategory in
                    selectedSubCategory = subCategory
                }
            )
        }
    }

    private var isFormValid: Bool {
        !amount.isEmpty &&
        selectedSubCategory != nil &&
        Double(amount) != nil &&
        Double(amount) ?? 0 > 0
    }
    
    private func saveTransaction() {
        guard let subCategory = selectedSubCategory,
              let amountValue = Double(amount),
              amountValue > 0 else {
            return
        }

        // Determine recurrence type
        let recurrenceType: RecurrenceType = isRecurring ? (selectedRecurrenceIndex == 0 ? .weekly : .monthly) : .none

        let transaction: Transaction
        if let existingTx = existingTransaction {
            // Edit mode: preserve the ID
            transaction = Transaction(
                id: existingTx.id,
                amount: amountValue,
                name: name,
                notes: notes,
                date: selectedDate,
                categoryId: subCategory.id,
                isRecurring: isRecurring,
                recurrenceType: recurrenceType
            )
        } else {
            // Add mode: create new transaction
            transaction = Transaction(
                amount: amountValue,
                name: name,
                notes: notes,
                date: selectedDate,
                categoryId: subCategory.id,
                isRecurring: isRecurring,
                recurrenceType: recurrenceType
            )
        }

        // Check if sub-category has zero budget amount (only in add mode)
        if !isEditMode {
            let categoryBudgetAmount = categoryAmounts[subCategory.id.uuidString] ?? 0
            if categoryBudgetAmount == 0 {
                pendingTransaction = transaction
                showingZeroBudgetAlert = true
                return
            }
        }

        // Sub-category has budget, proceed normally
        // If recurring and in add mode, add multiple transactions
        if isRecurring && !isEditMode {
            addRecurringTransactions(baseTransaction: transaction, subCategory: subCategory)
        } else {
            onSaveTransaction(transaction)
        }
        dismiss()
    }

    private func addRecurringTransactions(baseTransaction: Transaction, subCategory: SubCategory) {
        let calendar = Calendar.current

        // Add the initial transaction
        onSaveTransaction(baseTransaction)

        // Calculate how many recurring transactions to add based on budget period
        let occurrences: Int
        switch baseTransaction.recurrenceType {
        case .weekly:
            // Add weekly transactions until budget end date
            let weeks = calendar.dateComponents([.weekOfYear], from: baseTransaction.date, to: budgetPeriod.endDate).weekOfYear ?? 0
            occurrences = max(0, weeks)
        case .monthly:
            // Add monthly transactions until budget end date
            let months = calendar.dateComponents([.month], from: baseTransaction.date, to: budgetPeriod.endDate).month ?? 0
            occurrences = max(0, months)
        case .none:
            occurrences = 0
        }

        // Add subsequent transactions
        for i in 1...occurrences {
            var nextDate: Date?
            switch baseTransaction.recurrenceType {
            case .weekly:
                nextDate = calendar.date(byAdding: .weekOfYear, value: i, to: baseTransaction.date)
            case .monthly:
                nextDate = calendar.date(byAdding: .month, value: i, to: baseTransaction.date)
            case .none:
                break
            }

            if let date = nextDate, date <= budgetPeriod.endDate {
                let recurringTransaction = Transaction(
                    amount: baseTransaction.amount,
                    name: baseTransaction.name,
                    notes: baseTransaction.notes,
                    date: date,
                    categoryId: subCategory.id,
                    isRecurring: true,
                    recurrenceType: baseTransaction.recurrenceType
                )
                onSaveTransaction(recurringTransaction)
            }
        }
    }

    private func addTransactionWithBudgetUpdate() {
        guard let transaction = pendingTransaction,
              let category = selectedSubCategory,
              let onUpdateBudget = onUpdateBudget else {
            return
        }

        // Create updated budget with the transaction amount as the category budget
        var updatedCategoryAmounts = categoryAmounts
        updatedCategoryAmounts[category.id.uuidString] = transaction.amount

        let updatedBudget = Budget(
            id: budgetId,
            period: budgetPeriod,
            currency: currency,
            categories: categories,
            categoryAmounts: updatedCategoryAmounts
        )

        // Update the budget first
        if onUpdateBudget(updatedBudget) {
            // Then add the transaction
            onSaveTransaction(transaction)
            dismiss()
        }

        pendingTransaction = nil
    }
}

struct CategorySelectionCard: View {
    let category: SubCategory
    let isSelected: Bool
    let onTap: () -> Void
    
    @Environment(\.appTheme) private var theme
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Color Border (left edge)
                Rectangle()
                    .fill(category.categoryGroup.color)
                    .frame(width: 8)
                    .cornerRadius(8, corners: [.topLeft, .bottomLeft])
                
                HStack(spacing: DSSpacing.xs) {
                    // Category Name
                    DSText(category.name, font: .dsHeadline, color: theme.colors.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                
                    Spacer()
                }
                .padding(.horizontal, DSSpacing.xs)
                .padding(.vertical, DSSpacing.md)
            }
            .background(theme.colors.surface)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.colors.primary, lineWidth: isSelected ? 2 : 0)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct HorizontalDatePicker: View {
    @Binding var selectedDate: Date
    let budgetPeriod: BudgetPeriod
    @Environment(\.appTheme) private var theme
    
    private let calendar = Calendar.current
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: DSSpacing.xs) {
                    // Leading spacer for first item
                    Spacer()
                        .frame(width: 8)
                    
                    ForEach(dateRange, id: \.self) { date in
                        DateCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isDisabled: date > Date(),
                            onTap: { 
                                if date <= Date() {
                                    selectedDate = date
                                    withAnimation(.easeInOut(duration: 0.6)) {
                                        proxy.scrollTo(date, anchor: .center)
                                    }
                                }
                            }
                        )
                        .id(date)
                    }
                    
                    // Trailing spacer for last item
                    Spacer()
                        .frame(width: 8)
                }
            }
            .frame(height: 70)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    // Find today's date in the range
                    let today = Date()
                    if let todayInRange = dateRange.first(where: { calendar.isDate($0, inSameDayAs: today) }) {
                        withAnimation(.easeInOut(duration: 1.2)) {
                            proxy.scrollTo(todayInRange, anchor: .center)
                        }
                    }
                }
            }
        }
    }
    
    private var dateRange: [Date] {
        var dates: [Date] = []
        let daysDifference = calendar.dateComponents([.day], from: budgetPeriod.startDate, to: budgetPeriod.endDate).day ?? 0
        
        // Generate dates from budget start to budget end
        for i in 0...daysDifference {
            if let date = calendar.date(byAdding: .day, value: i, to: budgetPeriod.startDate) {
                dates.append(date)
            }
        }
        
        return dates
    }
}

struct DateCell: View {
    let date: Date
    let isSelected: Bool
    let isDisabled: Bool
    let onTap: () -> Void

    @Environment(\.appTheme) private var theme
    private let calendar = Calendar.current

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: DSSpacing.xxs) {
                DSText(dayOfWeek, font: .dsCaption, color: isDisabled ? theme.colors.textSecondary.opacity(0.5) : theme.colors.textSecondary)
                DSText(dayNumber, font: .dsHeadline, color: isDisabled ? theme.colors.textPrimary.opacity(0.5) : theme.colors.textPrimary)
                    .fontWeight(isSelected ? .medium : .regular)
            }
            .frame(width: 60, height: 60)  // Square shaped
            .background(isDisabled ? theme.colors.surface.opacity(0.5) : theme.colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? theme.colors.primary : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
    }
    
    private var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}

#Preview {
    let budgetPeriod = BudgetPeriod(startDate: Date())
    let categories = SubCategory.createDefault()
    let categoryAmounts = categories.reduce(into: [String: Double]()) { result, category in
        result[category.id.uuidString] = 500.0
    }

    AddTransactionSheet(
        budgetId: UUID(),
        categories: categories,
        currency: Currency(code: "USD", name: "US Dollar", symbol: "$"),
        budgetPeriod: budgetPeriod,
        budgetName: budgetPeriod.name,
        categoryAmounts: categoryAmounts,
        existingTransaction: nil,
        onSaveTransaction: { transaction in
            print("Added transaction: \(transaction)")
        },
        onUpdateBudget: { budget in
            print("Updated budget: \(budget)")
            return true
        },
        onDeleteTransaction: nil
    )
}
