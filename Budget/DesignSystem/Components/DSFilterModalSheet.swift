import SwiftUI

/// Comprehensive filter modal sheet for managing all transaction filters
struct DSFilterModalSheet: View {
    @Binding var searchCriteria: SearchCriteria
    let categories: [SubCategory]
    let onApply: () -> Void
    let onClearAll: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @State private var localCriteria: SearchCriteria
    @State private var showCustomDatePicker = false

    init(searchCriteria: Binding<SearchCriteria>, categories: [SubCategory], onApply: @escaping () -> Void, onClearAll: @escaping () -> Void) {
        self._searchCriteria = searchCriteria
        self.categories = categories
        self.onApply = onApply
        self.onClearAll = onClearAll
        self._localCriteria = State(initialValue: searchCriteria.wrappedValue)
    }

    // Check if user has made any changes to filters
    private var hasChanges: Bool {
        localCriteria.selectedCategories != searchCriteria.selectedCategories ||
        localCriteria.selectedCategoryGroups != searchCriteria.selectedCategoryGroups ||
        localCriteria.dateRange?.displayName != searchCriteria.dateRange?.displayName ||
        localCriteria.amountRange != searchCriteria.amountRange
    }

    private var activeFilterCount: Int {
        var count = 0
        if !localCriteria.selectedCategories.isEmpty { count += localCriteria.selectedCategories.count }
        if !localCriteria.selectedCategoryGroups.isEmpty { count += localCriteria.selectedCategoryGroups.count }
        if localCriteria.dateRange != nil { count += 1 }
        if localCriteria.amountRange != nil { count += 1 }
        return count
    }

    // Filter categories based on selected groups
    private var filteredCategories: [SubCategory] {
        if localCriteria.selectedCategoryGroups.isEmpty {
            return categories
        }
        return categories.filter { category in
            localCriteria.selectedCategoryGroups.contains(category.categoryGroup)
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Clear All Filters button at top
                if activeFilterCount > 0 {
                    HStack {
                        Spacer()
                        Button(action: {
                            HapticManager.shared.lightImpact()
                            localCriteria = SearchCriteria()
                        }) {
                            HStack(spacing: DSSpacing.xs) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.dsHeadline)
                                DSText("Clear All", font: .dsBody, color: theme.colors.primary)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(theme.colors.primary)
                        }
                    }
                    .padding(.horizontal, DSSpacing.md)
                    .padding(.vertical, DSSpacing.sm)
                    .background(theme.colors.background)
                }

                ScrollView {
                    VStack(spacing: DSSpacing.xl) {
                        // Date Filters Section - Compact Layout
                        FilterSection(title: "Date Range") {
                            VStack(spacing: DSSpacing.xs) {
                                // Quick date filters - horizontal scroll
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: DSSpacing.xs) {
                                        ForEach(QuickFilter.allCases, id: \.self) { filter in
                                            CompactDateFilterButton(
                                                filter: filter,
                                                isSelected: isQuickFilterSelected(filter),
                                                onTap: {
                                                    HapticManager.shared.filterApplied()
                                                    if isQuickFilterSelected(filter) {
                                                        localCriteria.dateRange = nil
                                                    } else {
                                                        applyQuickFilter(filter)
                                                    }
                                                }
                                            )
                                        }

                                        // Custom date range button
                                        Button(action: {
                                            showCustomDatePicker = true
                                        }) {
                                            HStack(spacing: DSSpacing.xs) {
                                                Image(systemName: "calendar.badge.plus")
                                                    .font(.dsSubtitle)
                                                DSText("Custom", font: .dsCaption, color: theme.colors.textPrimary)
                                                    .fontWeight(.medium)
                                            }
                                            .padding(.horizontal, DSSpacing.sm)
                                            .padding(.vertical, DSSpacing.xs)
                                            .background(theme.colors.surface)
                                            .cornerRadius(8)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(theme.colors.divider, lineWidth: 1)
                                            )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                    .padding(.horizontal, DSSpacing.md)
                                }
                                .padding(.horizontal, -16)
                            }
                        }

                        // Category Groups Section
                        FilterSection(title: "Category Groups") {
                            VStack(spacing: DSSpacing.sm) {
                                ForEach(CategoryGroup.allCases) { group in
                                    CategoryGroupFilterButton(
                                        group: group,
                                        isSelected: localCriteria.selectedCategoryGroups.contains(group),
                                        onTap: {
                                            HapticManager.shared.filterApplied()
                                            toggleCategoryGroup(group)
                                        }
                                    )
                                }
                            }
                        }

                        // Categories Section - Only show categories from selected groups
                        if !filteredCategories.isEmpty {
                            FilterSection(title: localCriteria.selectedCategoryGroups.isEmpty ? "Categories" : "Categories in Selected Groups") {
                                VStack(spacing: DSSpacing.xs) {
                                    ForEach(filteredCategories) { subCategory in
                                        CategoryFilterRow(
                                            subCategory: subCategory,
                                            isSelected: localCriteria.selectedCategories.contains(subCategory.id),
                                            onTap: {
                                                HapticManager.shared.filterApplied()
                                                toggleSubCategory(subCategory.id)
                                            }
                                        )
                                    }
                                }
                            }
                        }

                        // Bottom padding for safe area
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 20)
                    }
                    .padding(.horizontal, DSSpacing.md)
                    .padding(.top, DSSpacing.xs)
                }
            }
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Image(systemName: "xmark")
                        .font(.dsHeadline)
                        .foregroundColor(theme.colors.textPrimary)
                        .onTapGesture {
                            HapticManager.shared.navigationBack()
                            dismiss()
                        }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Group {
                        if activeFilterCount > 0 {
                            DSText("Apply (\(activeFilterCount))", font: .dsBody, color: hasChanges ? theme.colors.primary : theme.colors.textSecondary)
                                .fontWeight(.semibold)
                        } else {
                            DSText("Apply", font: .dsBody, color: hasChanges ? theme.colors.primary : theme.colors.textSecondary)
                                .fontWeight(.semibold)
                        }
                    }
                    .padding(.horizontal, DSSpacing.md)
                    .onTapGesture {
                        if hasChanges {
                            HapticManager.shared.success()
                            searchCriteria = localCriteria
                            onApply()
                            dismiss()
                        }
                    }
                }
            }
            .sheet(isPresented: $showCustomDatePicker) {
                CustomDateRangePicker(
                    startDate: localCriteria.dateRange?.startDate ?? Date(),
                    endDate: localCriteria.dateRange?.endDate ?? Date(),
                    onApply: { start, end in
                        setCustomDateRange(start: start, end: end)
                        showCustomDatePicker = false
                    }
                )
            }
        }
    }

    // MARK: - Helper Methods

    private func isQuickFilterSelected(_ filter: QuickFilter) -> Bool {
        guard let currentRange = localCriteria.dateRange else { return false }

        switch filter {
        case .today:
            return currentRange.displayName == DateRange.today.displayName
        case .thisWeek:
            return currentRange.displayName == DateRange.thisWeek.displayName
        case .thisMonth:
            return currentRange.displayName == DateRange.thisMonth.displayName
        case .last30Days:
            return currentRange.displayName == DateRange.last30Days.displayName
        }
    }

    private func applyQuickFilter(_ filter: QuickFilter) {
        switch filter {
        case .today:
            localCriteria.dateRange = .today
        case .thisWeek:
            localCriteria.dateRange = .thisWeek
        case .thisMonth:
            localCriteria.dateRange = .thisMonth
        case .last30Days:
            localCriteria.dateRange = .last30Days
        }
    }

    private func setCustomDateRange(start: Date, end: Date) {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        let displayName = "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        localCriteria.dateRange = DateRange(
            startDate: start,
            endDate: end,
            displayName: displayName
        )
    }

    private func toggleCategoryGroup(_ group: CategoryGroup) {
        if localCriteria.selectedCategoryGroups.contains(group) {
            localCriteria.selectedCategoryGroups.remove(group)
        } else {
            localCriteria.selectedCategoryGroups.insert(group)
        }
    }

    private func toggleSubCategory(_ id: UUID) {
        if localCriteria.selectedCategories.contains(id) {
            localCriteria.selectedCategories.remove(id)
        } else {
            localCriteria.selectedCategories.insert(id)
        }
    }
}

// MARK: - Supporting Components

struct FilterSection<Content: View>: View {
    let title: String
    let content: Content

    @Environment(\.appTheme) private var theme

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            DSText(title, font: .dsBody, color: theme.colors.textPrimary)
                .fontWeight(.semibold)

            content
        }
    }
}

// Compact horizontal date filter button
struct CompactDateFilterButton: View {
    let filter: QuickFilter
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DSSpacing.xs) {
                DSText(filter.displayName, font: .dsCaption, color: isSelected ? theme.colors.primary : theme.colors.textPrimary)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)
            .background(isSelected ? theme.colors.primary.opacity(0.1) : theme.colors.surface)
            .foregroundColor(isSelected ? theme.colors.primary : theme.colors.textPrimary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? theme.colors.primary : theme.colors.divider, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CategoryGroupFilterButton: View {
    let group: CategoryGroup
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DSSpacing.sm) {
                // Color indicator
                Circle()
                    .fill(group.color)
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                    DSText(group.displayName, font: .dsHeadline, color: theme.colors.textPrimary)
                    DSText(group.description, font: .dsCaption, color: theme.colors.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.dsHeadline)
                        .foregroundColor(theme.colors.primary)
                } else {
                    Spacer(minLength: 20)
                }
            }
            .padding(DSSpacing.md)
            .background(theme.colors.surface)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CategoryFilterRow: View {
    let subCategory: SubCategory
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DSSpacing.sm) {
                // Color indicator
                Circle()
                    .fill(subCategory.categoryGroup.color)
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                    DSText(subCategory.name, font: .dsHeadline, color: theme.colors.textPrimary)
                    DSText(subCategory.categoryGroup.displayName, font: .dsCaption, color: theme.colors.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.dsHeadline)
                        .foregroundColor(theme.colors.primary)
                } else {
                    Spacer(minLength: 20)
                }
            }
            .padding(DSSpacing.md)
            .background(theme.colors.surface)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CustomDateRangePicker: View {
    @State var startDate: Date
    @State var endDate: Date
    let onApply: (Date, Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DSSpacing.md) {
                    // Start Date Picker
                    DSCard {
                        HStack(spacing: DSSpacing.md) {
                            DSText("Start Date", font: .dsBody, color: theme.colors.textPrimary)

                            Spacer()

                            DatePicker("", selection: $startDate, displayedComponents: [.date])
                                .labelsHidden()
                                .tint(theme.colors.primary)
                        }
                    }
                    .padding(.horizontal, DSSpacing.md)

                    // End Date Picker
                    DSCard {
                        HStack(spacing: DSSpacing.md) {
                            DSText("End Date", font: .dsBody, color: theme.colors.textPrimary)

                            Spacer()

                            DatePicker("", selection: $endDate, in: startDate..., displayedComponents: [.date])
                                .labelsHidden()
                                .tint(theme.colors.primary)
                        }
                    }
                    .padding(.horizontal, DSSpacing.md)
                }
                .padding(.top, DSSpacing.md)
            }
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle("Custom Date Range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Image(systemName: "xmark")
                        .font(.dsHeadline)
                        .foregroundColor(theme.colors.textPrimary)
                        .onTapGesture {
                            HapticManager.shared.navigationBack()
                            dismiss()
                        }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Image(systemName: "checkmark")
                        .font(.dsHeadline)
                        .foregroundColor(theme.colors.textPrimary)
                        .onTapGesture {
                            HapticManager.shared.success()
                            onApply(startDate, endDate)
                            dismiss()
                        }
                }
            }
        }
    }
}

#Preview {
    DSFilterModalSheet(
        searchCriteria: .constant(SearchCriteria()),
        categories: [
            SubCategory(name: "Housing", categoryGroup: .essentials),
            SubCategory(name: "Groceries", categoryGroup: .essentials),
            SubCategory(name: "Entertainment", categoryGroup: .lifestyle)
        ],
        onApply: {},
        onClearAll: {}
    )
}
