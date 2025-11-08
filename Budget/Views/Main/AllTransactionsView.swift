import SwiftUI

struct AllTransactionsView: View {
    let budgetManager: any BudgetManagerProtocol
    var isReadOnly: Bool = false  // Flag for historical budget read-only mode
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @State private var transactionToEdit: Transaction?
    @StateObject private var searchManager = SearchManager()
    @State private var notificationManager = NotificationManager()
    @State private var showFilterSheet = false
    @State private var showAddTransaction = false
    @State private var searchText = ""

    private var allTransactions: [Transaction] {
        budgetManager.getAllTransactions()
    }

    private var filteredTransactions: [Transaction] {
        searchManager.filterTransactions(allTransactions, categories: budgetManager.budget.categories)
    }

    private var transactionsByDate: [(Date, [Transaction])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredTransactions.sorted { $0.date > $1.date }) { tx in
            calendar.startOfDay(for: tx.date)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    private var hasActiveFilters: Bool {
        // your logic (I think you meant “has filters & query nonempty”)
        return searchManager.searchCriteria.hasActiveFilters && !searchManager.searchCriteria.query.isEmpty
    }

    private var activeFilterPills: [FilterPillData] {
        searchManager.getActiveFilterPills(categories: budgetManager.budget.categories)
    }

    private var filteredTotal: Double {
        searchManager.calculateFilteredTotal(filteredTransactions)
    }

    private var totalAmount: Double {
        searchManager.calculateFilteredTotal(allTransactions)
    }

    var body: some View {
        // *Do not* wrap in another NavigationStack here if the parent already has a NavigationStack.
        // Just assume this view is inside a NavigationStack.
        VStack(spacing: 0) {
            // Subtitle & filter pills & summary — same as before
            if hasActiveFilters {
                HStack {
                    DSText(
                        "\(filteredTransactions.count) of \(allTransactions.count) transactions",
                        font: .dsCaption,
                        color: theme.colors.textSecondary
                    )
                    Spacer()
                }
                .padding(.horizontal, DSSpacing.md)
                .padding(.top, DSSpacing.xs)
                .padding(.bottom, DSSpacing.xxs)
            }

            if !activeFilterPills.isEmpty {
                DSActiveFilterPillsView(
                    filters: activeFilterPills,
                    onRemoveFilter: { pillId in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            HapticManager.shared.lightImpact()
                            searchManager.removeFilterPill(pillId, categories: budgetManager.budget.categories)
                        }
                    },
                    onClearAll: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            HapticManager.shared.lightImpact()
                            searchManager.clearSearch()
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
            
            
            // Always show summary card
            if !transactionsByDate.isEmpty {
                DSFilterSummaryCard(
                    filteredAmount: filteredTotal,
                    filteredCount: filteredTransactions.count,
                    totalAmount: totalAmount,
                    totalCount: allTransactions.count,
                    currencyCode: budgetManager.budget.currency.code
                )
                .padding(.vertical, DSSpacing.md)
                .padding(.horizontal, DSSpacing.md)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .scale(scale: 0.95).combined(with: .opacity)
                ))
            }
            
            Spacer()

            if transactionsByDate.isEmpty {
                VStack(spacing: DSSpacing.md) {
                    Image(systemName: searchManager.searchCriteria.hasActiveFilters ? "magnifyingglass" : "doc.text")
                        .font(.dsLargeTitle)
                        .foregroundColor(theme.colors.textSecondary)

                    DSText(
                        searchManager.searchCriteria.hasActiveFilters ? "No Results Found" : "No Transactions",
                        font: .dsHeadline,
                        color: theme.colors.textPrimary
                    )

                    DSText(
                        searchManager.searchCriteria.hasActiveFilters
                            ? "Try adjusting your search or filters"
                            : "Start adding expenses to see them here",
                        font: .dsBody,
                        color: theme.colors.textSecondary
                    )
                    .multilineTextAlignment(.center)

                    if searchManager.searchCriteria.hasActiveFilters {
                        DSButton("Clear Filters", style: .outline) {
                            searchManager.clearSearch()
                            searchText = ""
                        }
                    }
                }
                .padding(.horizontal, DSSpacing.xxl)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(transactionsByDate, id: \.0) { date, transactions in
                            TransactionDateSection(
                                date: date,
                                transactions: transactions,
                                budgetManager: budgetManager,
                                onEditTransaction: isReadOnly ? nil : { tx in
                                    transactionToEdit = tx
                                }
                            )
                        }
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 20)
                    }
                }
            }
        }
        .background(theme.colors.background)
        .navigationTitle("All Transactions")
        .navigationBarTitleDisplayMode(.inline)
        .customNavigationBarAppearance()
        .toolbar {
            // Top-right filter button
            ToolbarItem(placement: .topBarTrailing) {
                ZStack {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.dsHeadline)
                        .foregroundColor(hasActiveFilters ? theme.colors.primary : theme.colors.textPrimary)
                    if !activeFilterPills.isEmpty {
                        Circle()
                            .fill(theme.colors.primary)
                            .frame(width: 12, height: 12)
                            .overlay(
                                DSText("\(activeFilterPills.count)", font: .dsCaption, color: .white)
                                    .fontWeight(.bold)
                            )
                            .offset(x: 6, y: -6)
                    }
                }
                .onTapGesture {
                    HapticManager.shared.lightImpact()
                    showFilterSheet = true
                }
            }

            // Bottom toolbar: search + add button
            if #available(iOS 26.0, *) {
                DefaultToolbarItem(kind: .search, placement: .bottomBar)
                ToolbarSpacer(.flexible, placement: .bottomBar)
            }
            // Only show add button if not in read-only mode
            if !isReadOnly {
                ToolbarItem(placement: .bottomBar) {
                    Image(systemName: "plus.circle")
                        .font(.dsHeadline)
                        .foregroundColor(hasActiveFilters ? theme.colors.primary : theme.colors.textPrimary)
                        .onTapGesture {
                            HapticManager.shared.lightImpact()
                            showAddTransaction = true
                        }
                }
            }
        }
        .searchable(
            text: $searchText,
            placement: .toolbar,
            prompt: "Search transactions and categories"
        )
        .onChange(of: searchText) { _, newValue in
            searchManager.searchCriteria.query = newValue
        }
        .onChange(of: searchManager.searchCriteria.query) { newQuery in
            // keep searchText in sync if filters reset it
            if newQuery != searchText {
                searchText = newQuery
            }
        }
        .snackbar(notificationManager)
        .sheet(isPresented: $showFilterSheet) {
            DSFilterModalSheet(
                searchCriteria: $searchManager.searchCriteria,
                categories: budgetManager.budget.categories,
                onApply: {
                    HapticManager.shared.success()
                },
                onClearAll: {
                    HapticManager.shared.lightImpact()
                    searchManager.clearSearch()
                    searchText = ""
                }
            )
        }
        .fullScreenCover(isPresented: $showAddTransaction) {
            AddTransactionSheet(
                budgetId: budgetManager.budget.id,
                categories: budgetManager.budget.categories,
                currency: budgetManager.budget.currency,
                budgetPeriod: budgetManager.budget.period,
                budgetName: budgetManager.budget.budgetName,
                categoryAmounts: budgetManager.budget.categoryAmounts,
                existingTransaction: nil,
                budgetManager: budgetManager,
                onSuccess: {
                    HapticManager.shared.transactionAdded()
                    notificationManager.showSuccess("Transaction added successfully!")
                    showAddTransaction = false
                }
            )
        }
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


struct TransactionDateSection: View {
    let date: Date
    let transactions: [Transaction]
    let budgetManager: any BudgetManagerProtocol
    let onEditTransaction: ((Transaction) -> Void)?  // Optional for read-only mode
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
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            // Date header
            VStack(spacing: DSSpacing.xs) {
                HStack {
                    DSText(dateFormatter.string(from: date), font: .dsBody, color: theme.colors.textPrimary)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    DSText(String(format: "%.2f", dayTotal), font: .dsBody, color: theme.colors.textSecondary)
                }
                
                Divider()
                    .background(theme.colors.divider)
            }
            .padding(.horizontal, DSSpacing.md)
            
            // Transactions for this date
            VStack(spacing: DSSpacing.xs) {
                ForEach(transactions) { transaction in
                    TransactionRowView(
                        transaction: transaction,
                        budgetManager: budgetManager,
                        onEditTransaction: onEditTransaction != nil ? {
                            onEditTransaction?(transaction)
                        } : nil
                    )
                    .padding(.horizontal, DSSpacing.md)
                }
            }
        }
        .padding(.bottom, DSSpacing.xl)
    }
}

struct TransactionRowView: View {
    let transaction: Transaction
    let budgetManager: any BudgetManagerProtocol
    let onEditTransaction: (() -> Void)?
    @Environment(\.appTheme) private var theme

    private var subCategory: SubCategory? {
        budgetManager.budget.categories.first { $0.id == transaction.categoryId }
    }


    var body: some View {
        let content = HStack(spacing: 0) {
            // Color Border (like expandable card)
            Rectangle()
                .fill(subCategory?.categoryGroup.color ?? theme.colors.textSecondary)
                .frame(width: 8)
                .cornerRadius(8, corners: [.topLeft, .bottomLeft])

            VStack(spacing: DSSpacing.xs) {
                // Transaction header
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                        DSText(transaction.name.isEmpty ? "Expense" : transaction.name, font: .dsHeadline, color: theme.colors.textPrimary)
                            .lineLimit(1)
                            .onAppear {
                                print("🔍 Displaying transaction: ID=\(transaction.id), Name='\(transaction.name)', isEmpty=\(transaction.name.isEmpty)")
                            }
                        HStack(spacing: DSSpacing.xxs) {
                            DSText(subCategory?.name ?? "Unknown", font: .dsCaption, color: theme.colors.textSecondary)
                            if let subCategory = subCategory {
                                DSText("•", font: .dsCaption, color: theme.colors.textSecondary)
                                DSText(subCategory.categoryGroup.displayName, font: .dsCaption, color: theme.colors.textSecondary)
                            }
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: DSSpacing.xxs) {
                        DSText(String(format: "%.2f", transaction.amount), font: .dsBody, color: theme.colors.textPrimary)
                            .fontWeight(.medium)
                        DSText(budgetManager.budget.currency.code, font: .dsCaption, color: theme.colors.textSecondary)
                    }
                }
            }
            .padding(.horizontal, DSSpacing.md)
            .padding(.vertical, DSSpacing.md)
        }
        .background(theme.colors.surface)
        .cornerRadius(8)

        // Conditionally wrap in button or return content directly
        if let editAction = onEditTransaction {
            Button(action: editAction) {
                content
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            content
        }
    }
}

#Preview {
    AllTransactionsView(budgetManager: MockBudgetManager(budget: Budget.createSample()))
        .background(AppTheme.shared.colors.background)
}
