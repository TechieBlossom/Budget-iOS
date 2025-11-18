import SwiftUI

/// Reusable category management UI component that can be used in onboarding and settings
struct DSCategoryManagementView: View {
    // MARK: - Properties
    let subCategories: [SubCategory]
    let categoryAmounts: [String: Double]
    let currency: Currency
    let totalAmount: Double
    let showHeader: Bool
    let headerTitle: String?
    let headerSubtitle: String?
    let onBack: (() -> Void)?
    let onAmountChange: (String, Double) -> Void
    let onAddCategory: () -> Void
    let onEditCategory: (SubCategory) -> Void
    let onDeleteCategory: (SubCategory) -> Void
    let onToggleCategoryType: ((SubCategory) -> Void)?
    let onAddCategoryWithGroup: ((CategoryGroup) -> Void)?

    @Environment(\.appTheme) private var theme

    // MARK: - Initializers

    /// Full initializer with all options
    init(
        subCategories: [SubCategory],
        categoryAmounts: [String: Double],
        currency: Currency,
        totalAmount: Double,
        showHeader: Bool = false,
        headerTitle: String? = nil,
        headerSubtitle: String? = nil,
        onBack: (() -> Void)? = nil,
        onAmountChange: @escaping (String, Double) -> Void,
        onAddCategory: @escaping () -> Void,
        onEditCategory: @escaping (SubCategory) -> Void,
        onDeleteCategory: @escaping (SubCategory) -> Void,
        onToggleCategoryType: ((SubCategory) -> Void)? = nil,
        onAddCategoryWithGroup: ((CategoryGroup) -> Void)? = nil
    ) {
        self.subCategories = subCategories
        self.categoryAmounts = categoryAmounts
        self.currency = currency
        self.totalAmount = totalAmount
        self.showHeader = showHeader
        self.headerTitle = headerTitle
        self.headerSubtitle = headerSubtitle
        self.onBack = onBack
        self.onAmountChange = onAmountChange
        self.onAddCategory = onAddCategory
        self.onEditCategory = onEditCategory
        self.onDeleteCategory = onDeleteCategory
        self.onToggleCategoryType = onToggleCategoryType
        self.onAddCategoryWithGroup = onAddCategoryWithGroup
    }

    // MARK: - Computed Properties

    private var formattedTotalAmount: String {
        String(format: "%.2f", totalAmount)
    }

    private func subCategories(for group: CategoryGroup) -> [SubCategory] {
        subCategories.filter { $0.categoryGroup == group }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Optional Header (for onboarding flow)
            if showHeader, let title = headerTitle, let subtitle = headerSubtitle, let backAction = onBack {
                DSHeader(
                    title: title,
                    subtitle: subtitle,
                    buttonType: .back,
                    onBack: backAction
                )
            }

            // Total Budget Display with Add Button
            HStack(spacing: DSSpacing.md) {
                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                    DSText("Total Budget Amount", font: .dsHeadline, color: theme.colors.textPrimary)
                    HStack(alignment: .bottom, spacing: DSSpacing.xxs) {
                        DSText(formattedTotalAmount, font: .dsHeadline, color: theme.colors.textPrimary)
                        DSText(currency.code, font: .dsSubtitle, color: theme.colors.textPrimary)
                    }
                }

                Spacer()

                DSButton("ADD", style: .outline, size: .mini) {
                    onAddCategory()
                }
            }
            .padding(DSSpacing.lg)
            .background(theme.colors.surface)
            .cornerRadius(16)
            .padding(.horizontal, DSSpacing.md)
            .padding(.bottom, DSSpacing.xl)

            // Categories List - Grouped by Category Group
            ScrollView {
                LazyVStack(spacing: DSSpacing.xl) {
                    // Iterate through all category groups
                    ForEach(Array(CategoryGroup.allCases.enumerated()), id: \.element.rawValue) { index, group in
                        let subCategoriesInGroup = subCategories(for: group)

                        if !subCategoriesInGroup.isEmpty {
                            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                                // Section Header
                                HStack(spacing: DSSpacing.xs) {
                                    Circle()
                                        .fill(group.color)
                                        .frame(width: 16, height: 16)

                                    DSText(
                                        group.displayName,
                                        font: .dsHeadline,
                                        color: theme.colors.textSecondary
                                    )
                                    .fontWeight(.semibold)
                                }

                                // Sub-categories in this group
                                VStack(spacing: DSSpacing.xs) {
                                    ForEach(subCategoriesInGroup) { subCategory in
                                        DSCategoryRowWithAmount(
                                            subCategory: subCategory,
                                            currentAmount: categoryAmounts[subCategory.id.uuidString] ?? 0.0,
                                            currency: currency,
                                            onAmountChange: { newAmount in
                                                onAmountChange(subCategory.id.uuidString, newAmount)
                                            },
                                            onDelete: {
                                                onDeleteCategory(subCategory)
                                            },
                                            onEdit: {
                                                onEditCategory(subCategory)
                                            },
                                            onToggleCategoryType: onToggleCategoryType != nil ? {
                                                onToggleCategoryType?(subCategory)
                                            } : nil
                                        )
                                    }

                                    // Add Category button for this group
                                    if let onAddCategoryWithGroup = onAddCategoryWithGroup {
                                        DSButton("Add \(group.displayName) Category", style: .outline, size: .regular) {
                                            onAddCategoryWithGroup(group)
                                        }
                                        .padding(.top, DSSpacing.xxs)
                                    }
                                }
                            }
                        }
                    }

                    // Bottom spacing
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: showHeader ? 120 : 16)
                }
                .padding(.horizontal, DSSpacing.md)
            }
        }
        .background(theme.colors.background)
    }
}

#Preview("Onboarding Style") {
    return DSCategoryManagementView(
        subCategories: SubCategory.createDefault(),
        categoryAmounts: [:],
        currency: Currency(code: "USD", name: "US Dollar", symbol: "$"),
        totalAmount: 0.0,
        showHeader: true,
        headerTitle: "Categories",
        headerSubtitle: "Modify or allocate amount to categories",
        onBack: {},
        onAmountChange: { _, _ in },
        onAddCategory: {},
        onEditCategory: { _ in },
        onDeleteCategory: { _ in }
    )
}

#Preview("Settings Style") {
    let budget = Budget.createSample()

    return DSCategoryManagementView(
        subCategories: budget.categories,
        categoryAmounts: budget.categoryAmounts,
        currency: budget.currency,
        totalAmount: budget.totalAmount,
        showHeader: false,
        onAmountChange: { _, _ in },
        onAddCategory: {},
        onEditCategory: { _ in },
        onDeleteCategory: { _ in }
    )
}
