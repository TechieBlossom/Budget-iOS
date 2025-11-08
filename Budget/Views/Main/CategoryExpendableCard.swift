import SwiftUI

struct CategoryExpendableCard: View {
    let category: SubCategory
    let budgetManager: any BudgetManagerProtocol
    let isExpanded: Bool
    let onToggle: () -> Void
    let onEditTransaction: ((Transaction) -> Void)?
    let onDeleteTransaction: ((Transaction) -> Void)?

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

    // Actual percentage for display (can exceed 100%)
    private var actualSpentPercentage: Double {
        guard allocatedAmount > 0 else { return 0 }
        return (spentAmount / allocatedAmount)
    }

    // Capped percentage for progress bar (max 100%)
    private var displayBarPercentage: Double {
        min(1.0, actualSpentPercentage)
    }

    private var remainingPercentage: Double {
        1.0 - spentPercentage
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main card content - make this section tappable for expand/collapse
            Button(action: {
                HapticManager.shared.buttonTap()
                onToggle()
            }) {
                HStack(spacing: 0) {
                    // Color Border
                    Rectangle()
                        .fill(category.categoryGroup.color)
                        .frame(width: 8)
                        .cornerRadius(8, corners: [.topLeft, isExpanded ? [] : .bottomLeft])

                    VStack(spacing: DSSpacing.xs) {
                        // Category header
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                                DSText(category.name, font: .dsHeadline, color: theme.colors.textPrimary)
                                HStack(alignment: .bottom, spacing: DSSpacing.xxs) {
                                    DSText(String(format: "%.0f/%.0f", spentAmount, allocatedAmount), font: .dsCaption, color: theme.colors.textPrimary)
                                    DSText(budgetManager.budget.currency.code, font: .dsCaption, color: theme.colors.textSecondary)
                                }
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: DSSpacing.xs) {
                                // Double arrow icon
                                Image(systemName: isExpanded ? "chevron.up.2" : "chevron.down.2")
                                    .font(.dsHeadline)
                                    .foregroundColor(theme.colors.textSecondary)
                                    .rotationEffect(.degrees(isExpanded ? 180 : 0))

                                Spacer()

                                // Spent percentage - aligned with spent amount
                                DSText("\(Int(actualSpentPercentage * 100))%", font: .dsBody, color: theme.colors.textSecondary)
                                    .fontWeight(.bold)
                            }
                        }

                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background (total allocated)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(theme.colors.textSecondary.opacity(0.2))
                                    .frame(height: 8)

                                // Progress fill (spent amount) - capped at 100%
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(category.categoryGroup.color)
                                    .frame(width: geometry.size.width * displayBarPercentage, height: 8)
                            }
                        }
                        .frame(height: 8)
                    }
                    .padding(.horizontal, DSSpacing.md)
                    .padding(.vertical, DSSpacing.sm)
                }
                .background(theme.colors.surface)
                .cornerRadius(8, corners: isExpanded ? [.topLeft, .topRight] : .allCorners)
            }
            .buttonStyle(PlainButtonStyle())

            // Expanded content
            if isExpanded {
                VStack(spacing: 0) {
                    // Recent transactions
                    let recentTransactions = budgetManager.recentTransactions(for: category, limit: 5)

                    if recentTransactions.isEmpty {
                        VStack(spacing: DSSpacing.xs) {
                            DSText("No transactions yet", font: .dsBody, color: theme.colors.textSecondary)
                                .padding(.vertical, DSSpacing.xl)
                        }
                        .frame(maxWidth: .infinity)
                        .background(theme.colors.surface)
                    } else {
                        ForEach(Array(recentTransactions.enumerated()), id: \.element.id) { index, transaction in
                            TransactionRow(
                                transaction: transaction,
                                currency: budgetManager.budget.currency,
                                onEdit: {
                                    onEditTransaction?(transaction)
                                },
                                onDelete: {
                                    if budgetManager.deleteTransaction(transaction) {
                                        onDeleteTransaction?(transaction)
                                    }
                                }
                            )

                            if index < recentTransactions.count - 1 {
                                Divider()
                                    .background(theme.colors.divider)
                            }
                        }
                    }
                }
                .background(theme.colors.surface)
                .overlay(
                    // Left border continuation - matches background corner radius
                    HStack {
                        Rectangle()
                            .fill(category.categoryGroup.color)
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
}

struct TransactionRow: View {
    let transaction: Transaction
    let currency: Currency
    let onEdit: () -> Void
    let onDelete: () -> Void

    @Environment(\.appTheme) private var theme
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            HapticManager.shared.buttonTap()
            onEdit()
        }) {
            HStack(spacing: DSSpacing.md) {
                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                    DSText(transaction.name.isEmpty ? transaction.notes : transaction.name, font: .dsBody, color: theme.colors.textPrimary)
                    DSText(transaction.formattedDate, font: .dsCaption, color: theme.colors.textSecondary)
                }

                Spacer(minLength: 0)

                HStack(alignment: .bottom, spacing: DSSpacing.xxs) {
                    DSText(transaction.formattedAmount, font: .dsBody, color: theme.colors.textPrimary)
                    DSText(currency.code, font: .dsCaption, color: theme.colors.textSecondary)
                }

                // Delete button - will handle its own tap events
                Button(action: {
                    HapticManager.shared.buttonTap()
                    onDelete()
                }) {
                    Image(systemName: "trash")
                        .font(.body)
                        .foregroundColor(theme.colors.textSecondary)
                        .padding(DSSpacing.xs)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DSSpacing.xl) // Extra padding to account for left border
            .padding(.vertical, DSSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isPressed ? theme.colors.textSecondary.opacity(0.1) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

#Preview {
    let budget = Budget.createSample()
    // Preview with mock data - would need ModelContext in real app
    let budgetManager = MockBudgetManager(budget: budget)
    
    VStack(spacing: DSSpacing.md) {
        CategoryExpendableCard(
            category: budget.categories.first!,
            budgetManager: budgetManager,
            isExpanded: false,
            onToggle: {},
            onEditTransaction: nil,
            onDeleteTransaction: nil
        )
        
        CategoryExpendableCard(
            category: budget.categories.first!,
            budgetManager: budgetManager,
            isExpanded: true,
            onToggle: {},
            onEditTransaction: { transaction in
                print("Edit transaction: \(transaction)")
            },
            onDeleteTransaction: { transaction in
                print("Delete transaction: \(transaction)")
            }
        )
    }
    .padding(DSSpacing.md)
    .background(AppTheme.shared.colors.background)
}
