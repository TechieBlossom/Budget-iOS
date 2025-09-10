import SwiftUI

struct AllTransactionsView: View {
    let budgetManager: any BudgetManagerProtocol
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    
    private var transactionsByDate: [(Date, [Transaction])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: budgetManager.getAllTransactions().sorted { $0.date > $1.date }) { transaction in
            calendar.startOfDay(for: transaction.date)
        }
        
        return grouped.sorted { $0.key > $1.key }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            DSHeader(
                title: "All Transactions",
                subtitle: "\(budgetManager.getAllTransactions().count) transactions",
                onBack: {
                    dismiss()
                }
            )
            
            if transactionsByDate.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Spacer()
                    
                    Image(systemName: "list.bullet")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(theme.colors.secondaryText)
                    
                    VStack(spacing: 8) {
                        DSText("No Transactions", font: .dsHeadline, color: theme.colors.primaryText)
                        DSText("Start adding expenses to see them here", font: .dsBody, color: theme.colors.secondaryText)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
            } else {
                // Transactions list
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(transactionsByDate, id: \.0) { date, transactions in
                            TransactionDateSection(
                                date: date,
                                transactions: transactions,
                                budgetManager: budgetManager
                            )
                        }
                        
                        // Bottom spacing
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 40)
                    }
                }
            }
        }
        .background(theme.colors.background)
        .navigationBarBackButtonHidden(true)
    }
}

struct TransactionDateSection: View {
    let date: Date
    let transactions: [Transaction]
    let budgetManager: any BudgetManagerProtocol
    @Environment(\.appTheme) private var theme
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "'Today'"
        } else if Calendar.current.isDateInYesterday(date) {
            formatter.dateFormat = "'Yesterday'"
        } else {
            formatter.dateFormat = "EEEE, MMM d"
        }
        return formatter
    }
    
    private var dayTotal: Double {
        transactions.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Date header
            VStack(spacing: 8) {
                HStack {
                    DSText(dateFormatter.string(from: date), font: .dsBody, color: theme.colors.primaryText)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    DSText(String(format: "%.2f", dayTotal), font: .dsBody, color: theme.colors.secondaryText)
                }
                
                Divider()
                    .background(theme.colors.secondaryText.opacity(0.2))
            }
            .padding(.horizontal, 16)
            
            // Transactions for this date
            VStack(spacing: 8) {
                ForEach(transactions) { transaction in
                    TransactionRowView(
                        transaction: transaction,
                        budgetManager: budgetManager
                    )
                    .padding(.horizontal, 16)
                }
            }
        }
        .padding(.bottom, 24)
    }
}

struct TransactionRowView: View {
    let transaction: Transaction
    let budgetManager: any BudgetManagerProtocol
    @Environment(\.appTheme) private var theme
    
    private var category: Category? {
        budgetManager.budget.categories.first { $0.id == transaction.categoryId }
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }
    
    var body: some View {
        DSCard(padding: 12) {
            HStack(spacing: 12) {
                // Category color indicator
                if let category = category {
                    Rectangle()
                        .fill(category.color.color)
                        .frame(width: 4, height: 40)
                        .cornerRadius(2)
                } else {
                    Rectangle()
                        .fill(theme.colors.secondaryText)
                        .frame(width: 4, height: 40)
                        .cornerRadius(2)
                }
                
                // Transaction details
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        DSText(transaction.notes.isEmpty ? "Expense" : transaction.notes, 
                               font: .dsBody, color: theme.colors.primaryText)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        DSText(String(format: "%.2f", transaction.amount), 
                               font: .dsBody, color: theme.colors.primaryText)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        DSText(category?.name ?? "Unknown Category", 
                               font: .dsCaption, color: theme.colors.secondaryText)
                        
                        Spacer()
                        
                        DSText(timeFormatter.string(from: transaction.date), 
                               font: .dsCaption, color: theme.colors.secondaryText)
                    }
                }
            }
        }
    }
}

#Preview {
    AllTransactionsView(budgetManager: MockBudgetManager(budget: Budget.createSample()))
        .background(AppTheme.shared.colors.background)
}