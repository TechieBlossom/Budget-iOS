import SwiftUI

struct CategoryGroupExpendableCard: View {
    let group: CategoryGroup
    let budgetManager: any BudgetManagerProtocol
    let isExpanded: Bool
    let onToggle: () -> Void
    let onSubCategoryTap: ((SubCategory) -> Void)?
    let onAddCategory: ((CategoryGroup) -> Void)?

    @Environment(\.appTheme) private var theme

    private var allocatedAmount: Double {
        budgetManager.allocatedAmount(for: group)
    }

    private var spentAmount: Double {
        budgetManager.spentAmount(for: group)
    }

    private var remainingAmount: Double {
        budgetManager.remainingAmount(for: group)
    }

    private var spentPercentage: Double {
        budgetManager.spentPercentage(for: group)
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

    var body: some View {
        VStack(spacing: 0) {
            // Main card content - tappable for expand/collapse
            Button(action: {
                HapticManager.shared.buttonTap()
                onToggle()
            }) {
                HStack(spacing: 0) {
                    // Color Border
                    Rectangle()
                        .fill(group.color)
                        .frame(width: 8)
                        .cornerRadius(8, corners: [.topLeft, isExpanded ? [] : .bottomLeft])

                    VStack(spacing: DSSpacing.xs) {
                        HStack(alignment: .top) {
                            DSText(group.displayName, font: .dsHeadline, color: theme.colors.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.down.2")
                                .font(.caption)
                                .foregroundColor(theme.colors.textSecondary)
                                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        }
                        
                        HStack(alignment: .bottom, spacing: DSSpacing.xxs) {
                            let remaining = allocatedAmount - spentAmount
                            let text = remaining < 0
                                ? String(format: "%.0f \(budgetManager.budget.currency.code) overspent", abs(remaining))
                                : String(format: "%.0f \(budgetManager.budget.currency.code) left", remaining)
                            let textColor = remaining < 0 ? Color.red : theme.colors.textSecondary
                            DSText(text, font: .dsSubtitle, color: textColor)
                            Spacer()
                        }
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background (total allocated)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(theme.colors.textSecondary.opacity(0.2))
                                    .frame(height: 8)

                                // Progress fill (spent amount) - capped at 100%
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(group.color)
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

            // Expanded content - Sub-category aggregates
            if isExpanded {
                VStack(spacing: 0) {
                    let subCategories = budgetManager.subCategories(for: group)

                    if subCategories.isEmpty {
                        // Show "Add Category" button for empty groups
                        Button(action: {
                            HapticManager.shared.buttonTap()
                            onAddCategory?(group)
                        }) {
                            HStack(spacing: DSSpacing.sm) {
                                Image(systemName: "plus.circle")
                                    .font(.dsBody)
                                    .foregroundColor(group.color)

                                DSText("Add Category", font: .dsBody, color: group.color)
                                    .fontWeight(.medium)
                            }
                            .padding(.vertical, DSSpacing.lg)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(group.color, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                            )
                            .padding(.horizontal, DSSpacing.xl)
                            .padding(.vertical, DSSpacing.md)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .frame(maxWidth: .infinity)
                        .background(theme.colors.surface)
                    } else {
                        ForEach(Array(subCategories.enumerated()), id: \.element.id) { index, subCategory in
                            SubCategoryAggregateRow(
                                subCategory: subCategory,
                                budgetManager: budgetManager,
                                groupColor: group.color,
                                onTap: {
                                    onSubCategoryTap?(subCategory)
                                }
                            )

                            if index < subCategories.count - 1 {
                                Divider()
                                    .background(theme.colors.divider)
                            }
                        }
                    }
                }
                .background(theme.colors.surface)
                .overlay(
                    // Left border continuation
                    HStack {
                        Rectangle()
                            .fill(group.color)
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

struct SubCategoryAggregateRow: View {
    let subCategory: SubCategory
    let budgetManager: any BudgetManagerProtocol
    let groupColor: Color
    let onTap: () -> Void

    @Environment(\.appTheme) private var theme
    @State private var isPressed = false

    private var allocatedAmount: Double {
        budgetManager.budget.categoryAmounts[subCategory.id.uuidString] ?? 0
    }

    private var spentAmount: Double {
        budgetManager.spentAmount(for: subCategory)
    }

    private var spentPercentage: Double {
        guard allocatedAmount > 0 else { return 0 }
        return min(1.0, spentAmount / allocatedAmount)
    }

    private var actualSpentPercentage: Int {
        guard allocatedAmount > 0 else { return 0 }
        return Int((spentAmount / allocatedAmount) * 100)
    }

    private var remainingAmount: Double {
        allocatedAmount - spentAmount
    }

    var body: some View {
        Button(action: {
            HapticManager.shared.buttonTap()
            onTap()
        }) {
            HStack(spacing: DSSpacing.sm) {
                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                    DSText(subCategory.name, font: .dsBody, color: theme.colors.textPrimary)
                    HStack(alignment: .bottom, spacing: DSSpacing.xxs) {
                        let text = remainingAmount < 0
                            ? String(format: "%.0f \(budgetManager.budget.currency.code) overspent", abs(remainingAmount))
                            : String(format: "%.0f \(budgetManager.budget.currency.code) left", remainingAmount)
                        let textColor = remainingAmount < 0 ? Color.red : theme.colors.textSecondary
                        DSText(text, font: .dsCaption, color: textColor)
                    }
                }

                Spacer(minLength: 0)

                // Progress percentage
                let percentageColor = remainingAmount < 0 ? Color.red : theme.colors.textSecondary
                DSText("\(actualSpentPercentage)%", font: .dsBody, color: percentageColor)
                    .fontWeight(.medium)

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.dsSubtitle)
                    .fontWeight(.medium)
                    .foregroundColor(theme.colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DSSpacing.xl) // Extra padding to account for left border
            .padding(.vertical, DSSpacing.sm)
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
    let budgetManager = MockBudgetManager(budget: budget)

    VStack(spacing: DSSpacing.md) {
        CategoryGroupExpendableCard(
            group: .essentials,
            budgetManager: budgetManager,
            isExpanded: false,
            onToggle: {},
            onSubCategoryTap: nil,
            onAddCategory: { group in
                print("Add category to group: \(group.displayName)")
            }
        )

        CategoryGroupExpendableCard(
            group: .essentials,
            budgetManager: budgetManager,
            isExpanded: true,
            onToggle: {},
            onSubCategoryTap: { subCategory in
                print("Tapped sub-category: \(subCategory.name)")
            },
            onAddCategory: { group in
                print("Add category to group: \(group.displayName)")
            }
        )
    }
    .padding(DSSpacing.md)
    .background(AppTheme.shared.colors.background)
}
