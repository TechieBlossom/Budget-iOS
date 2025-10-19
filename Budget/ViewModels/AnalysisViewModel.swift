import Foundation

@MainActor
class AnalysisViewModel: ObservableObject {
    private let budgetManager: any BudgetManagerProtocol

    @Published var selectedPeriod: AnalysisPeriod = .monthly
    @Published var isLoading = false

    // Computed analysis data
    @Published var spendingTrends: [PeriodDataPoint] = []
    @Published var budgetPerformance: BudgetPerformanceSummary?
    @Published var categoryComparison: [CategoryComparisonData] = []
    @Published var dailySpendingPattern: DailySpendingPattern?

    init(budgetManager: any BudgetManagerProtocol) {
        self.budgetManager = budgetManager
    }

    // MARK: - Public Interface

    func loadAnalysisData() {
        isLoading = true

        // Get all transactions across all budgets
        let allTransactions = budgetManager.getAllTransactionsAcrossAllBudgets()
        let allBudgets = budgetManager.getAllBudgetsSorted()

        // Calculate each analysis component
        spendingTrends = calculateSpendingTrends(transactions: allTransactions, budgets: allBudgets)
        budgetPerformance = calculateBudgetPerformance(budgets: allBudgets, transactions: allTransactions)
        categoryComparison = calculateCategoryComparison(transactions: allTransactions, budgets: allBudgets)
        dailySpendingPattern = calculateDailySpendingPattern(transactions: allTransactions)

        isLoading = false
    }

    // MARK: - Spending Trends Calculation

    private func calculateSpendingTrends(transactions: [Transaction], budgets: [Budget]) -> [PeriodDataPoint] {
        switch selectedPeriod {
        case .weekly:
            return calculateDailyTrends(transactions: transactions, daysBack: 7)
        case .monthly:
            return calculateDailyTrends(transactions: transactions, daysBack: 30)
        case .sixMonths:
            return calculateSixMonthTrends(transactions: transactions)
        }
    }

    private func calculateDailyTrends(transactions: [Transaction], daysBack: Int) -> [PeriodDataPoint] {
        let calendar = Calendar.current
        let now = Date()

        // Get start date (daysBack days ago)
        let startDate = calendar.date(byAdding: .day, value: -daysBack + 1, to: now) ?? now
        let startOfStartDate = calendar.startOfDay(for: startDate)

        // Filter transactions within period
        let filteredTransactions = transactions.filter { $0.date >= startOfStartDate }

        // Group by day
        var dailyData: [Date: (amount: Double, count: Int)] = [:]

        for transaction in filteredTransactions {
            let dayStart = calendar.startOfDay(for: transaction.date)
            let existing = dailyData[dayStart] ?? (0, 0)
            dailyData[dayStart] = (existing.amount + transaction.amount, existing.count + 1)
        }

        // Create data points for all days in range (including zero days)
        var dataPoints: [PeriodDataPoint] = []
        var currentDate = startOfStartDate

        // Determine period based on daysBack
        let periodType: TrendPeriod = daysBack == 7 ? .weekly : .monthly

        while currentDate <= calendar.startOfDay(for: now) {
            let data = dailyData[currentDate] ?? (0, 0)

            dataPoints.append(PeriodDataPoint(
                date: currentDate,
                amount: data.amount,
                transactionCount: data.count,
                period: periodType
            ))

            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }

        // Return in natural chronological order (oldest to newest)
        return dataPoints.sorted { $0.date < $1.date }
    }

    private func calculateSixMonthTrends(transactions: [Transaction]) -> [PeriodDataPoint] {
        let calendar = Calendar.current
        let now = Date()

        // Get the first day of current month
        let currentMonthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now

        // Go back 5 months (so 6 months total including current)
        let startDate = calendar.date(byAdding: .month, value: -5, to: currentMonthStart) ?? now

        // Filter transactions within period
        let filteredTransactions = transactions.filter { $0.date >= startDate }

        // Group by month
        var monthlyData: [Date: (amount: Double, count: Int)] = [:]

        for transaction in filteredTransactions {
            let monthStart = calendar.dateInterval(of: .month, for: transaction.date)?.start ?? transaction.date
            let existing = monthlyData[monthStart] ?? (0, 0)
            monthlyData[monthStart] = (existing.amount + transaction.amount, existing.count + 1)
        }

        // Create data points for all 6 months (including current)
        var dataPoints: [PeriodDataPoint] = []
        var currentDate = startDate

        for _ in 0..<6 {
            let monthStart = calendar.dateInterval(of: .month, for: currentDate)?.start ?? currentDate
            let data = monthlyData[monthStart] ?? (0, 0)

            dataPoints.append(PeriodDataPoint(
                date: monthStart,
                amount: data.amount,
                transactionCount: data.count,
                period: .monthly
            ))

            currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
        }

        // Return in natural chronological order (oldest to newest)
        return dataPoints.sorted { $0.date < $1.date }
    }

    // MARK: - Budget Performance Calculation

    private func calculateBudgetPerformance(budgets: [Budget], transactions: [Transaction]) -> BudgetPerformanceSummary {
        guard !budgets.isEmpty else {
            return BudgetPerformanceSummary(
                totalBudgetsCreated: 0,
                averageUtilization: 0,
                mostOverBudgetCategory: nil,
                bestPerformingBudget: nil
            )
        }

        // Calculate utilization for each budget
        var budgetUtilizations: [(Budget, Double)] = []
        var categoryOverBudgetCounts: [String: Int] = [:]

        for budget in budgets {
            let budgetTransactions = transactions.filter { transaction in
                transaction.date >= budget.period.startDate && transaction.date <= budget.period.endDate
            }

            let totalSpent = budgetTransactions.reduce(0) { $0 + $1.amount }
            let utilization = budget.totalAmount > 0 ? totalSpent / budget.totalAmount : 0
            budgetUtilizations.append((budget, utilization))

            // Track over-budget categories
            for category in budget.categories {
                let categorySpent = budgetTransactions
                    .filter { $0.categoryId == category.id }
                    .reduce(0) { $0 + $1.amount }

                let allocated = budget.categoryAmounts[category.id.uuidString] ?? 0
                if categorySpent > allocated && allocated > 0 {
                    categoryOverBudgetCounts[category.name, default: 0] += 1
                }
            }
        }

        let avgUtilization = budgetUtilizations.map(\.1).reduce(0, +) / Double(budgets.count)

        // Find most over-budget category
        let mostOverBudget = categoryOverBudgetCounts.max { $0.value < $1.value }

        // Find best performing budget (closest to 100% without going over)
        let bestBudget = budgetUtilizations
            .filter { $0.1 <= 1.0 }
            .max { abs($0.1 - 1.0) > abs($1.1 - 1.0) }

        return BudgetPerformanceSummary(
            totalBudgetsCreated: budgets.count,
            averageUtilization: avgUtilization,
            mostOverBudgetCategory: mostOverBudget?.key,
            bestPerformingBudget: bestBudget?.0
        )
    }

    // MARK: - Category Comparison Calculation

    private func calculateCategoryComparison(transactions: [Transaction], budgets: [Budget]) -> [CategoryComparisonData] {
        // Get all unique categories across all budgets
        var categoryTotals: [String: (UUID, Double, CategoryGroup)] = [:]

        for transaction in transactions {
            // Find sub-category from budgets
            if let subCategory = budgets.flatMap(\.categories).first(where: { $0.id == transaction.categoryId }) {
                let existing = categoryTotals[subCategory.name] ?? (subCategory.id, 0, subCategory.categoryGroup)
                categoryTotals[subCategory.name] = (existing.0, existing.1 + transaction.amount, subCategory.categoryGroup)
            }
        }

        // Convert to CategoryComparisonData and sort by amount
        return categoryTotals.map { name, data in
            CategoryComparisonData(
                categoryId: data.0,
                categoryName: name,
                categoryGroup: data.2,
                totalSpent: data.1,
                transactionCount: transactions.filter { transaction in
                    budgets.flatMap(\.categories).first(where: { $0.id == transaction.categoryId })?.name == name
                }.count
            )
        }
        .sorted { $0.totalSpent > $1.totalSpent }
        .prefix(8) // Top 8 sub-categories
        .map { $0 }
    }

    // MARK: - Daily Spending Pattern Calculation

    private func calculateDailySpendingPattern(transactions: [Transaction]) -> DailySpendingPattern {
        guard !transactions.isEmpty else {
            return DailySpendingPattern(
                averageDailySpending: 0,
                trendPercentage: 0,
                dayOfWeekBreakdown: [:],
                isIncreasing: false
            )
        }

        let calendar = Calendar.current
        let now = Date()

        // Calculate current period (last 30 days)
        let currentPeriodStart = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        let currentTransactions = transactions.filter { $0.date >= currentPeriodStart }

        // Calculate previous period (30 days before that)
        let previousPeriodStart = calendar.date(byAdding: .day, value: -60, to: now) ?? now
        let previousTransactions = transactions.filter {
            $0.date >= previousPeriodStart && $0.date < currentPeriodStart
        }

        let currentAvg = currentTransactions.isEmpty ? 0 :
            currentTransactions.reduce(0) { $0 + $1.amount } / 30.0

        let previousAvg = previousTransactions.isEmpty ? 0 :
            previousTransactions.reduce(0) { $0 + $1.amount } / 30.0

        let trendPercentage = previousAvg > 0 ? ((currentAvg - previousAvg) / previousAvg) * 100 : 0

        // Calculate day-of-week breakdown
        var dayOfWeekTotals: [Int: (amount: Double, count: Int)] = [:]

        for transaction in currentTransactions {
            let weekday = calendar.component(.weekday, from: transaction.date)
            let existing = dayOfWeekTotals[weekday] ?? (0, 0)
            dayOfWeekTotals[weekday] = (existing.amount + transaction.amount, existing.count + 1)
        }

        let dayOfWeekBreakdown = dayOfWeekTotals.mapValues { $0.count > 0 ? $0.amount / Double($0.count) : 0 }

        return DailySpendingPattern(
            averageDailySpending: currentAvg,
            trendPercentage: trendPercentage,
            dayOfWeekBreakdown: dayOfWeekBreakdown,
            isIncreasing: trendPercentage > 0
        )
    }

}

// MARK: - Supporting Types

enum AnalysisPeriod: String, CaseIterable {
    case weekly = "W"
    case monthly = "M"
    case sixMonths = "6M"

    var displayName: String {
        switch self {
        case .weekly: return "This Week"
        case .monthly: return "This Month"
        case .sixMonths: return "Last 6 Months"
        }
    }
}

struct BudgetPerformanceSummary {
    let totalBudgetsCreated: Int
    let averageUtilization: Double
    let mostOverBudgetCategory: String?
    let bestPerformingBudget: Budget?
}

struct CategoryComparisonData: Identifiable {
    let id = UUID()
    let categoryId: UUID
    let categoryName: String
    let categoryGroup: CategoryGroup
    let totalSpent: Double
    let transactionCount: Int
}

struct DailySpendingPattern {
    let averageDailySpending: Double
    let trendPercentage: Double
    let dayOfWeekBreakdown: [Int: Double] // Weekday (1=Sunday) -> Average spending
    let isIncreasing: Bool

    func averageForWeekday(_ weekday: Int) -> Double {
        return dayOfWeekBreakdown[weekday] ?? 0
    }

    var weekdayNames: [String] {
        return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    }
}
