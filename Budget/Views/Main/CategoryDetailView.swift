import SwiftUI

struct CategoryDetailView: View {
    let category: SubCategory
    let budgetManager: any BudgetManagerProtocol
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @State private var transactionToEdit: Transaction?
    @State private var notificationManager = NotificationManager()
    @State private var animatedSpentPercentage: Double = 0

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

    private var actualSpentPercentage: Double {
        guard allocatedAmount > 0 else { return 0 }
        return (spentAmount / allocatedAmount)
    }

    private var categoryTransactions: [Transaction] {
        budgetManager.getAllTransactions().filter { $0.categoryId == category.id }
    }

    private var transactionsByDate: [(Date, [Transaction])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: categoryTransactions.sorted { $0.date > $1.date }) { tx in
            calendar.startOfDay(for: tx.date)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: DSSpacing.xl) {
                    // Top spacing
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 8)

                    // Category Overview Card
                    DSCard(padding: 0) {
                        GeometryReader { cardGeometry in
                            VStack(spacing: 0) {
                                // Main content area
                                HStack(spacing: DSSpacing.md) {
                                    // Left section - Category budget info
                                    VStack(alignment: .leading, spacing: DSSpacing.md) {
                                        // Allocated Budget - Large and prominent
                                        VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                                            DSText("Allocated", font: .dsBody, color: theme.colors.textSecondary)
                                            DSText(String(format: "%.2f", allocatedAmount), font: .dsLargeTitle, color: theme.colors.textPrimary)
                                                .fontWeight(.bold)
                                        }

                                        // Spent and Remaining
                                        HStack(spacing: DSSpacing.xl) {
                                            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                                                DSText("Spent", font: .dsCaption, color: theme.colors.textSecondary)
                                                DSText(String(format: "%.2f", spentAmount), font: .dsHeadline, color: theme.colors.textPrimary)
                                                    .fontWeight(.medium)
                                            }

                                            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                                                DSText("Remaining", font: .dsCaption, color: theme.colors.textSecondary)
                                                DSText(String(format: "%.2f", remainingAmount), font: .dsHeadline, color: theme.colors.textPrimary)
                                                    .fontWeight(.medium)
                                            }
                                        }
                                    }

                                    Spacer()

                                    // Right section - Circular progress
                                    VStack(spacing: DSSpacing.xs) {
                                        ZStack {
                                            // Background circle
                                            Circle()
                                                .stroke(theme.colors.textSecondary.opacity(0.2), lineWidth: 8)
                                                .frame(width: 80, height: 80)

                                            // Progress circle
                                            Circle()
                                                .trim(from: 0, to: min(1.0, animatedSpentPercentage))
                                                .stroke(
                                                    category.categoryGroup.color,
                                                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                                )
                                                .frame(width: 80, height: 80)
                                                .rotationEffect(.degrees(-90))
                                                .animation(.easeInOut(duration: 1.2), value: animatedSpentPercentage)

                                            // Percentage text in center
                                            DSText("\(Int(actualSpentPercentage * 100))%", font: .dsTitle, color: theme.colors.textPrimary)
                                                .fontWeight(.bold)
                                                .animation(.easeInOut(duration: 0.8), value: actualSpentPercentage)
                                        }

                                        DSText("spent in\n\(categoryTransactions.count) transactions", font: .dsCaption, color: theme.colors.textSecondary)
                                            .multilineTextAlignment(.center)
                                    }
                                }
                                .padding(.horizontal, DSSpacing.lg)
                                .padding(.top, DSSpacing.lg)
                            }
                        }
                        .frame(height: 160)
                    }
                    .padding(.horizontal, DSSpacing.md)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.2).delay(0.3)) {
                            animatedSpentPercentage = actualSpentPercentage
                        }
                    }
                    .onChange(of: actualSpentPercentage) { _, newValue in
                        withAnimation(.easeInOut(duration: 0.8)) {
                            animatedSpentPercentage = newValue
                        }
                    }

                    // Transactions Section
                    VStack(alignment: .leading, spacing: DSSpacing.md) {
                        HStack {
                            DSText("Transactions", font: .dsSmallTitle, color: theme.colors.textPrimary)
                            Spacer()
                            DSText("\(categoryTransactions.count)", font: .dsBody, color: theme.colors.textSecondary)
                        }
                        .padding(.horizontal, DSSpacing.md)

                        if transactionsByDate.isEmpty {
                            // Empty state
                            VStack(spacing: DSSpacing.md) {
                                Image(systemName: "doc.text")
                                    .font(.dsLargeTitle)
                                    .foregroundColor(theme.colors.textSecondary)

                                DSText("No Transactions", font: .dsHeadline, color: theme.colors.textPrimary)

                                DSText("Start adding expenses to this category", font: .dsBody, color: theme.colors.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, 40)
                            .frame(maxWidth: .infinity)
                        } else {
                            // Transactions list
                            LazyVStack(spacing: 0) {
                                ForEach(transactionsByDate, id: \.0) { date, transactions in
                                    TransactionDateSection(
                                        date: date,
                                        transactions: transactions,
                                        budgetManager: budgetManager,
                                        onEditTransaction: { tx in
                                            transactionToEdit = tx
                                        }
                                    )
                                }
                            }
                        }
                    }

                    // Bottom spacing
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 20)
                }
            }
        }
        .background(theme.colors.background)
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
        .customNavigationBarAppearance()
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    DSText(category.name, font: .dsBody, color: theme.colors.textPrimary)
                        .fontWeight(.semibold)
                    DSText(category.categoryGroup.displayName, font: .dsCaption, color: theme.colors.textSecondary)
                }
            }
        }
        .snackbar(notificationManager)
        .fullScreenCover(item: $transactionToEdit) { tx in
            AddTransactionSheet(
                budgetId: budgetManager.budget.id,
                categories: budgetManager.budget.categories,
                currency: budgetManager.budget.currency,
                budgetPeriod: budgetManager.budget.period,
                budgetName: budgetManager.budget.budgetName,
                categoryAmounts: budgetManager.budget.categoryAmounts,
                existingTransaction: tx,
                budgetManager: budgetManager,
                onSuccess: {
                    HapticManager.shared.success()
                    notificationManager.showSuccess("Transaction updated successfully!")
                    transactionToEdit = nil
                }
            )
        }
    }
}

#Preview {
    let budget = Budget.createSample()
    let budgetManager = MockBudgetManager(budget: budget)

    CategoryDetailView(
        category: budget.categories.first!,
        budgetManager: budgetManager
    )
    .background(AppTheme.shared.colors.background)
}
