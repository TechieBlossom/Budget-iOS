import SwiftUI

struct AddTransactionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    
    let categories: [Category]
    let currency: Currency
    let budgetPeriod: BudgetPeriod
    let budgetName: String
    let onAddTransaction: (Transaction) -> Void
    
    @State private var name: String = ""
    @State private var amount: String = ""
    @State private var notes: String = ""
    @State private var selectedCategory: Category?
    @State private var selectedDate = Date() // Defaults to today
    
    var body: some View {
        return VStack(spacing: 0) {
            DSHeader(
                title: "Add Expense",
                subtitle: budgetName,
                onBack: {
                    dismiss()
                }
            )
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Date Section
                        HorizontalDatePicker(selectedDate: $selectedDate, budgetPeriod: budgetPeriod)
                        
                        // Name Section
                        VStack(alignment: .leading, spacing: 8) {
                            DSText("Expense Name", font: .dsBody, color: theme.colors.primaryText)
                            DSTextField("Enter expense name", text: $name)
                        }.padding(.horizontal, 16)
                        
                        // Amount Section
                        VStack(alignment: .leading, spacing: 8) {
                            DSText("Amount", font: .dsBody, color: theme.colors.primaryText)
                            DSTextField("0.00", text: $amount)
                                .keyboardType(.decimalPad)
                        }.padding(.horizontal, 16)
                        
                        // Category Section
                        VStack(alignment: .leading, spacing: 8) {
                            DSText("Category", font: .dsBody, color: theme.colors.primaryText)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                                ForEach(categories) { category in
                                    CategorySelectionCard(
                                        category: category,
                                        isSelected: selectedCategory?.id == category.id
                                    ) {
                                        selectedCategory = category
                                    }
                                }
                            }
                        }.padding(.horizontal, 16)
                        
                        // Notes Section
                        VStack(alignment: .leading, spacing: 8) {
                            DSText("Notes (Optional)", font: .dsBody, color: theme.colors.primaryText)
                            
                            DSTextField("Enter notes", text: $notes)
                        }.padding(.horizontal, 16)
                        
                        // Bottom spacing for sticky buttons
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 20)
                    }
                }
                
                // Sticky bottom buttons
                VStack(spacing: 0) {
                    Divider()
                        .background(theme.colors.secondaryText.opacity(0.2))
                    
                    DSButton("Save", style: .primary, fullWidth: true) {
                        saveTransaction()
                    }
                    .disabled(!isFormValid)
                    .opacity(isFormValid ? 1.0 : 0.6)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 16)
                    .background(theme.colors.background)
                }
        }
        .background(theme.colors.background)
        .navigationBarBackButtonHidden(true)
    }
    
    private var isFormValid: Bool {
        !name.isEmpty &&
        !amount.isEmpty && 
        selectedCategory != nil &&
        Double(amount) != nil &&
        Double(amount) ?? 0 > 0
    }
    
    private func saveTransaction() {
        guard let category = selectedCategory,
              let amountValue = Double(amount),
              amountValue > 0 else { return }
        
        let transaction = Transaction(
            amount: amountValue,
            notes: name.isEmpty ? notes : name,
            date: selectedDate,
            categoryId: category.id
        )
        
        onAddTransaction(transaction)
        dismiss()
    }
}

struct CategorySelectionCard: View {
    let category: Category
    let isSelected: Bool
    let onTap: () -> Void
    
    @Environment(\.appTheme) private var theme
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Color Border (left edge)
                Rectangle()
                    .fill(category.color.color)
                    .frame(width: 8)
                    .cornerRadius(8, corners: [.topLeft, .bottomLeft])
                
                HStack(spacing: 8) {
                    // Category Name
                    DSText(category.name, font: .dsHeadline, color: theme.colors.primaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 16)
            }
            .background(theme.colors.card)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.colors.primaryText, lineWidth: isSelected ? 2 : 0)
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
                LazyHStack(spacing: 8) {
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
            .frame(height: 82)
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
            VStack(spacing: 4) {
                DSText(dayOfWeek, font: .dsCaption, color: isDisabled ? theme.colors.secondaryText.opacity(0.5) : theme.colors.secondaryText)
                DSText(dayNumber, font: .dsHeadline, color: isDisabled ? theme.colors.primaryText.opacity(0.5) : theme.colors.primaryText)
                    .fontWeight(isSelected ? .medium : .regular)
            }
            .frame(width: 48, height: 72)
            .background(isDisabled ? theme.colors.card.opacity(0.5) : theme.colors.card)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? theme.colors.primaryText : Color.clear, 
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
    return AddTransactionSheet(
        categories: Category.createDefault(),
        currency: Currency(code: "USD", name: "US Dollar", symbol: "$"),
        budgetPeriod: budgetPeriod,
        budgetName: budgetPeriod.name
    ) { transaction in
        print("Added transaction: \(transaction)")
    }
}
