import SwiftUI


struct CategorySetupView: View {
    @Bindable var onboardingState: OnboardingState
    let onBack: () -> Void
    @State private var showingAddCategory = false
    @State private var editingSubCategory: SubCategory?
    @State private var editingCategoryAmount: Double = 0

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
                editingSubCategory = nil
                editingCategoryAmount = 0
                showingAddCategory = true
            },
            onEditCategory: { subCategory in
                editingSubCategory = subCategory
                editingCategoryAmount = onboardingState.categoryAmounts[subCategory.id.uuidString] ?? 0
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
                subCategory: editingSubCategory,
                allocatedAmount: editingCategoryAmount,
                currency: onboardingState.selectedCurrency ?? Currency(code: "USD", name: "US Dollar", symbol: "$"),
                budgetManager: nil, // No budgetManager during onboarding
                onSuccess: {
                    clearState()
                },
                onSuccessWithValues: { updatedCategory, amount in
                    // Update onboarding state with the new/edited category
                    if let originalCategory = editingSubCategory {
                        // Edit mode - update existing category
                        onboardingState.updateSubCategory(
                            originalCategory,
                            name: updatedCategory.name,
                            group: updatedCategory.categoryGroup,
                            categoryType: updatedCategory.categoryType
                        )
                        onboardingState.updateCategoryAmount(categoryId: originalCategory.id.uuidString, amount: amount)
                    } else {
                        // Add mode - add new category
                        onboardingState.addSubCategory(
                            name: updatedCategory.name,
                            group: updatedCategory.categoryGroup,
                            categoryType: updatedCategory.categoryType,
                            allocatedAmount: amount
                        )
                    }
                },
                onCancel: {
                    clearState()
                }
            )
        }
    }

    private func clearState() {
        editingSubCategory = nil
        editingCategoryAmount = 0
        showingAddCategory = false
    }
}


#Preview {
    let state = OnboardingState()
    state.currentStep = .categorySetup
    return CategorySetupView(onboardingState: state, onBack: {})
}
