import Foundation
import SwiftUI

// MARK: - Trend Period
enum TrendPeriod: CaseIterable, Hashable {
    case weekly
    case monthly
    case quarterly
    case yearly

    var displayName: String {
        switch self {
        case .weekly:
            return "Weekly"
        case .monthly:
            return "Monthly"
        case .quarterly:
            return "Quarterly"
        case .yearly:
            return "Yearly"
        }
    }

    var shortName: String {
        switch self {
        case .weekly:
            return "Week"
        case .monthly:
            return "Month"
        case .quarterly:
            return "Quarter"
        case .yearly:
            return "Year"
        }
    }
}

// MARK: - Trend Direction
enum TrendDirection: Hashable {
    case increasing(Double)
    case decreasing(Double)
    case stable

    var isPositive: Bool {
        switch self {
        case .decreasing:
            return true // Decreasing spending is positive
        case .increasing:
            return false
        case .stable:
            return true
        }
    }

    var percentage: Double {
        switch self {
        case .increasing(let percent):
            return percent
        case .decreasing(let percent):
            return percent
        case .stable:
            return 0.0
        }
    }

    var symbol: String {
        switch self {
        case .increasing:
            return "↗"
        case .decreasing:
            return "↘"
        case .stable:
            return "→"
        }
    }
}

// MARK: - Category Trend
struct CategoryTrend: Identifiable, Hashable {
    let id = UUID()
    let subCategory: SubCategory
    let currentAmount: Double
    let previousAmount: Double
    let changePercentage: Double
    let trend: TrendDirection
    let transactionCount: Int
    let budgetAmount: Double

    init(subCategory: SubCategory, currentAmount: Double, previousAmount: Double, transactionCount: Int, budgetAmount: Double = 0) {
        self.subCategory = subCategory
        self.currentAmount = currentAmount
        self.previousAmount = previousAmount
        self.transactionCount = transactionCount
        self.budgetAmount = budgetAmount

        if previousAmount == 0 {
            self.changePercentage = currentAmount > 0 ? 100.0 : 0.0
            self.trend = currentAmount > 0 ? .increasing(100.0) : .stable
        } else {
            let change = ((currentAmount - previousAmount) / previousAmount) * 100
            self.changePercentage = abs(change)

            if abs(change) < 5.0 {
                self.trend = .stable
            } else if change > 0 {
                self.trend = .increasing(abs(change))
            } else {
                self.trend = .decreasing(abs(change))
            }
        }
    }

    var budgetUtilization: Double {
        guard budgetAmount > 0 else { return 0 }
        return (currentAmount / budgetAmount) * 100
    }

    var isOverBudget: Bool {
        budgetUtilization > 100
    }
}

// MARK: - Comparison Data
struct ComparisonData: Hashable {
    let currentPeriodTotal: Double
    let previousPeriodTotal: Double
    let changeAmount: Double
    let changePercentage: Double
    let trend: TrendDirection

    init(current: Double, previous: Double) {
        self.currentPeriodTotal = current
        self.previousPeriodTotal = previous
        self.changeAmount = current - previous

        if previous == 0 {
            self.changePercentage = current > 0 ? 100.0 : 0.0
            self.trend = current > 0 ? .increasing(100.0) : .stable
        } else {
            let change = ((current - previous) / previous) * 100
            self.changePercentage = abs(change)

            if abs(change) < 2.0 {
                self.trend = .stable
            } else if change > 0 {
                self.trend = .increasing(abs(change))
            } else {
                self.trend = .decreasing(abs(change))
            }
        }
    }
}

// MARK: - Period Data Point
struct PeriodDataPoint: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let amount: Double
    let label: String
    let transactionCount: Int
    let period: TrendPeriod

    init(date: Date, amount: Double, transactionCount: Int, period: TrendPeriod) {
        self.date = date
        self.amount = amount
        self.transactionCount = transactionCount
        self.period = period

        let formatter = DateFormatter()
        switch period {
        case .weekly:
            formatter.dateFormat = "MMM d"
        case .monthly:
            formatter.dateFormat = "MMM yyyy"
        case .quarterly:
            formatter.dateFormat = "Q'q' yyyy"
        case .yearly:
            formatter.dateFormat = "yyyy"
        }
        self.label = formatter.string(from: date)
    }
}

// MARK: - Main Trend Data
struct TrendData: Hashable {
    let period: TrendPeriod
    let totalSpent: Double
    let categoryBreakdown: [CategoryTrend]
    let comparisonData: ComparisonData
    let timeSeriesData: [PeriodDataPoint]
    let averagePerPeriod: Double
    let highestSpendingPeriod: PeriodDataPoint?
    let lowestSpendingPeriod: PeriodDataPoint?

    init(
        period: TrendPeriod,
        totalSpent: Double,
        categoryBreakdown: [CategoryTrend],
        comparisonData: ComparisonData,
        timeSeriesData: [PeriodDataPoint]
    ) {
        self.period = period
        self.totalSpent = totalSpent
        self.categoryBreakdown = categoryBreakdown.sorted { $0.currentAmount > $1.currentAmount }
        self.comparisonData = comparisonData
        self.timeSeriesData = timeSeriesData.sorted { $0.date < $1.date }

        // Calculate statistics
        let totalCount = timeSeriesData.count
        self.averagePerPeriod = totalCount > 0 ? timeSeriesData.map({ $0.amount }).reduce(0, +) / Double(totalCount) : 0

        self.highestSpendingPeriod = timeSeriesData.max { $0.amount < $1.amount }
        self.lowestSpendingPeriod = timeSeriesData.min { $0.amount < $1.amount }
    }

    var topSpendingCategories: [CategoryTrend] {
        Array(categoryBreakdown.prefix(5))
    }

    var budgetPerformance: [CategoryTrend] {
        categoryBreakdown.filter { $0.budgetAmount > 0 }
    }

    var totalTransactions: Int {
        categoryBreakdown.map(\.transactionCount).reduce(0, +)
    }
}

// MARK: - Chart Data Helpers
extension TrendData {

    struct ChartDataPoint: Identifiable, Hashable {
        let id = UUID()
        let x: Double
        let y: Double
        let label: String
        let color: Color

        init(index: Int, amount: Double, label: String, color: Color = .blue) {
            self.x = Double(index)
            self.y = amount
            self.label = label
            self.color = color
        }

        static func == (lhs: ChartDataPoint, rhs: ChartDataPoint) -> Bool {
            lhs.id == rhs.id
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    var chartData: [ChartDataPoint] {
        timeSeriesData.enumerated().map { index, dataPoint in
            ChartDataPoint(
                index: index,
                amount: dataPoint.amount,
                label: dataPoint.label
            )
        }
    }

    var categoryChartData: [ChartDataPoint] {
        topSpendingCategories.enumerated().map { index, categoryTrend in
            ChartDataPoint(
                index: index,
                amount: categoryTrend.currentAmount,
                label: categoryTrend.subCategory.name,
                color: categoryTrend.subCategory.categoryGroup.color
            )
        }
    }
}