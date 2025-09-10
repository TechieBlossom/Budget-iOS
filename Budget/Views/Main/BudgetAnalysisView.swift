import SwiftUI

struct BudgetAnalysisView: View {
    let budgetManager: any BudgetManagerProtocol
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @State private var showingAllTransactions = false
    @State private var showingBudgetSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            DSHeader(
                title: "Budget Analysis",
                subtitle: budgetManager.budget.budgetName,
                onBack: {
                    dismiss()
                }
            ) {
                Button(action: {
                    showingBudgetSettings = true
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(theme.colors.primaryText)
                }
            }
            
            ScrollView {
                VStack(spacing: 24) {
                    // Budget Overview Stats
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            DSText("Overview", font: .dsSmallTitle, color: theme.colors.primaryText)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        
                        OverviewHeroCard(budgetManager: budgetManager)
                            .padding(.horizontal, 16)
                    }
                    
                    // Category Spending Chart Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            DSText("Spending Breakdown", font: .dsSmallTitle, color: theme.colors.primaryText)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        
                        CategoryBarChart(budgetManager: budgetManager)
                    }
                    
                    
                    // Additional Analytics
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            DSText("Insights", font: .dsSmallTitle, color: theme.colors.primaryText)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        
                        InsightsSection(budgetManager: budgetManager)
                            .padding(.horizontal, 16)
                    }
                    
                    // All Transactions Link
                    VStack(spacing: 16) {
                        DSButtonCard(
                            "View All Transactions",
                            subtitle: "\(budgetManager.getAllTransactions().count) transactions"
                        ) {
                            showingAllTransactions = true
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // Bottom spacing
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 40)
                }
            }
        }
        .background(theme.colors.background)
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $showingAllTransactions) {
            AllTransactionsView(budgetManager: budgetManager)
        }
        .navigationDestination(isPresented: $showingBudgetSettings) {
            BudgetSettingsView(budgetManager: budgetManager)
        }
    }
}

struct CategoryBarChart: View {
    let budgetManager: any BudgetManagerProtocol
    @Environment(\.appTheme) private var theme
    @State private var showText = false
    
    private var sortedCategories: [(Category, Double, Double)] {
        budgetManager.budget.categories.compactMap { category in
            let spent = budgetManager.spentAmount(for: category)
            let allocated = budgetManager.budget.categoryAmounts[category.id.uuidString] ?? 0
            guard allocated > 0 && spent > 0 else { return nil }
            let percentage = spent / allocated
            return (category, percentage, spent)
        }
        .sorted { $0.1 > $1.1 } // Sort by percentage descending
    }
    
    private var maxPercentage: Double {
        sortedCategories.max(by: { $0.1 < $1.1 })?.1 ?? 1.0
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(sortedCategories, id: \.0.id) { category, percentage, spent in
                CategoryBarRow(
                    category: category,
                    percentage: percentage,
                    maxPercentage: maxPercentage,
                    spent: spent,
                    allocated: budgetManager.budget.categoryAmounts[category.id.uuidString] ?? 0,
                    showText: showText
                )
            }
        }
        .padding(.horizontal, 16)
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

struct CategoryBarRow: View {
    let category: Category
    let percentage: Double
    let maxPercentage: Double
    let spent: Double
    let allocated: Double
    let showText: Bool
    @Environment(\.appTheme) private var theme
    @State private var animatedPercentage: Double = 0
    
    var body: some View {
        HStack(spacing: 8) {
            // Progress bar background
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    HStack {
                        // Progress bar only
                        Rectangle()
                            .fill(category.color.color)
                            .frame(width: max(0, geometry.size.width * (animatedPercentage / maxPercentage)), height: 32)
                        
                        Spacer()
                    }
                    
                    // Category name overlay
                    HStack {
                        let relativePercentage = percentage / maxPercentage
                        if relativePercentage > 0.3 {
                            DSText(category.name, font: .dsCaption, color: theme.colors.primaryText)
                                .fontWeight(.medium)
                                .padding(.leading, 8)
                                .opacity(showText ? 1.0 : 0.0)
                        } else {
                            DSText(category.name, font: .dsCaption, color: theme.colors.primaryText)
                                .fontWeight(.medium)
                                .padding(.leading, max(8, geometry.size.width * relativePercentage + 8))
                                .opacity(showText ? 1.0 : 0.0)
                        }
                        
                        Spacer()
                    }
                }
            }
            .frame(height: 32)
            
            // Percentage outside bar
            DSText(String(format: "%.1f%%", percentage * 100), font: .dsCaption, color: theme.colors.primaryText)
                .fontWeight(.medium)
                .frame(width: 40, alignment: .trailing)
                .opacity(showText ? 1.0 : 0.0)
        }
        .onAppear {
            let randomDelay = Double.random(in: 0.1...0.8)
            
            // Animate the bar
            withAnimation(.spring(response: 1.2, dampingFraction: 0.6, blendDuration: 0.3).delay(randomDelay)) {
                animatedPercentage = percentage
            }
        }
        .onChange(of: percentage) { _, newValue in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6, blendDuration: 0.2)) {
                animatedPercentage = newValue
            }
        }
    }
}

struct OverviewHeroCard: View {
    let budgetManager: any BudgetManagerProtocol
    @Environment(\.appTheme) private var theme
    @State private var animatedSpentPercentage: Double = 0
    
    var body: some View {
        DSCard(padding: 0) {
            GeometryReader { cardGeometry in
                VStack(spacing: 0) {
                    // Main content area
                    HStack(spacing: 16) {
                        // Left section - Budget info
                        VStack(alignment: .leading, spacing: 16) {
                            // Total Budget - Large and prominent
                            VStack(alignment: .leading, spacing: 4) {
                                DSText("Total Budget", font: .dsBody, color: theme.colors.secondaryText)
                                DSText(budgetManager.budget.formattedTotalAmount, font: .dsLargeTitle, color: theme.colors.primaryText)
                                    .fontWeight(.bold)
                            }
                            
                            // Spent and Remaining
                            HStack(spacing: 24) {
                                VStack(alignment: .leading, spacing: 4) {
                                    DSText("Spent", font: .dsCaption, color: theme.colors.secondaryText)
                                    DSText(String(format: "%.2f", budgetManager.totalSpent), font: .dsHeadline, color: theme.colors.primaryText)
                                        .fontWeight(.medium)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    DSText("Remaining", font: .dsCaption, color: theme.colors.secondaryText)
                                    DSText(String(format: "%.2f", budgetManager.totalRemains), font: .dsHeadline, color: theme.colors.primaryText)
                                        .fontWeight(.medium)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // Right section - Circular progress
                        VStack(spacing: 8) {
                            ZStack {
                                // Background circle
                                Circle()
                                    .stroke(theme.colors.secondaryText.opacity(0.2), lineWidth: 8)
                                    .frame(width: 80, height: 80)
                                
                                // Progress circle
                                Circle()
                                    .trim(from: 0, to: animatedSpentPercentage)
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                CategoryColor.color1.color,
                                                CategoryColor.color3.color,
                                                CategoryColor.color5.color
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
                                DSText("\(Int(budgetManager.spentPercentage * 100))%", font: .dsTitle, color: theme.colors.primaryText)
                                    .fontWeight(.bold)
                                    .animation(.easeInOut(duration: 0.8), value: budgetManager.spentPercentage)
                            }
                            
                            DSText("\(budgetManager.getAllTransactions().count) transactions", font: .dsCaption, color: theme.colors.secondaryText)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    
                }
            }
            .frame(height: 160)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).delay(0.3)) {
                animatedSpentPercentage = budgetManager.spentPercentage
            }
        }
        .onChange(of: budgetManager.spentPercentage) { _, newValue in
            withAnimation(.easeInOut(duration: 0.8)) {
                animatedSpentPercentage = newValue
            }
        }
    }
}

struct OverviewStatsGrid: View {
    let budgetManager: any BudgetManagerProtocol
    @Environment(\.appTheme) private var theme
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
            StatCard(
                title: "Total Budget",
                value: budgetManager.budget.formattedTotalAmount,
                subtitle: budgetManager.budget.currency.symbol
            )
            
            StatCard(
                title: "Total Spent",
                value: String(format: "%.2f", budgetManager.totalSpent),
                subtitle: String(format: "%.1f%%", budgetManager.spentPercentage * 100)
            )
            
            StatCard(
                title: "Remaining",
                value: String(format: "%.2f", budgetManager.totalRemains),
                subtitle: String(format: "%.1f%% left", (1 - budgetManager.spentPercentage) * 100)
            )
            
            StatCard(
                title: "Transactions",
                value: "\(budgetManager.getAllTransactions().count)",
                subtitle: "this period"
            )
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    @Environment(\.appTheme) private var theme
    
    var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: 8) {
                DSText(title, font: .dsCaption, color: theme.colors.secondaryText)
                DSText(value, font: .dsSmallTitle, color: theme.colors.primaryText)
                    .fontWeight(.medium)
                DSText(subtitle, font: .dsCaption, color: theme.colors.secondaryText)
            }
        }
    }
}

struct InsightsSection: View {
    let budgetManager: any BudgetManagerProtocol
    @Environment(\.appTheme) private var theme
    
    private var topSpendingCategory: Category? {
        budgetManager.budget.categories.max { cat1, cat2 in
            budgetManager.spentAmount(for: cat1) < budgetManager.spentAmount(for: cat2)
        }
    }
    
    private var categoriesOverBudget: [Category] {
        budgetManager.budget.categories.filter { category in
            let spent = budgetManager.spentAmount(for: category)
            let allocated = budgetManager.budget.categoryAmounts[category.id.uuidString] ?? 0
            return spent > allocated && allocated > 0
        }
    }
    
    
    var body: some View {
        VStack(spacing: 12) {
            if let topCategory = topSpendingCategory {
                InsightCard(
                    icon: "chart.bar.fill",
                    title: "Top Spending Category",
                    description: "\(topCategory.name) - \(String(format: "%.2f", budgetManager.spentAmount(for: topCategory)))"
                )
            }
            
            if !categoriesOverBudget.isEmpty {
                InsightCard(
                    icon: "exclamationmark.triangle.fill",
                    title: "Over Budget",
                    description: "\(categoriesOverBudget.count) \(categoriesOverBudget.count == 1 ? "category" : "categories") exceeded budget"
                )
            }
            
//            DailySpendingChart(budgetManager: budgetManager)
        }
    }
}

struct InsightCard: View {
    let icon: String
    let title: String
    let description: String
    @Environment(\.appTheme) private var theme
    
    var body: some View {
        DSCard {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(theme.colors.primaryText)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    DSText(title, font: .dsBody, color: theme.colors.primaryText)
                        .fontWeight(.medium)
                    DSText(description, font: .dsCaption, color: theme.colors.secondaryText)
                }
                
                Spacer()
            }
        }
    }
}

struct DailySpendingChart: View {
    let budgetManager: any BudgetManagerProtocol
    @Environment(\.appTheme) private var theme
    @State private var selectedDate: Date? = nil
    @State private var selectedAmount: Double = 0
    @State private var animatedBars: [Double] = []
    
    private var dailyData: [(Date, Double)] {
        let calendar = Calendar.current
        let startDate = budgetManager.budget.period.startDate
        let endDate = budgetManager.budget.period.endDate
        
        var data: [(Date, Double)] = []
        var currentDate = startDate
        
        while currentDate <= endDate {
            let dayTransactions = budgetManager.getAllTransactions().filter { transaction in
                calendar.isDate(transaction.date, inSameDayAs: currentDate)
            }
            let dayTotal = dayTransactions.reduce(0) { $0 + $1.amount }
            data.append((currentDate, dayTotal))
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return data
    }
    
    private var maxAmount: Double {
        dailyData.map { $0.1 }.max() ?? 1.0
    }
    
    private var averageAmount: Double {
        let totalSpent = dailyData.reduce(0) { $0 + $1.1 }
        return totalSpent / Double(max(1, dailyData.count))
    }
    
    private var displayAmount: Double {
        selectedAmount > 0 ? selectedAmount : averageAmount
    }
    
    private var displayDate: String {
        if let selectedDate = selectedDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "E, MMM d"
            return formatter.string(from: selectedDate).uppercased()
        } else {
            return "DAILY AVERAGE"
        }
    }
    
    var body: some View {
        DSCard {
            VStack(spacing: 16) {
                // Header with selected value
                VStack(spacing: 4) {
                    DSText(displayDate, font: .dsCaption, color: theme.colors.secondaryText)
                    DSText(String(format: "%.0f", displayAmount), font: .dsLargeTitle, color: theme.colors.primaryText)
                        .fontWeight(.bold)
                        .animation(.easeInOut(duration: 0.2), value: displayAmount)
                }
                
                // Chart area
                VStack(spacing: 8) {
                    // Bars chart
                    GeometryReader { geometry in
                        let barWidth = max(2, (geometry.size.width - CGFloat(dailyData.count - 1) * 2) / CGFloat(dailyData.count))
                        let chartHeight = geometry.size.height
                        
                        ZStack(alignment: .bottom) {
                            // Average line
                            let averageY = chartHeight * (1 - (averageAmount / maxAmount))
                            HStack {
                                Rectangle()
                                    .fill(theme.colors.secondaryText.opacity(0.3))
                                    .frame(height: 1)
                            }
                            .offset(y: averageY - chartHeight/2)
                            
                            // Bars only
                            HStack(alignment: .bottom, spacing: 2) {
                                ForEach(Array(dailyData.enumerated()), id: \.offset) { index, dayData in
                                    let (date, amount) = dayData
                                    let barHeight = chartHeight * (animatedBars.indices.contains(index) ? animatedBars[index] : 0)
                                    let isSelected = selectedDate != nil && Calendar.current.isDate(date, inSameDayAs: selectedDate!)
                                    
                                    Rectangle()
                                        .fill(isSelected ? CategoryColor.color1.color : theme.colors.primaryText)
                                        .frame(width: barWidth, height: max(1, barHeight))
                                        .animation(.easeInOut(duration: 0.3), value: isSelected)
                                        .onTapGesture {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                if isSelected {
                                                    selectedDate = nil
                                                    selectedAmount = 0
                                                } else {
                                                    selectedDate = date
                                                    selectedAmount = amount
                                                }
                                            }
                                        }
                                }
                            }
                        }
                    }
                    .frame(height: 100)
                    
                    // X-axis labels (separate from bars)
                    HStack {
                        ForEach(Array(dailyData.enumerated()), id: \.offset) { index, dayData in
                            let (date, _) = dayData
                            
                            if index % max(1, dailyData.count / 6) == 0 {
                                DSText(formatDateLabel(date), font: .dsCaption, color: theme.colors.secondaryText)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(1)
                                Spacer()
                            } else if index == dailyData.count - 1 {
                                // Add final spacer to balance layout
                                Spacer()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let barWidth = max(2, (UIScreen.main.bounds.width - 32 - CGFloat(dailyData.count - 1) * 2) / CGFloat(dailyData.count))
                            let index = max(0, min(dailyData.count - 1, Int(value.location.x / (barWidth + 2))))
                            let (date, amount) = dailyData[index]
                            selectedDate = date
                            selectedAmount = amount
                        }
                        .onEnded { _ in
                            // Keep selection on drag end
                        }
                )
            }
        }
        .onAppear {
            // Animate bars on appear
            animatedBars = Array(repeating: 0, count: dailyData.count)
            withAnimation(.easeInOut(duration: 1.0)) {
                animatedBars = dailyData.map { $0.1 / maxAmount }
            }
        }
    }
    
    private func formatDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

#Preview {
    BudgetAnalysisView(budgetManager: MockBudgetManager(budget: Budget.createSample()))
        .background(AppTheme.shared.colors.background)
}
