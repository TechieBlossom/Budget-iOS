import SwiftUI

struct DSAddCategorySheet: View {
    @Binding var categoryName: String
    @Binding var selectedGroup: CategoryGroup?
    let onSave: (CategoryGroup, CategoryType) -> Void
    let onCancel: () -> Void
    let isEditMode: Bool

    @State private var showingGroupSelection = false
    @State private var categoryType: CategoryType
    @Environment(\.appTheme) private var theme

    init(
        categoryName: Binding<String>,
        selectedGroup: Binding<CategoryGroup?>,
        categoryType: CategoryType? = nil,
        isEditMode: Bool = false,
        onSave: @escaping (CategoryGroup, CategoryType) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._categoryName = categoryName
        self._selectedGroup = selectedGroup
        self.isEditMode = isEditMode
        self.onSave = onSave
        self.onCancel = onCancel
        // Initialize categoryType based on group or provided value
        if let type = categoryType {
            self._categoryType = State(initialValue: type)
        } else if let group = selectedGroup.wrappedValue {
            self._categoryType = State(initialValue: group == .financialGoals ? .savings : .expense)
        } else {
            self._categoryType = State(initialValue: .expense)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DSSpacing.xl) {
                    // Category Name Input
                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        DSText("Category Name", font: .dsHeadline, color: theme.colors.textPrimary)
                        DSTextField("e.g., Travel, Hobbies, Pets", text: $categoryName, autocapitalization: .words)
                            .onChange(of: categoryName) { _, newValue in
                                if newValue.count > 30 {
                                    categoryName = String(newValue.prefix(30))
                                }
                            }
                    }
                    .padding(.horizontal, DSSpacing.md)
                    .padding(.top, DSSpacing.xl)

                    // Category Group Selection Button
                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        DSText("Category Group", font: .dsHeadline, color: theme.colors.textPrimary)
                            .padding(.horizontal, DSSpacing.md)

                        Button(action: {
                            showingGroupSelection = true
                        }) {
                            HStack(spacing: DSSpacing.sm) {
                                if let group = selectedGroup {
                                    Circle()
                                        .fill(group.color)
                                        .frame(width: 12, height: 12)

                                    VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                                        DSText(group.displayName, font: .dsHeadline, color: theme.colors.textPrimary)
                                        DSText(group.description, font: .dsCaption, color: theme.colors.textSecondary)
                                            .lineLimit(1)
                                    }
                                } else {
                                    DSText("Select Category Group", font: .dsHeadline, color: theme.colors.textSecondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.dsSubtitle)
                                    .foregroundColor(theme.colors.textSecondary)
                            }
                            .padding(DSSpacing.md)
                            .background(theme.colors.surface)
                            .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, DSSpacing.md)
                        .onChange(of: selectedGroup) { _, newGroup in
                            // Update categoryType when group changes
                            if let group = newGroup {
                                categoryType = group == .financialGoals ? .savings : .expense
                            }
                        }
                    }

                    // Category Type Toggle
                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        DSText("Category Type", font: .dsHeadline, color: theme.colors.textPrimary)
                            .padding(.horizontal, DSSpacing.md)

                        HStack {
                            DSText("Savings", font: .dsBody, color: theme.colors.textPrimary)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { categoryType == .savings },
                                set: { isSavings in
                                    categoryType = isSavings ? .savings : .expense
                                }
                            ))
                            .labelsHidden()
                            .tint(theme.colors.primary)
                        }
                        .padding(DSSpacing.md)
                        .background(theme.colors.surface)
                        .cornerRadius(12)
                        .padding(.horizontal, DSSpacing.md)
                    }

                    // Extra padding for keyboard
                    Spacer()
                        .frame(height: 100)
                }
            }
            .background(theme.colors.background)
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    DSText(isEditMode ? "Edit Category" : "Add Category", font: .dsHeadline, color: theme.colors.textPrimary)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Image(systemName: "xmark")
                        .font(.dsHeadline)
                        .foregroundColor(theme.colors.textPrimary)
                        .onTapGesture {
                            onCancel()
                        }
                }
                if (!categoryName.isEmpty && selectedGroup != nil) {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Image(systemName: "checkmark")
                            .font(.dsHeadline)
                            .foregroundStyle(theme.colors.textPrimary, theme.colors.surface)
                            .onTapGesture {
                                if let group = selectedGroup {
                                    onSave(group, categoryType)
                                }
                            }
                    }
                }
            }
            .sheet(isPresented: $showingGroupSelection) {
                DSCategoryGroupSelectionSheet(
                    selectedGroup: $selectedGroup,
                    onSelect: { group in
                        selectedGroup = group
                    }
                )
            }
        }
    }
}

#Preview {
    @Previewable @State var categoryName = ""
    @Previewable @State var selectedGroup: CategoryGroup? = nil

    DSAddCategorySheet(
        categoryName: $categoryName,
        selectedGroup: $selectedGroup,
        onSave: { group, categoryType in
            print("Saved sub-category: \(categoryName), group: \(group.displayName), type: \(categoryType.displayName)")
        },
        onCancel: {
            print("Cancelled")
        }
    )
}
