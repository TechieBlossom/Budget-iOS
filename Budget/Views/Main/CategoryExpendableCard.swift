import SwiftUI

struct CategoryExpendableCard: View {
    let category: Category
    let budgetManager: BudgetManager
    let isExpanded: Bool
    let onToggle: () -> Void
    
    @Environment(\.appTheme) private var theme
    
    private var allocatedAmount: Double {
        budgetManager.budget.categoryAmounts[category.id.uuidString] ?? 0
    }
    
    private var spentAmount: Double {
        budgetManager.spentAmount(for: category)
    }
    
    private var remainingAmount: Double {
        budgetManager.remainingAmount(for: category)
    }
    
    private var spentPercentage: Double {
        budgetManager.spentPercentage(for: category)
    }
    
    private var remainingPercentage: Double {
        1.0 - spentPercentage
    }
    
    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: 0) {
                // Main card content
                HStack(spacing: 0) {
                    // Color Border
                    Rectangle()
                        .fill(category.color.color)
                        .frame(width: 8)
                        .cornerRadius(8, corners: [.topLeft, isExpanded ? [] : .bottomLeft])
                    
                    VStack(spacing: 16) {
                        // Category header
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                DSText(category.name, font: .dsHeadline, color: theme.colors.primaryText)
                                HStack(alignment: .bottom, spacing: 4) {
                                    DSText(String(format: "%.2f", spentAmount), font: .dsBody, color: theme.colors.primaryText)
                                        .animation(.easeInOut(duration: 0.8), value: spentAmount)
                                    DSText(budgetManager.budget.currency.code, font: .dsCaption, color: theme.colors.secondaryText)
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 8) {
                                // Double arrow icon
                                Image(systemName: isExpanded ? "chevron.up.2" : "chevron.down.2")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(theme.colors.secondaryText)
                                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                                
                                // Remaining percentage
                                DSText("\(Int(remainingPercentage * 100))%", font: .dsCaption, color: theme.colors.secondaryText)
                                    .animation(.easeInOut(duration: 0.8), value: remainingPercentage)
                            }
                        }
                        
                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background (total allocated)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(theme.colors.secondaryText.opacity(0.2))
                                    .frame(height: 8)
                                
                                // Progress fill (spent amount)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(category.color.color)
                                    .frame(width: geometry.size.width * spentPercentage, height: 8)
                                    .animation(.easeInOut(duration: 0.8), value: spentPercentage)
                            }
                        }
                        .frame(height: 8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                .background(theme.colors.card)
                .cornerRadius(8, corners: isExpanded ? [.topLeft, .topRight] : .allCorners)
                
                // Expanded content
                if isExpanded {
                    VStack(spacing: 0) {
                        // Recent transactions
                        let recentTransactions = budgetManager.recentTransactions(for: category)
                        
                        if recentTransactions.isEmpty {
                            VStack(spacing: 8) {
                                DSText("No transactions yet", font: .dsBody, color: theme.colors.secondaryText)
                                    .padding(.vertical, 24)
                            }
                            .frame(maxWidth: .infinity)
                            .background(theme.colors.card)
                        } else {
                            ForEach(Array(recentTransactions.enumerated()), id: \.element.id) { index, transaction in
                                TransactionRow(
                                    transaction: transaction,
                                    currency: budgetManager.budget.currency,
                                    onDelete: {
                                        budgetManager.deleteTransaction(transaction)
                                    }
                                )
                                
                                if index < recentTransactions.count - 1 {
                                    Divider()
                                        .background(theme.colors.secondaryText.opacity(0.2))
                                }
                            }
                        }
                    }
                    .background(theme.colors.card)
                    .overlay(
                        // Left border continuation - matches background corner radius
                        HStack {
                            Rectangle()
                                .fill(category.color.color)
                                .frame(width: 8)
                            Spacer()
                        },
                        alignment: .leading
                    )
                    .cornerRadius(8, corners: [.bottomLeft, .bottomRight])
                    .clipped()
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TransactionRow: View {
    let transaction: Transaction
    let currency: Currency
    let onDelete: () -> Void
    
    @Environment(\.appTheme) private var theme
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                DSText(transaction.notes, font: .dsBody, color: theme.colors.primaryText)
                DSText(transaction.formattedDate, font: .dsCaption, color: theme.colors.secondaryText)
            }
            
            Spacer()
            
            HStack(alignment: .bottom, spacing: 4) {
                DSText(transaction.formattedAmount, font: .dsBody, color: theme.colors.primaryText)
                DSText(currency.code, font: .dsCaption, color: theme.colors.secondaryText)
            }
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.body)
                    .foregroundColor(theme.colors.secondaryText)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 24) // Extra padding to account for left border
        .padding(.vertical, 12)
    }
}

#Preview {
    let budget = Budget.createSample()
    let budgetManager = BudgetManager(budget: budget)
    
    return VStack(spacing: 16) {
        CategoryExpendableCard(
            category: budget.categories.first!,
            budgetManager: budgetManager,
            isExpanded: false
        ) {}
        
        CategoryExpendableCard(
            category: budget.categories.first!,
            budgetManager: budgetManager,
            isExpanded: true
        ) {}
    }
    .padding()
    .background(AppTheme.shared.colors.background)
}
