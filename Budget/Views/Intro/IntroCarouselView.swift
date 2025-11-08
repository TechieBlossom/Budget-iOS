//
//  IntroCarouselView.swift
//  Budget
//
//  Created for intro carousel feature
//

import SwiftUI

struct IntroCarouselView: View {
    @Environment(\.appTheme) private var theme
    @AppStorage("hasSeenIntroCarousel") private var hasSeenIntroCarousel = false

    @State private var currentPage = 0
    let onComplete: () -> Void

    private let totalPages = 3

    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    theme.colors.background,
                    theme.colors.backgroundSecondary
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button at top (hide on last slide)
                if currentPage != totalPages - 1 {
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.easeOut(duration: 0.3)) {
                                completeIntro()
                            }
                        } label: {
                            DSText("Skip", font: .dsBody, color: theme.colors.textSecondary)
                                .padding(.horizontal, DSSpacing.md)
                                .padding(.vertical, DSSpacing.sm)
                        }
                    }
                    .padding(.top, DSSpacing.md)
                    .padding(.horizontal, DSSpacing.md)
                    .transition(.opacity)
                } else {
                    // Spacer to maintain consistent layout
                    Spacer()
                        .frame(height: 48)
                }

                // Carousel
                TabView(selection: $currentPage) {
                    IntroSlide1()
                        .tag(0)

                    IntroSlide2()
                        .tag(1)

                    IntroSlide3()
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Custom progress dots with animation
                HStack(spacing: DSSpacing.sm) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? theme.colors.primary : theme.colors.divider)
                            .frame(width: index == currentPage ? 10 : 8, height: index == currentPage ? 10 : 8)
                            .scaleEffect(index == currentPage ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                    }
                }
                .padding(.bottom, DSSpacing.md)

                // Get Started Button - Below indicators (only on last slide)
                if currentPage == totalPages - 1 {
                    DSButton("Get Started", style: .primary, fullWidth: true) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            completeIntro()
                        }
                    }
                    .padding(.horizontal, DSSpacing.xl)
                    .padding(.bottom, DSSpacing.xl)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    // Spacer to maintain consistent layout
                    Spacer()
                        .frame(height: DSSpacing.xl)
                }
            }
        }
    }

    private func completeIntro() {
        hasSeenIntroCarousel = true
        onComplete()
    }
}

// MARK: - Slide 1: Budget What You Spend

private struct IntroSlide1: View {
    @Environment(\.appTheme) private var theme
    @State private var isVisible = false

    // Mock budget manager for preview card
    private func createMockBudgetManager() -> any BudgetManagerProtocol {
        let period = BudgetPeriod(startDate: Date())
        let currency = Currency(code: "USD", name: "US Dollar", symbol: "$")
        let categories = SubCategory.createDefault()

        // Create mock category amounts that total exactly 100000
        var categoryAmounts: [String: Double] = [:]
        let targetTotal = 100000.0
        let amountPerCategory = floor(targetTotal / Double(categories.count))

        // Assign base amount to all categories
        for category in categories {
            categoryAmounts[category.id.uuidString] = amountPerCategory
        }

        // Add the remainder to the first category to ensure exact total
        let currentTotal = amountPerCategory * Double(categories.count)
        let remainder = targetTotal - currentTotal
        if let firstCategory = categories.first {
            categoryAmounts[firstCategory.id.uuidString] = amountPerCategory + remainder
        }

        let mockBudget = Budget(
            id: UUID(),
            period: period,
            currency: currency,
            categories: categories,
            categoryAmounts: categoryAmounts
        )
        return MockBudgetManager(budget: mockBudget, totalSpent: 60000, totalRemains: 40000)
    }

    var body: some View {
        VStack(spacing: DSSpacing.xl) {
            Spacer()

            // Icon with animation
            ZStack {
                Circle()
                    .fill(theme.colors.primary.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .scaleEffect(isVisible ? 1.0 : 0.5)
                    .opacity(isVisible ? 1 : 0)

                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 50, weight: .light))
                    .foregroundColor(theme.colors.primary)
                    .scaleEffect(isVisible ? 1.0 : 0.5)
                    .opacity(isVisible ? 1 : 0)
            }
            .padding(.bottom, DSSpacing.sm)

            // Title with fade-in
            DSText("Budget What You Spend,\nNot What You Earn", font: .dsTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DSSpacing.xl)
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 20)

            // Mock Budget Overview Card
            OverviewHeroCard(budgetManager: createMockBudgetManager(), excludeSavings: false, selectedGroups: nil)
                .padding(.horizontal, DSSpacing.xl)
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 20)
                .animation(.easeOut(duration: 0.5).delay(0.2), value: isVisible)

            // Features with staggered animation
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                FeatureBullet(text: "Set your budget in your currency - we never ask about your salary")
                    .opacity(isVisible ? 1 : 0)
                    .offset(x: isVisible ? 0 : -20)
                    .animation(.easeOut(duration: 0.5).delay(0.3), value: isVisible)
            }
            .padding(.horizontal, DSSpacing.xl)

            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isVisible = true
            }
        }
    }
}

// MARK: - Slide 2: Smart Envelope Budgeting

private struct IntroSlide2: View {
    @Environment(\.appTheme) private var theme
    @State private var isVisible = false

    // Mock budget manager for category cards
    private func createMockBudgetManager() -> any BudgetManagerProtocol {
        let period = BudgetPeriod(startDate: Date())
        let currency = Currency(code: "USD", name: "US Dollar", symbol: "$")

        // Create specific categories: Groceries (Essential) and Stocks + Liquid Funds (Financial Goals)
        let groceries = SubCategory(name: "Groceries", categoryGroup: .essentials, categoryType: .expense)
        let stocks = SubCategory(name: "Stocks", categoryGroup: .financialGoals, categoryType: .savings)
        let liquidFunds = SubCategory(name: "Liquid Funds", categoryGroup: .financialGoals, categoryType: .savings)

        let categories = [groceries, stocks, liquidFunds]

        // Set budgets: Groceries 1000, Stocks 1000, Liquid Funds 1000
        var categoryAmounts: [String: Double] = [:]
        categoryAmounts[groceries.id.uuidString] = 1000
        categoryAmounts[stocks.id.uuidString] = 1000
        categoryAmounts[liquidFunds.id.uuidString] = 1000

        let mockBudget = Budget(
            id: UUID(),
            period: period,
            currency: currency,
            categories: categories,
            categoryAmounts: categoryAmounts
        )

        // Create mock transactions
        // Groceries: 50% spent = 500
        let groceryTransaction = Transaction(
            amount: 500,
            name: "Weekly shopping",
            notes: "Supermarket trip",
            date: Date(),
            categoryId: groceries.id,
            budgetId: mockBudget.id
        )

        // Stocks: 70% spent = 700
        let stocksTransaction = Transaction(
            amount: 700,
            name: "Monthly investment",
            notes: "Stock purchase",
            date: Date(),
            categoryId: stocks.id,
            budgetId: mockBudget.id
        )

        // Liquid Funds: 90% spent = 900
        let liquidFundsTransaction = Transaction(
            amount: 900,
            name: "Emergency fund",
            notes: "Savings allocation",
            date: Date(),
            categoryId: liquidFunds.id,
            budgetId: mockBudget.id
        )

        return MockBudgetManager(
            budget: mockBudget,
            transactions: [groceryTransaction, stocksTransaction, liquidFundsTransaction]
        )
    }

    var body: some View {
        VStack(spacing: DSSpacing.md) {
            Spacer()

            // Icon with animation
            ZStack {
                Circle()
                    .fill(theme.colors.success.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .scaleEffect(isVisible ? 1.0 : 0.5)
                    .opacity(isVisible ? 1 : 0)

                Image(systemName: "rectangle.3.group.fill")
                    .font(.system(size: 50, weight: .light))
                    .foregroundColor(theme.colors.success)
                    .scaleEffect(isVisible ? 1.0 : 0.5)
                    .opacity(isVisible ? 1 : 0)
            }
            .padding(.bottom, DSSpacing.sm)

            // Title with fade-in
            DSText("Smart Envelope\nBudgeting", font: .dsTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DSSpacing.xl)
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 20)

            // Category Cards
            VStack(spacing: DSSpacing.sm) {
                // Essential -> Groceries (60% group, 50% category)
                CategoryGroupExpendableCard(
                    group: .essentials,
                    budgetManager: createMockBudgetManager(),
                    isExpanded: false,
                    onToggle: {},
                    onSubCategoryTap: nil,
                    onAddCategory: nil
                )

                // Financial Goals -> Stocks + Liquid Funds (80% group, 70% stocks, 90% liquid funds)
                CategoryGroupExpendableCard(
                    group: .financialGoals,
                    budgetManager: createMockBudgetManager(),
                    isExpanded: false,
                    onToggle: {},
                    onSubCategoryTap: nil,
                    onAddCategory: nil
                )
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, DSSpacing.lg)
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .animation(.easeOut(duration: 0.5).delay(0.2), value: isVisible)

            // Feature with animation
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                FeatureBullet(text: "See exactly where money goes")
                    .opacity(isVisible ? 1 : 0)
                    .offset(x: isVisible ? 0 : -20)
                    .animation(.easeOut(duration: 0.5).delay(0.3), value: isVisible)
            }
            .padding(.horizontal, DSSpacing.xl)

            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isVisible = true
            }
        }
    }
}

// MARK: - Slide 3: Complete Financial Picture

private struct IntroSlide3: View {
    @Environment(\.appTheme) private var theme
    @State private var isVisible = false

    var body: some View {
        VStack(spacing: DSSpacing.xl) {
            Spacer()

            // Icon with animation
            ZStack {
                Circle()
                    .fill(theme.colors.info.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .scaleEffect(isVisible ? 1.0 : 0.5)
                    .opacity(isVisible ? 1 : 0)

                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 50, weight: .light))
                    .foregroundColor(theme.colors.info)
                    .scaleEffect(isVisible ? 1.0 : 0.5)
                    .opacity(isVisible ? 1 : 0)
            }
            .padding(.bottom, DSSpacing.sm)

            // Title with fade-in
            DSText("Your Complete\nFinancial Picture", font: .dsTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DSSpacing.xl)
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 20)

            // Features with staggered animation
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                FeatureBullet(text: "Historical spending patterns")
                    .opacity(isVisible ? 1 : 0)
                    .offset(x: isVisible ? 0 : -20)
                    .animation(.easeOut(duration: 0.5).delay(0.3), value: isVisible)

                FeatureBullet(text: "Month-over-month analysis")
                    .opacity(isVisible ? 1 : 0)
                    .offset(x: isVisible ? 0 : -20)
                    .animation(.easeOut(duration: 0.5).delay(0.4), value: isVisible)

                FeatureBullet(text: "Category comparisons over time")
                    .opacity(isVisible ? 1 : 0)
                    .offset(x: isVisible ? 0 : -20)
                    .animation(.easeOut(duration: 0.5).delay(0.5), value: isVisible)
            }
            .padding(.horizontal, DSSpacing.xl)

            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isVisible = true
            }
        }
    }
}

// MARK: - Feature Bullet Component

private struct FeatureBullet: View {
    @Environment(\.appTheme) private var theme
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: DSSpacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(theme.colors.primary)
                .padding(.top, 2)

            DSText(text, font: .dsBody, color: theme.colors.textSecondary)
                .multilineTextAlignment(.leading)

            Spacer()
        }
    }
}


#Preview {
    IntroCarouselView(onComplete: {
        print("Intro completed")
    })
    .environment(\.appTheme, AppTheme.shared)
}
