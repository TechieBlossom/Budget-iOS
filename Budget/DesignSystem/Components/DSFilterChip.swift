import SwiftUI

struct DSFilterChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    let onRemove: (() -> Void)?

    @Environment(\.appTheme) private var theme

    init(_ title: String, isSelected: Bool = false, onTap: @escaping () -> Void, onRemove: (() -> Void)? = nil) {
        self.title = title
        self.isSelected = isSelected
        self.onTap = onTap
        self.onRemove = onRemove
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DSSpacing.xs) {
                DSText(title, font: .dsCaption, color: textColor)
                    .fontWeight(.medium)

                if let onRemove = onRemove, isSelected {
                    Button(action: onRemove) {
                        Image(systemName: "xmark")
                            .font(.dsCaption)
                        .fontWeight(.bold)
                            .foregroundColor(textColor)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)
            .background(backgroundColor)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(PlainButtonStyle())
    }

    private var backgroundColor: Color {
        if isSelected {
            return theme.colors.primary.opacity(0.1)
        } else {
            return theme.colors.surface
        }
    }

    private var textColor: Color {
        return isSelected ? theme.colors.primary : theme.colors.textSecondary
    }

    private var borderColor: Color {
        return isSelected ? theme.colors.primary : theme.colors.divider
    }
}

struct DSQuickFilterChip: View {
    let filter: QuickFilter
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DSSpacing.xs) {
                DSText(filter.displayName, font: .dsCaption, color: textColor)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, 9)
            .background(backgroundColor)
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var backgroundColor: Color {
        if isSelected {
            return theme.colors.primary.opacity(0.15)
        } else {
            return theme.colors.surface
        }
    }

    private var textColor: Color {
        return isSelected ? theme.colors.primary : theme.colors.textSecondary
    }

    private var borderColor: Color {
        return isSelected ? theme.colors.primary : theme.colors.divider
    }
}

// Category Filter Chip
struct DSSubCategoryFilterChip: View {
    let subCategory: SubCategory
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DSSpacing.xs) {
                Circle()
                    .fill(subCategory.categoryGroup.color)
                    .frame(width: 12, height: 12)

                DSText(subCategory.name, font: .dsCaption, color: textColor)
                    .fontWeight(.medium)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.dsCaption)
                        .fontWeight(.bold)
                        .foregroundColor(textColor)
                }
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)
            .background(backgroundColor)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var backgroundColor: Color {
        if isSelected {
            return subCategory.categoryGroup.color.opacity(0.2)
        } else {
            return theme.colors.surface
        }
    }

    private var textColor: Color {
        return isSelected ? theme.colors.primary : theme.colors.textSecondary
    }

    private var borderColor: Color {
        return isSelected ? subCategory.categoryGroup.color : theme.colors.divider
    }
}

// Category Group Filter Chip
struct DSCategoryGroupFilterChip: View {
    let group: CategoryGroup
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DSSpacing.xs) {
                Circle()
                    .fill(group.color)
                    .frame(width: 12, height: 12)

                DSText(group.displayName, font: .dsCaption, color: textColor)
                    .fontWeight(.medium)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.dsCaption)
                        .fontWeight(.bold)
                        .foregroundColor(textColor)
                }
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)
            .background(backgroundColor)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var backgroundColor: Color {
        if isSelected {
            return group.color.opacity(0.2)
        } else {
            return theme.colors.surface
        }
    }

    private var textColor: Color {
        return isSelected ? theme.colors.primary : theme.colors.textSecondary
    }

    private var borderColor: Color {
        return isSelected ? group.color : theme.colors.divider
    }
}

#Preview {
    VStack(spacing: DSSpacing.md) {
        // Regular filter chips
        HStack {
            DSFilterChip("All", isSelected: true, onTap: {})
            DSFilterChip("Active", isSelected: false, onTap: {})
            DSFilterChip("Selected", isSelected: true, onTap: {}, onRemove: {})
        }

        // Quick filter chips
        HStack {
            DSQuickFilterChip(filter: .today, isSelected: true, onTap: {})
            DSQuickFilterChip(filter: .thisWeek, isSelected: false, onTap: {})
            DSQuickFilterChip(filter: .thisMonth, isSelected: false, onTap: {})
        }

        // Sub-category filter chips
        let sampleSubCategory = SubCategory(name: "Food", categoryGroup: .lifestyle)
        HStack {
            DSSubCategoryFilterChip(subCategory: sampleSubCategory, isSelected: false, onTap: {})
            DSSubCategoryFilterChip(subCategory: sampleSubCategory, isSelected: true, onTap: {})
        }

        // Category group filter chips
        HStack {
            DSCategoryGroupFilterChip(group: .essentials, isSelected: false, onTap: {})
            DSCategoryGroupFilterChip(group: .lifestyle, isSelected: true, onTap: {})
        }
    }
    .padding(DSSpacing.md)
    .background(AppTheme.shared.colors.background)
}
