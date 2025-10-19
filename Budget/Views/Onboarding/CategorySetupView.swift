import SwiftUI


struct CategorySetupView: View {
    @Bindable var onboardingState: OnboardingState
    let onBack: () -> Void
    @State private var showingAddCategory = false
    @State private var newCategoryName = ""
    @State private var selectedGroup: CategoryGroup?
    @State private var editingSubCategory: SubCategory?
    @State private var isEditMode = false
    @State private var editingCategoryType: CategoryType = .expense

    @Environment(\.appTheme) private var theme

    var body: some View {
        DSCategoryManagementView(
            subCategories: onboardingState.categoryManager.subCategories,
            categoryAmounts: onboardingState.categoryAmounts,
            currency: onboardingState.selectedCurrency ?? Currency(code: "USD", name: "US Dollar", symbol: "$"),
            totalAmount: onboardingState.totalBudgetAmount,
            showHeader: true,
            headerTitle: "Categories",
            headerSubtitle: "Modify or allocate amount to categories",
            onBack: onBack,
            onAmountChange: { categoryId, newAmount in
                onboardingState.updateCategoryAmount(categoryId: categoryId, amount: newAmount)
            },
            onAddCategory: {
                isEditMode = false
                newCategoryName = ""
                selectedGroup = nil
                editingCategoryType = .expense
                showingAddCategory = true
            },
            onEditCategory: { subCategory in
                isEditMode = true
                editingSubCategory = subCategory
                newCategoryName = subCategory.name
                selectedGroup = subCategory.categoryGroup
                editingCategoryType = subCategory.categoryType
                showingAddCategory = true
            },
            onDeleteCategory: { subCategory in
                onboardingState.removeSubCategory(subCategory)
            },
            onToggleCategoryType: { subCategory in
                onboardingState.toggleCategoryType(for: subCategory)
            }
        )
        .sheet(isPresented: $showingAddCategory) {
            DSAddCategorySheet(
                categoryName: $newCategoryName,
                selectedGroup: $selectedGroup,
                categoryType: editingCategoryType,
                isEditMode: isEditMode,
                onSave: { group, categoryType in
                    if !newCategoryName.isEmpty {
                        if isEditMode, let subCategory = editingSubCategory {
                            // Update existing sub-category
                            onboardingState.updateSubCategory(subCategory, name: newCategoryName, categoryType: categoryType)
                        } else {
                            // Add new sub-category
                            onboardingState.addSubCategory(name: newCategoryName, group: group, categoryType: categoryType)
                        }
                        newCategoryName = ""
                        selectedGroup = nil
                        editingSubCategory = nil
                        isEditMode = false
                        showingAddCategory = false
                    }
                },
                onCancel: {
                    newCategoryName = ""
                    selectedGroup = nil
                    editingSubCategory = nil
                    isEditMode = false
                    showingAddCategory = false
                }
            )
        }
    }
}


#Preview {
    let state = OnboardingState()
    state.currentStep = .categorySetup
    return CategorySetupView(onboardingState: state, onBack: {})
}
