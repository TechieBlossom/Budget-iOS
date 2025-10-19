import Foundation

@MainActor
class TrendsAnalyzer: ObservableObject {
    private let budgetManager: any BudgetManagerProtocol

    init(budgetManager: any BudgetManagerProtocol) {
        self.budgetManager = budgetManager
    }

    // MARK: - Public Interface

    func generateTrendData(for period: TrendPeriod) -> TrendData {
        // Only use transactions from current budget period
        let currentBudget = budgetManager.budget
        let currentBudgetTransactions = budgetManager.getAllTransactions()
        let categories = currentBudget.categories

        // Get current and previous period date ranges
        let currentRange = getCurrentPeriodRange(for: period)
        let previousRange = getPreviousPeriodRange(for: period)

        // Filter transactions for each period
        let currentTransactions = filterTransactions(currentBudgetTransactions, in: currentRange)
        let previousTransactions = filterTransactions(currentBudgetTransactions, in: previousRange)

        // Calculate totals
        let currentTotal = currentTransactions.map({ $0.amount }).reduce(0, +)
        let previousTotal = previousTransactions.map({ $0.amount }).reduce(0, +)

        // Generate category breakdown
        let categoryBreakdown = generateCategoryBreakdown(
            categories: categories,
            currentTransactions: currentTransactions,
            previousTransactions: previousTransactions
        )

        // Create comparison data
        let comparisonData = ComparisonData(current: currentTotal, previous: previousTotal)

        // Generate time series data (only from current budget)
        let timeSeriesData = generateTimeSeriesData(for: period, transactions: currentBudgetTransactions)

        return TrendData(
            period: period,
            totalSpent: currentTotal,
            categoryBreakdown: categoryBreakdown,
            comparisonData: comparisonData,
            timeSeriesData: timeSeriesData
        )
    }

    func generateMultiPeriodComparison() -> [TrendData] {
        return TrendPeriod.allCases.map { period in
            generateTrendData(for: period)
        }
    }

    // MARK: - Date Range Calculations

    private func getCurrentPeriodRange(for period: TrendPeriod) -> TrendDateRange {
        let calendar = Calendar.current
        let now = Date()

        switch period {
        case .weekly:
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? now
            return TrendDateRange(start: weekStart, end: weekEnd)

        case .monthly:
            let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? now
            return TrendDateRange(start: monthStart, end: monthEnd)

        case .quarterly:
            let quarter = calendar.component(.quarter, from: now)
            let year = calendar.component(.year, from: now)
            let quarterStart = calendar.date(from: DateComponents(year: year, month: (quarter - 1) * 3 + 1, day: 1)) ?? now
            let quarterEnd = calendar.date(byAdding: .month, value: 3, to: quarterStart) ?? now
            return TrendDateRange(start: quarterStart, end: quarterEnd)

        case .yearly:
            let yearStart = calendar.dateInterval(of: .year, for: now)?.start ?? now
            let yearEnd = calendar.date(byAdding: .year, value: 1, to: yearStart) ?? now
            return TrendDateRange(start: yearStart, end: yearEnd)
        }
    }

    private func getPreviousPeriodRange(for period: TrendPeriod) -> TrendDateRange {
        let calendar = Calendar.current
        let currentRange = getCurrentPeriodRange(for: period)

        let previousStart: Date
        let previousEnd: Date

        switch period {
        case .weekly:
            previousStart = calendar.date(byAdding: .weekOfYear, value: -1, to: currentRange.start) ?? currentRange.start
            previousEnd = calendar.date(byAdding: .weekOfYear, value: -1, to: currentRange.end) ?? currentRange.end

        case .monthly:
            previousStart = calendar.date(byAdding: .month, value: -1, to: currentRange.start) ?? currentRange.start
            previousEnd = calendar.date(byAdding: .month, value: -1, to: currentRange.end) ?? currentRange.end

        case .quarterly:
            previousStart = calendar.date(byAdding: .month, value: -3, to: currentRange.start) ?? currentRange.start
            previousEnd = calendar.date(byAdding: .month, value: -3, to: currentRange.end) ?? currentRange.end

        case .yearly:
            previousStart = calendar.date(byAdding: .year, value: -1, to: currentRange.start) ?? currentRange.start
            previousEnd = calendar.date(byAdding: .year, value: -1, to: currentRange.end) ?? currentRange.end
        }

        return TrendDateRange(start: previousStart, end: previousEnd)
    }

    // MARK: - Transaction Filtering

    private func filterTransactions(_ transactions: [Transaction], in range: TrendDateRange) -> [Transaction] {
        return transactions.filter { transaction in
            transaction.date >= range.start && transaction.date < range.end
        }
    }

    // MARK: - Category Analysis

    private func generateCategoryBreakdown(
        categories: [SubCategory],
        currentTransactions: [Transaction],
        previousTransactions: [Transaction]
    ) -> [CategoryTrend] {
        let budget = budgetManager.budget

        return categories.compactMap { category in
            let currentAmount = currentTransactions
                .filter { $0.categoryId == category.id }
                .map({ $0.amount })
                .reduce(0, +)

            let previousAmount = previousTransactions
                .filter { $0.categoryId == category.id }
                .map({ $0.amount })
                .reduce(0, +)

            let transactionCount = currentTransactions
                .filter { $0.categoryId == category.id }
                .count

            let budgetAmount = budget.categoryAmounts[category.id.uuidString] ?? 0

            // Only include categories with transactions or budget allocation
            if currentAmount > 0 || previousAmount > 0 || budgetAmount > 0 {
                return CategoryTrend(
                    subCategory: category,
                    currentAmount: currentAmount,
                    previousAmount: previousAmount,
                    transactionCount: transactionCount,
                    budgetAmount: budgetAmount
                )
            }
            return nil
        }
    }

    // MARK: - Time Series Generation

    private func generateTimeSeriesData(for period: TrendPeriod, transactions: [Transaction]) -> [PeriodDataPoint] {
        let calendar = Calendar.current
        let now = Date()

        // Determine how many periods to go back
        let periodsToShow: Int
        let component: Calendar.Component

        switch period {
        case .weekly:
            periodsToShow = 12 // 12 weeks
            component = .weekOfYear
        case .monthly:
            periodsToShow = 12 // 12 months
            component = .month
        case .quarterly:
            periodsToShow = 8 // 8 quarters (2 years)
            component = .quarter
        case .yearly:
            periodsToShow = 5 // 5 years
            component = .year
        }

        var dataPoints: [PeriodDataPoint] = []

        for i in (1...periodsToShow).reversed() {
            let periodStart: Date
            let periodEnd: Date

            switch period {
            case .weekly:
                let targetDate = calendar.date(byAdding: .weekOfYear, value: -i, to: now) ?? now
                let weekInterval = calendar.dateInterval(of: .weekOfYear, for: targetDate)
                periodStart = weekInterval?.start ?? targetDate
                periodEnd = weekInterval?.end ?? targetDate

            case .monthly:
                let targetDate = calendar.date(byAdding: .month, value: -i, to: now) ?? now
                let monthInterval = calendar.dateInterval(of: .month, for: targetDate)
                periodStart = monthInterval?.start ?? targetDate
                periodEnd = monthInterval?.end ?? targetDate

            case .quarterly:
                let targetDate = calendar.date(byAdding: .month, value: -i * 3, to: now) ?? now
                let quarter = calendar.component(.quarter, from: targetDate)
                let year = calendar.component(.year, from: targetDate)
                periodStart = calendar.date(from: DateComponents(year: year, month: (quarter - 1) * 3 + 1, day: 1)) ?? targetDate
                periodEnd = calendar.date(byAdding: .month, value: 3, to: periodStart) ?? targetDate

            case .yearly:
                let targetDate = calendar.date(byAdding: .year, value: -i, to: now) ?? now
                let yearInterval = calendar.dateInterval(of: .year, for: targetDate)
                periodStart = yearInterval?.start ?? targetDate
                periodEnd = yearInterval?.end ?? targetDate
            }

            // Filter transactions for this period
            let periodTransactions = transactions.filter { transaction in
                transaction.date >= periodStart && transaction.date < periodEnd
            }

            let totalAmount = periodTransactions.map({ $0.amount }).reduce(0, +)

            let dataPoint = PeriodDataPoint(
                date: periodStart,
                amount: totalAmount,
                transactionCount: periodTransactions.count,
                period: period
            )

            dataPoints.append(dataPoint)
        }

        return dataPoints
    }

}

// MARK: - Date Range Helper
private struct TrendDateRange {
    let start: Date
    let end: Date
}