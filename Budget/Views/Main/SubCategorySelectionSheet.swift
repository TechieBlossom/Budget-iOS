import SwiftUI

struct SubCategorySelectionSheet: View {
    let subCategories: [SubCategory]
    @Binding var selectedSubCategory: SubCategory?
    let onSelect: (SubCategory) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    // Group sub-categories by category group
    private var groupedSubCategories: [(CategoryGroup, [SubCategory])] {
        let grouped = Dictionary(grouping: subCategories) { $0.categoryGroup }
        return CategoryGroup.allCases.compactMap { group in
            guard let subs = grouped[group], !subs.isEmpty else { return nil }
            return (group, subs)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: DSSpacing.xl) {
                    ForEach(groupedSubCategories, id: \.0) { group, subCategoriesInGroup in
                        VStack(alignment: .leading, spacing: DSSpacing.sm) {
                            // Section Header
                            HStack(spacing: DSSpacing.xs) {
                                Circle()
                                    .fill(group.color)
                                    .frame(width: 8, height: 8)

                                DSText(group.displayName.uppercased(), font: .dsCaption, color: theme.colors.textSecondary)
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, DSSpacing.md)

                            // Sub-categories in this group
                            VStack(spacing: DSSpacing.xs) {
                                ForEach(subCategoriesInGroup) { subCategory in
                                    Button(action: {
                                        HapticManager.shared.categorySelected()
                                        selectedSubCategory = subCategory
                                        onSelect(subCategory)
                                        dismiss()
                                    }) {
                                        HStack(spacing: 0) {
                                            // Color bar
                                            Rectangle()
                                                .fill(group.color)
                                                .frame(width: 8)
                                                .cornerRadius(8, corners: [.topLeft, .bottomLeft])

                                            HStack(spacing: DSSpacing.sm) {
                                                DSText(subCategory.name, font: .dsHeadline, color: theme.colors.textPrimary)
                                                    .lineLimit(1)

                                                Spacer()

                                                if selectedSubCategory?.id == subCategory.id {
                                                    Image(systemName: "checkmark")
                                                        .font(.dsHeadline)
                                                        .foregroundColor(theme.colors.primary)
                                                }
                                            }
                                            .padding(.horizontal, DSSpacing.md)
                                            .padding(.vertical, DSSpacing.md)
                                        }
                                        .background(theme.colors.surface)
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, DSSpacing.md)
                        }
                    }

                    // Bottom spacing
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 20)
                }
                .padding(.top, DSSpacing.md)
            }
            .background(theme.colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    DSText("Select Category", font: .dsHeadline, color: theme.colors.textPrimary)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Image(systemName: "xmark")
                        .font(.dsHeadline)
                        .foregroundColor(theme.colors.textPrimary)
                        .onTapGesture {
                            dismiss()
                        }
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var selectedSubCategory: SubCategory? = nil

    let subCategories = SubCategory.createDefault()

    SubCategorySelectionSheet(
        subCategories: subCategories,
        selectedSubCategory: $selectedSubCategory,
        onSelect: { subCategory in
            print("Selected: \(subCategory.name)")
        }
    )
}
