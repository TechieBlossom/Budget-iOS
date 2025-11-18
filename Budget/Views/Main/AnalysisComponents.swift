import SwiftUI

// MARK: - Overview Hero Card
struct OverviewHeroCard: View {
    let budgetManager: any BudgetManagerProtocol
    let excludeSavings: Bool
    let selectedGroups: Set<CategoryGroup>?
    @Environment(\.appTheme) private var theme
    @State private var animatedSpentPercentage: Double = 0
    @State private var isExpanded: Bool = false

    init(budgetManager: any BudgetManagerProtocol, excludeSavings: Bool = false, selectedGroups: Set<CategoryGroup>? = nil) {
        self.budgetManager = budgetManager
        self.excludeSavings = excludeSavings
        self.selectedGroups = selectedGroups
    }

    private var totalBudgetAmount: Double {
        if let selectedGroups = selectedGroups, let concreteManager = budgetManager as? BudgetManager {
            return concreteManager.totalBudgetAmount(excludingSavings: excludeSavings, selectedGroups: selectedGroups)
        }
        return budgetManager.totalBudgetAmount(excludingSavings: excludeSavings)
    }

    private var totalSpent: Double {
        if let selectedGroups = selectedGroups, let concreteManager = budgetManager as? BudgetManager {
            return concreteManager.totalSpent(excludingSavings: excludeSavings, selectedGroups: selectedGroups)
        }
        return budgetManager.totalSpent(excludingSavings: excludeSavings)
    }

    private var totalRemains: Double {
        if let selectedGroups = selectedGroups, let concreteManager = budgetManager as? BudgetManager {
            return concreteManager.totalRemains(excludingSavings: excludeSavings, selectedGroups: selectedGroups)
        }
        return budgetManager.totalRemains(excludingSavings: excludeSavings)
    }

    private var spentPercentage: Double {
        if let selectedGroups = selectedGroups, let concreteManager = budgetManager as? BudgetManager {
            return concreteManager.spentPercentage(excludingSavings: excludeSavings, selectedGroups: selectedGroups)
        }
        return budgetManager.spentPercentage(excludingSavings: excludeSavings)
    }

    var body: some View {
        DSCard(padding: 0) {
            VStack(spacing: 0) {
                if isExpanded {
                    // Expanded state - Full details
                    VStack(spacing: DSSpacing.md) {
                        // Top row - Same as collapsed state
                        HStack(spacing: DSSpacing.md) {
                            // Left section - Total Budget only
                            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                                DSText("Total Budget", font: .dsBody, color: theme.colors.textSecondary)
                                DSText(String(format: "%.2f", totalBudgetAmount), font: .dsLargeTitle, color: theme.colors.textPrimary)
                                    .fontWeight(.bold)
                            }

                            Spacer()

                            // Right section - Circular progress (80x80 - same as collapsed)
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

                                // Percentage text in center
                                DSText("\(Int(spentPercentage * 100))%", font: .dsBody, color: theme.colors.textPrimary)
                                    .fontWeight(.bold)
                            }
                        }

                        // Bottom row - Spent and Remaining (only visible when expanded)
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

                            Spacer()
                        }
                    }
                    .padding(.horizontal, DSSpacing.lg)
                    .padding(.vertical, DSSpacing.md)
                    .transition(.opacity)
                } else {
                    // Collapsed state - Smaller pie and total budget only
                    HStack(spacing: DSSpacing.md) {
                        // Left section - Total Budget only
                        VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                            DSText("Total Budget", font: .dsBody, color: theme.colors.textSecondary)
                            DSText(String(format: "%.2f", totalBudgetAmount), font: .dsLargeTitle, color: theme.colors.textPrimary)
                                .fontWeight(.bold)
                        }

                        Spacer()

                        // Right section - Circular progress (80x80 - same as expanded)
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

                            // Percentage text in center
                            DSText("\(Int(spentPercentage * 100))%", font: .dsBody, color: theme.colors.textPrimary)
                                .fontWeight(.bold)
                        }
                    }
                    .padding(.horizontal, DSSpacing.lg)
                    .padding(.vertical, DSSpacing.md)
                    .transition(.opacity)
                }
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                isExpanded.toggle()
                HapticManager.shared.buttonTap()
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2).delay(0.3)) {
                animatedSpentPercentage = spentPercentage
            }
        }
        .onChange(of: spentPercentage) { _, newValue in
            withAnimation(.easeOut(duration: 0.8)) {
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

            let percentage = budgetManager.spentPercentage(for: group, excludingSavings: excludeSavings)
            return (group, percentage)
        }
        .sorted { $0.1 > $1.1 } // Sort by completion percentage descending
    }

    private var maxPercentage: Double {
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
                ForEach(sortedGroups, id: \.0) { group, percentage in
                    CategoryGroupBarRow(
                        group: group,
                        percentage: percentage,
                        maxPercentage: maxPercentage,
                        showText: showText
                    )
                }
                .padding(.horizontal, DSSpacing.md)
                .onAppear {
                    // Show text after 80% of the longest possible bar animation
                    let baseDelay = 0.8 // max random delay
                    let barAnimationDuration = 1.2
                    let textDelay = baseDelay + (barAnimationDuration * 0.8)

                    withAnimation(.easeOut(duration: 0.3).delay(textDelay)) {
                        showText = true
                    }
                }
            }
        }
    }
}

struct CategoryGroupBarRow: View {
    let group: CategoryGroup
    let percentage: Double
    let maxPercentage: Double
    let showText: Bool
    @Environment(\.appTheme) private var theme
    @State private var animatedPercentage: Double = 0

    var body: some View {
        HStack(spacing: DSSpacing.xs) {
            // Progress bar background
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    HStack {
                        // Progress bar only
                        Rectangle()
                            .fill(group.color)
                            .frame(width: max(0, geometry.size.width * (animatedPercentage / maxPercentage)), height: 32)

                        Spacer()
                    }

                    // Group name overlay
                    HStack {
                        let relativeWidth = percentage / maxPercentage
                        if relativeWidth > 0.3 {
                            DSText(group.displayName, font: .dsCaption, color: Color(hex: "1a1a1a"))
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

            // Completion percentage outside bar
            DSText(String(format: "%.0f%%", percentage * 100), font: .dsCaption, color: theme.colors.textPrimary)
                .fontWeight(.medium)
                .frame(width: 50, alignment: .trailing)
                .opacity(showText ? 1.0 : 0.0)
        }
        .onAppear {
            let randomDelay = Double.random(in: 0.1...0.8)

            // Animate the bar
            withAnimation(.easeOut(duration: 1.2).delay(randomDelay)) {
                animatedPercentage = percentage
            }
        }
        .onChange(of: percentage) { _, newValue in
            withAnimation(.easeOut(duration: 0.8)) {
                animatedPercentage = newValue
            }
        }
    }
}
