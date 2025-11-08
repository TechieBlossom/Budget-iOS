import SwiftUI

// MARK: - Period Selector
struct AnalysisPeriodSelector: View {
    @Binding var selectedPeriod: AnalysisPeriod
    let onPeriodChanged: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: DSSpacing.xs) {
            ForEach(AnalysisPeriod.allCases, id: \.self) { period in
                Button(action: {
                    selectedPeriod = period
                    HapticManager.shared.buttonTap()
                    onPeriodChanged()
                }) {
                    DSText(
                        period.rawValue,
                        font: .dsBody,
                        color: selectedPeriod == period ? theme.colors.background : theme.colors.textPrimary
                    )
                    .fontWeight(.medium)
                    .padding(.vertical, DSSpacing.xs)
                    .padding(.horizontal, DSSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedPeriod == period ? theme.colors.textPrimary : theme.colors.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(theme.colors.textPrimary.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

// MARK: - Spending Trends Section
enum SpendingTrendsLabelMode {
    case percentage
    case amount
}

struct SpendingTrendsSection: View {
    let dataPoints: [PeriodDataPoint]
    let currency: Currency
    @Environment(\.appTheme) private var theme
    @State private var labelMode: SpendingTrendsLabelMode = .percentage

    private var maxAmount: Double {
        dataPoints.map(\.amount).max() ?? 1.0
    }

    private var totalSpending: Double {
        dataPoints.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            HStack {
                DSText("Spending Trends", font: .dsSmallTitle, color: theme.colors.textPrimary)
                Spacer()
            }

            // Stats and Label Toggle
            VStack(spacing: DSSpacing.md) {
                // Total spending stat with toggle button
                HStack {
                    VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                        DSText("Total Spending", font: .dsCaption, color: theme.colors.textSecondary)
                        DSText("\(currency.code) \(String(format: "%.0f", totalSpending))", font: .dsLargeTitle, color: theme.colors.textPrimary)
                            .fontWeight(.bold)
                    }

                    Spacer()

                    // Label mode toggle button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            labelMode = labelMode == .percentage ? .amount : .percentage
                        }
                        HapticManager.shared.buttonTap()
                    }) {
                        HStack(spacing: DSSpacing.xs) {
                            Image(systemName: labelMode == .percentage ? "percent" : "dollarsign.circle")
                                .font(.dsSubtitle)
                                .fontWeight(.medium)
                            DSText(labelMode == .percentage ? "%" : currency.code, font: .dsCaption, color: theme.colors.background)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, DSSpacing.sm)
                        .padding(.vertical, DSSpacing.xs)
                        .background(theme.colors.textPrimary)
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            // Chart
            MonthlySpendingNormalizedChart(
                dataPoints: dataPoints,
                maxAmount: maxAmount,
                currency: currency,
                labelMode: labelMode
            )
        }
    }
}

// MARK: - Monthly Spending Charts

struct MonthlySpendingNormalizedChart: View {
    let dataPoints: [PeriodDataPoint]
    let maxAmount: Double
    let currency: Currency
    let labelMode: SpendingTrendsLabelMode
    @Environment(\.appTheme) private var theme
    @State private var showBars = false

    // Computed property to track when data changes
    private var period: TrendPeriod {
        dataPoints.first?.period ?? .weekly
    }

    var body: some View {
        VStack(spacing: 0) {
            if dataPoints.isEmpty || maxAmount == 0 {
                VStack(spacing: DSSpacing.sm) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.dsLargeTitle)
                        .foregroundColor(theme.colors.textSecondary.opacity(0.6))

                    VStack(spacing: DSSpacing.xxs) {
                        DSText("No spending data", font: .dsBody, color: theme.colors.textPrimary)
                            .fontWeight(.medium)
                        DSText("Add transactions to see trends", font: .dsCaption, color: theme.colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DSSpacing.xl)
            } else {
                VStack(spacing: DSSpacing.xs) {
                    // Bars only
                    GeometryReader { geometry in
                        HStack(alignment: .bottom, spacing: 1) {
                            ForEach(Array(dataPoints.enumerated()), id: \.offset) { index, dataPoint in
                                VerticalBarView(
                                    dataPoint: dataPoint,
                                    maxAmount: maxAmount,
                                    showBar: showBars,
                                    color: theme.colors.textPrimary,
                                    barWidth: calculateBarWidth(totalWidth: geometry.size.width, barCount: dataPoints.count)
                                )
                            }
                        }
                    }
                    .frame(height: 200)

                    // X-axis labels - aligned with bars
                    GeometryReader { geometry in
                        ZStack(alignment: .topLeading) {
                            ForEach(Array(visibleLabelIndices.enumerated()), id: \.offset) { _, labelIndex in
                                VStack(spacing: 2) {
                                    DSText(formatDateLabelLine1(dataPoints[labelIndex].date, period: dataPoints[labelIndex].period), font: .dsCaption, color: theme.colors.textPrimary)
                                        .fontWeight(.semibold)
                                        .lineLimit(1)
                                    DSText(formatDateLabelLine2(dataPoints[labelIndex].date, period: dataPoints[labelIndex].period), font: .dsCaption, color: theme.colors.textPrimary)
                                        .lineLimit(1)
                                }
                                .frame(width: 60)
                                .offset(x: calculateLabelOffset(
                                    labelIndex: labelIndex,
                                    totalWidth: geometry.size.width,
                                    barCount: dataPoints.count
                                ))
                            }
                        }
                    }
                    .frame(height: 40)
                }
                .onAppear {
                    showBars = false
                    withAnimation(.spring(response: 1.0, dampingFraction: 0.7).delay(0.2)) {
                        showBars = true
                    }
                }
                .onChange(of: period) { _, _ in
                    // Reset animation when period changes
                    showBars = false
                    withAnimation(.spring(response: 1.0, dampingFraction: 0.7).delay(0.2)) {
                        showBars = true
                    }
                }
                .onChange(of: dataPoints.count) { _, _ in
                    // Reset animation when data count changes
                    showBars = false
                    withAnimation(.spring(response: 1.0, dampingFraction: 0.7).delay(0.2)) {
                        showBars = true
                    }
                }
            }
        }
    }

    // Calculate which labels should be visible
    private var visibleLabelIndices: [Int] {
        guard !dataPoints.isEmpty else { return [] }

        let totalCount = dataPoints.count
        let period = dataPoints.first?.period ?? .weekly

        // For monthly period (30 days), show every 7th label
        if period == .monthly && totalCount > 15 {
            return stride(from: 0, to: totalCount, by: 7).map { $0 }
        }
        // For weekly (7 days) and 6M (6 months), show all labels
        return Array(0..<totalCount)
    }

    // Calculate exact bar width based on total width and number of bars
    // Formula: (totalWidth - (barCount - 1) * spacing) / barCount
    private func calculateBarWidth(totalWidth: CGFloat, barCount: Int) -> CGFloat {
        guard barCount > 0 else { return 0 }
        let spacing: CGFloat = 1.0
        let totalSpacing = CGFloat(barCount - 1) * spacing
        let availableWidth = totalWidth - totalSpacing
        return max(1, availableWidth / CGFloat(barCount))
    }

    // Calculate the x-offset for a label to center it on its corresponding bar
    private func calculateLabelOffset(labelIndex: Int, totalWidth: CGFloat, barCount: Int) -> CGFloat {
        let barWidth = calculateBarWidth(totalWidth: totalWidth, barCount: barCount)
        let spacing: CGFloat = 1.0
        let labelWidth: CGFloat = 60.0

        // Calculate the center of the bar at labelIndex
        let barCenter = (barWidth + spacing) * CGFloat(labelIndex) + (barWidth / 2.0)

        // Offset label to center it on the bar
        return barCenter - (labelWidth / 2.0)
    }

    private func formatDateLabelLine1(_ date: Date, period: TrendPeriod) -> String {
        let formatter = DateFormatter()
        if period == .weekly {
            formatter.dateFormat = "dd"
            return formatter.string(from: date)
        } else {
            formatter.dateFormat = "MMM"
            return formatter.string(from: date)
        }
    }

    private func formatDateLabelLine2(_ date: Date, period: TrendPeriod) -> String {
        let formatter = DateFormatter()
        if period == .weekly {
            formatter.dateFormat = "MMM"
            return formatter.string(from: date)
        } else {
            formatter.dateFormat = "yy"
            return formatter.string(from: date)
        }
    }
}

struct VerticalBarView: View {
    let dataPoint: PeriodDataPoint
    let maxAmount: Double
    let showBar: Bool
    let color: Color
    let barWidth: CGFloat
    @State private var animatedHeight: CGFloat = 0

    private var barHeight: CGFloat {
        guard maxAmount > 0 else { return 0 }
        return CGFloat(dataPoint.amount / maxAmount)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            Rectangle()
                .fill(color)
                .frame(width: barWidth, height: 200 * animatedHeight)
                .cornerRadius(2, corners: [.topLeft, .topRight])
        }
        .frame(width: barWidth, height: 200)
        .onAppear {
            let randomDelay = Double.random(in: 0.0...0.4)
            withAnimation(.spring(response: 1.0, dampingFraction: 0.7).delay(randomDelay)) {
                animatedHeight = showBar ? barHeight : 0
            }
        }
        .onChange(of: showBar) { _, newValue in
            withAnimation(.spring(response: 1.0, dampingFraction: 0.7)) {
                animatedHeight = newValue ? barHeight : 0
            }
        }
    }
}

// MARK: - Budget Performance Section
struct BudgetPerformanceSection: View {
    let performance: BudgetPerformanceSummary
    let currency: Currency
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            DSText("Budget Performance", font: .dsSmallTitle, color: theme.colors.textPrimary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: DSSpacing.sm) {
                PerformanceStatCard(
                    title: "Budgets Created",
                    value: "\(performance.totalBudgetsCreated)",
                    icon: "calendar"
                )

                PerformanceStatCard(
                    title: "Avg. Utilization",
                    value: "\(String(format: "%.0f%%", performance.averageUtilization * 100))",
                    icon: "chart.pie"
                )

                if let mostOverBudget = performance.mostOverBudgetCategory {
                    PerformanceStatCard(
                        title: "Most Over Budget",
                        value: mostOverBudget,
                        icon: "exclamationmark.triangle",
                        isWarning: true
                    )
                }

                if let bestBudget = performance.bestPerformingBudget {
                    PerformanceStatCard(
                        title: "Best Period",
                        value: bestBudget.budgetName,
                        icon: "star"
                    )
                }
            }
        }
    }
}

struct PerformanceStatCard: View {
    let title: String
    let value: String
    let icon: String
    var isWarning: Bool = false
    @Environment(\.appTheme) private var theme

    var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                HStack {
                    Image(systemName: icon)
                        .font(.dsHeadline)
                        .foregroundColor(isWarning ? .orange : theme.colors.textPrimary.opacity(0.6))
                    Spacer()
                }

                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                    DSText(title, font: .dsCaption, color: theme.colors.textSecondary)
                        .lineLimit(1)
                    DSText(value, font: .dsHeadline, color: theme.colors.textPrimary)
                        .fontWeight(.medium)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Category Comparison Section
struct CategoryComparisonSection: View {
    let categories: [CategoryComparisonData]
    let currency: Currency
    @Environment(\.appTheme) private var theme

    private var maxSpent: Double {
        categories.map(\.totalSpent).max() ?? 1.0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            DSText("Top Spending Categories", font: .dsSmallTitle, color: theme.colors.textPrimary)

            DSCard(padding: 16) {
                VStack(spacing: DSSpacing.sm) {
                    ForEach(categories) { category in
                        CategoryComparisonRow(
                            category: category,
                            maxSpent: maxSpent,
                            currency: currency
                        )
                    }
                }
            }
        }
    }
}

struct CategoryComparisonRow: View {
    let category: CategoryComparisonData
    let maxSpent: Double
    let currency: Currency
    @Environment(\.appTheme) private var theme
    @State private var animatedWidth: CGFloat = 0

    private var barWidth: CGFloat {
        return CGFloat(category.totalSpent / maxSpent)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            HStack {
                DSText(category.categoryName, font: .dsBody, color: theme.colors.textPrimary)
                    .fontWeight(.medium)
                Spacer()
                DSText("\(currency.code) \(String(format: "%.0f", category.totalSpent))", font: .dsBody, color: theme.colors.textPrimary)
                    .fontWeight(.medium)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(theme.colors.textSecondary.opacity(0.1))
                        .frame(height: 8)
                        .cornerRadius(4)

                    Rectangle()
                        .fill(category.categoryGroup.color)
                        .frame(width: geometry.size.width * animatedWidth, height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
            .onAppear {
                withAnimation(.easeOut(duration: 0.8).delay(0.1)) {
                    animatedWidth = barWidth
                }
            }
        }
    }
}

// MARK: - Daily Spending Section
struct DailySpendingSection: View {
    let pattern: DailySpendingPattern
    let currency: Currency
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            DSText("Daily Spending Pattern", font: .dsSmallTitle, color: theme.colors.textPrimary)

            DSCard(padding: 16) {
                VStack(spacing: DSSpacing.lg) {
                    // Average daily spending with trend
                    HStack {
                        VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                            DSText("Average Daily", font: .dsCaption, color: theme.colors.textSecondary)
                            HStack(alignment: .firstTextBaseline, spacing: DSSpacing.xs) {
                                DSText("\(currency.code) \(String(format: "%.2f", pattern.averageDailySpending))", font: .dsLargeTitle, color: theme.colors.textPrimary)
                                    .fontWeight(.bold)

                                if abs(pattern.trendPercentage) > 0.1 {
                                    HStack(spacing: DSSpacing.xxs) {
                                        Image(systemName: pattern.isIncreasing ? "arrow.up" : "arrow.down")
                                            .font(.dsCaption)
                                            .fontWeight(.bold)
                                        DSText("\(String(format: "%.0f%%", abs(pattern.trendPercentage)))", font: .dsCaption, color: pattern.isIncreasing ? .red : .green)
                                            .fontWeight(.bold)
                                    }
                                    .foregroundColor(pattern.isIncreasing ? .red : .green)
                                }
                            }
                        }
                        Spacer()
                    }

                    // Day of week breakdown
                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        DSText("By Day of Week", font: .dsBody, color: theme.colors.textSecondary)
                            .fontWeight(.medium)

                        HStack(alignment: .bottom, spacing: DSSpacing.xxs) {
                            ForEach(1...7, id: \.self) { weekday in
                                DayOfWeekBar(
                                    day: pattern.weekdayNames[weekday - 1],
                                    amount: pattern.averageForWeekday(weekday),
                                    maxAmount: pattern.dayOfWeekBreakdown.values.max() ?? 1,
                                    currency: currency
                                )
                            }
                        }
                        .frame(height: 100)
                    }
                }
            }
        }
    }
}

struct DayOfWeekBar: View {
    let day: String
    let amount: Double
    let maxAmount: Double
    let currency: Currency
    @Environment(\.appTheme) private var theme
    @State private var animatedHeight: CGFloat = 0

    private var barHeight: CGFloat {
        return maxAmount > 0 ? CGFloat(amount / maxAmount) : 0
    }

    var body: some View {
        VStack(spacing: DSSpacing.xxs) {
            GeometryReader { geometry in
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(theme.colors.textPrimary)
                        .frame(height: geometry.size.height * animatedHeight)
                        .cornerRadius(4)
                }
            }

            DSText(day, font: .dsCaption, color: theme.colors.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(Double.random(in: 0.1...0.3))) {
                animatedHeight = barHeight
            }
        }
    }
}

// MARK: - Overview Hero Card
struct OverviewHeroCard: View {
    let budgetManager: any BudgetManagerProtocol
    let excludeSavings: Bool
    let selectedGroups: Set<CategoryGroup>?
    @Environment(\.appTheme) private var theme
    @State private var animatedSpentPercentage: Double = 0

    init(budgetManager: any BudgetManagerProtocol, excludeSavings: Bool = false, selectedGroups: Set<CategoryGroup>? = nil) {
        self.budgetManager = budgetManager
        self.excludeSavings = excludeSavings
        self.selectedGroups = selectedGroups
    }

    private var totalBudgetAmount: Double {
        if let selectedGroups = selectedGroups {
            return budgetManager.totalBudgetAmount(excludingSavings: excludeSavings, selectedGroups: selectedGroups)
        }
        return budgetManager.totalBudgetAmount(excludingSavings: excludeSavings)
    }

    private var totalSpent: Double {
        if let selectedGroups = selectedGroups {
            return budgetManager.totalSpent(excludingSavings: excludeSavings, selectedGroups: selectedGroups)
        }
        return budgetManager.totalSpent(excludingSavings: excludeSavings)
    }

    private var totalRemains: Double {
        if let selectedGroups = selectedGroups {
            return budgetManager.totalRemains(excludingSavings: excludeSavings, selectedGroups: selectedGroups)
        }
        return budgetManager.totalRemains(excludingSavings: excludeSavings)
    }

    private var spentPercentage: Double {
        if let selectedGroups = selectedGroups {
            return budgetManager.spentPercentage(excludingSavings: excludeSavings, selectedGroups: selectedGroups)
        }
        return budgetManager.spentPercentage(excludingSavings: excludeSavings)
    }

    var body: some View {
        DSCard(padding: 0) {
            GeometryReader { cardGeometry in
                VStack(spacing: 0) {
                    // Main content area
                    HStack(spacing: DSSpacing.md) {
                        // Left section - Budget info
                        VStack(alignment: .leading, spacing: DSSpacing.md) {
                            // Total Budget - Large and prominent
                            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                                DSText("Total Budget", font: .dsBody, color: theme.colors.textSecondary)
                                DSText(String(format: "%.2f", totalBudgetAmount), font: .dsLargeTitle, color: theme.colors.textPrimary)
                                    .fontWeight(.bold)
                            }

                            // Spent and Remaining
                            HStack(spacing: DSSpacing.xl) {
                                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                                    DSText("Spent", font: .dsCaption, color: theme.colors.textSecondary)
                                    DSText(String(format: "%.2f", totalSpent), font: .dsHeadline, color: theme.colors.textPrimary)
                                        .fontWeight(.medium)
                                }

                                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                                    DSText("Remaining", font: .dsCaption, color: theme.colors.textSecondary)
                                    DSText(String(format: "%.2f", totalRemains), font: .dsHeadline, color: theme.colors.textPrimary)
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
                                    .trim(from: 0, to: animatedSpentPercentage)
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                theme.colors.primaryLight,
                                                theme.colors.primary
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                    )
                                    .frame(width: 80, height: 80)
                                    .rotationEffect(.degrees(-90))
                                    .animation(.easeInOut(duration: 1.2), value: animatedSpentPercentage)

                                // Percentage text in center
                                DSText("\(Int(spentPercentage * 100))%", font: .dsTitle, color: theme.colors.textPrimary)
                                    .fontWeight(.bold)
                                    .animation(.easeInOut(duration: 0.8), value: spentPercentage)
                            }

                            DSText("spent in\n\(budgetManager.getAllTransactions().count) transactions", font: .dsCaption, color: theme.colors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, DSSpacing.lg)
                    .padding(.top, DSSpacing.lg)


                }
            }
            .frame(height: 160)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).delay(0.3)) {
                animatedSpentPercentage = spentPercentage
            }
        }
        .onChange(of: spentPercentage) { _, newValue in
            withAnimation(.easeInOut(duration: 0.8)) {
                animatedSpentPercentage = newValue
            }
        }
    }
}

// MARK: - Category Group Bar Chart
struct CategoryGroupBarChart: View {
    let budgetManager: any BudgetManagerProtocol
    let excludeSavings: Bool
    let selectedGroups: Set<CategoryGroup>?
    @Environment(\.appTheme) private var theme
    @State private var showText = false

    private var sortedGroups: [(CategoryGroup, Double)] {
        let groupsToCheck = selectedGroups ?? Set(CategoryGroup.allCases)

        return groupsToCheck.compactMap { group in
            let spent = budgetManager.spentAmount(for: group)

            // If excluding savings (expenses mode), include groups that have at least one savings category
            if excludeSavings {
                let hasSavingsCategories = budgetManager.budget.categories
                    .filter { $0.categoryGroup == group }
                    .contains { $0.categoryType == .savings }

                // Show group if it has spending OR if it has savings categories
                guard spent > 0 || hasSavingsCategories else { return nil }
            } else {
                // In normal mode, only show groups with spending
                guard spent > 0 else { return nil }
            }

            return (group, spent)
        }
        .sorted { $0.1 > $1.1 } // Sort by spent amount descending
    }

    private var maxSpent: Double {
        sortedGroups.max(by: { $0.1 < $1.1 })?.1 ?? 1.0
    }

    var body: some View {
        VStack(spacing: 0) {
            if sortedGroups.isEmpty {
                // Empty state when no transactions
                DSCard {
                    VStack(spacing: DSSpacing.sm) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.dsLargeTitle)
                            .foregroundColor(theme.colors.textSecondary.opacity(0.6))

                        VStack(spacing: DSSpacing.xxs) {
                            DSText("No spending data yet", font: .dsBody, color: theme.colors.textPrimary)
                                .fontWeight(.medium)
                            DSText("Start tracking expenses to see breakdown", font: .dsCaption, color: theme.colors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DSSpacing.xl)
                }
                .padding(.horizontal, DSSpacing.md)
            } else {
                ForEach(sortedGroups, id: \.0) { group, spent in
                    CategoryGroupBarRow(
                        group: group,
                        spent: spent,
                        maxSpent: maxSpent,
                        showText: showText
                    )
                }
                .padding(.horizontal, DSSpacing.md)
                .onAppear {
                    // Show text after 80% of the longest possible bar animation
                    let baseDelay = 0.8 // max random delay
                    let barAnimationDuration = 1.2
                    let textDelay = baseDelay + (barAnimationDuration * 0.8)

                    withAnimation(.easeInOut(duration: 0.3).delay(textDelay)) {
                        showText = true
                    }
                }
            }
        }
    }
}

struct CategoryGroupBarRow: View {
    let group: CategoryGroup
    let spent: Double
    let maxSpent: Double
    let showText: Bool
    @Environment(\.appTheme) private var theme
    @State private var animatedSpent: Double = 0

    var body: some View {
        HStack(spacing: DSSpacing.xs) {
            // Progress bar background
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    HStack {
                        // Progress bar only
                        Rectangle()
                            .fill(group.color)
                            .frame(width: max(0, geometry.size.width * (animatedSpent / maxSpent)), height: 32)

                        Spacer()
                    }

                    // Group name overlay
                    HStack {
                        let relativeWidth = spent / maxSpent
                        if relativeWidth > 0.3 {
                            DSText(group.displayName, font: .dsCaption, color: theme.colors.textPrimary)
                                .fontWeight(.medium)
                                .padding(.leading, DSSpacing.xs)
                                .opacity(showText ? 1.0 : 0.0)
                        } else {
                            DSText(group.displayName, font: .dsCaption, color: theme.colors.textPrimary)
                                .fontWeight(.medium)
                                .padding(.leading, max(8, geometry.size.width * relativeWidth + 8))
                                .opacity(showText ? 1.0 : 0.0)
                        }

                        Spacer()
                    }
                }
            }
            .frame(height: 32)

            // Amount outside bar
            DSText(String(format: "%.0f", spent), font: .dsCaption, color: theme.colors.textPrimary)
                .fontWeight(.medium)
                .frame(width: 50, alignment: .trailing)
                .opacity(showText ? 1.0 : 0.0)
        }
        .onAppear {
            let randomDelay = Double.random(in: 0.1...0.8)

            // Animate the bar
            withAnimation(.spring(response: 1.2, dampingFraction: 0.6, blendDuration: 0.3).delay(randomDelay)) {
                animatedSpent = spent
            }
        }
        .onChange(of: spent) { _, newValue in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6, blendDuration: 0.2)) {
                animatedSpent = newValue
            }
        }
    }
}

