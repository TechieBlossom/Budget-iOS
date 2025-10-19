import SwiftUI

struct CategorySettingsView: View {
    let currentBudget: Budget
    let budgetManager: any BudgetManagerProtocol
    let onUpdateBudget: (Budget) -> Void

    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var subCategories: [SubCategory]
    @State private var categoryAmounts: [String: Double]
    @State private var showingAddCategory = false
    @State private var newCategoryName = ""
    @State private var selectedGroup: CategoryGroup?
    @State private var totalBudgetAmount: Double
    @State private var showingDeleteConfirmation = false
    @State private var subCategoryToDelete: SubCategory?
    @State private var editingSubCategory: SubCategory?
    @State private var isEditMode = false
    @State private var editingCategoryType: CategoryType = .expense

    init(currentBudget: Budget, budgetManager: any BudgetManagerProtocol, onUpdateBudget: @escaping (Budget) -> Void) {
        self.currentBudget = currentBudget
        self.budgetManager = budgetManager
        self.onUpdateBudget = onUpdateBudget
        self._subCategories = State(initialValue: currentBudget.categories)
        self._categoryAmounts = State(initialValue: currentBudget.categoryAmounts)
        self._totalBudgetAmount = State(initialValue: currentBudget.totalAmount)
    }

    private var hasChanges: Bool {
        // Check if sub-categories changed
        if subCategories.count != currentBudget.categories.count {
            return true
        }

        // Check if any sub-category changed
        for subCategory in subCategories {
            if !currentBudget.categories.contains(where: {
                $0.id == subCategory.id &&
                $0.name == subCategory.name &&
                $0.categoryType == subCategory.categoryType
            }) {
                return true
            }
        }

        // Check if amounts changed
        if categoryAmounts != currentBudget.categoryAmounts {
            return true
        }

        return false
    }

    var body: some View {
        NavigationStack {
            DSCategoryManagementView(
                subCategories: subCategories,
                categoryAmounts: categoryAmounts,
                currency: currentBudget.currency,
                totalAmount: totalBudgetAmount,
                showHeader: false,
                onAmountChange: { categoryId, newAmount in
                    categoryAmounts[categoryId] = newAmount
                    updateTotalBudgetAmount()
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
                    subCategoryToDelete = subCategory
                    showingDeleteConfirmation = true
                },
                onToggleCategoryType: { subCategory in
                    toggleCategoryType(for: subCategory)
                }
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        DSText("Category Settings", font: .dsHeadline, color: theme.colors.textPrimary)
                        DSText(currentBudget.budgetName, font: .dsCaption, color: theme.colors.textSecondary)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Image(systemName: "xmark")
                        .font(.dsHeadline)
                        .foregroundColor(theme.colors.textPrimary)
                        .onTapGesture {
                            dismiss()
                        }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Image(systemName: "checkmark")
                        .font(.dsHeadline)
                        .foregroundColor(hasChanges ? theme.colors.textPrimary : theme.colors.textSecondary)
                        .onTapGesture {
                            if hasChanges {
                                saveCategoryChanges()
                            }
                        }
                }
            }
        }
        .sheet(isPresented: $showingAddCategory) {
            DSAddCategorySheet(
                categoryName: $newCategoryName,
                selectedGroup: $selectedGroup,
                categoryType: editingCategoryType,
                isEditMode: isEditMode,
                onSave: { group, categoryType in
                    if isEditMode, let subCategory = editingSubCategory {
                        updateSubCategory(subCategory, name: newCategoryName, categoryType: categoryType)
                    } else {
                        addNewSubCategory(group: group, categoryType: categoryType)
                    }
                },
                onCancel: {
                    clearAddCategoryState()
                }
            )
        }
        .alert("Delete Category", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let subCategory = subCategoryToDelete {
                    removeSubCategory(subCategory)
                }
            }
        } message: {
            if let subCategory = subCategoryToDelete {
                let transactionCount = budgetManager.getAllTransactions().filter { $0.categoryId == subCategory.id }.count
                if transactionCount > 0 {
                    Text("Are you sure you want to delete '\(subCategory.name)'?\n\n⚠️ This will permanently delete \(transactionCount) transaction\(transactionCount == 1 ? "" : "s") associated with this sub-category.\n\nThis action cannot be undone.")
                } else {
                    Text("Are you sure you want to delete '\(subCategory.name)'?\n\nThis action cannot be undone.")
                }
            }
        }
    }
    
    // MARK: - Helper Methods

    private func addNewSubCategory(group: CategoryGroup, categoryType: CategoryType) {
        guard !newCategoryName.isEmpty,
              !subCategories.contains(where: { $0.name.lowercased() == newCategoryName.lowercased() }) else {
            return
        }

        let newSubCategory = SubCategory(
            name: newCategoryName,
            categoryGroup: group,
            categoryType: categoryType
        )

        subCategories.append(newSubCategory)
        categoryAmounts[newSubCategory.id.uuidString] = 0.0
        clearAddCategoryState()
    }

    private func removeSubCategory(_ subCategory: SubCategory) {
        // Delete all transactions associated with this sub-category
        _ = budgetManager.deleteAllTransactions(for: subCategory)

        // Remove the sub-category from the budget
        subCategories.removeAll { $0.id == subCategory.id }
        categoryAmounts.removeValue(forKey: subCategory.id.uuidString)
        updateTotalBudgetAmount()
    }

    private func updateSubCategory(_ subCategory: SubCategory, name: String, categoryType: CategoryType? = nil) {
        if let index = subCategories.firstIndex(where: { $0.id == subCategory.id }) {
            subCategories[index] = SubCategory(
                id: subCategory.id,
                name: name,
                categoryGroup: subCategory.categoryGroup,
                categoryType: categoryType ?? subCategory.categoryType
            )
        }
    }

    private func toggleCategoryType(for subCategory: SubCategory) {
        if let index = subCategories.firstIndex(where: { $0.id == subCategory.id }) {
            let newType: CategoryType = subCategory.categoryType == .expense ? .savings : .expense
            subCategories[index] = SubCategory(
                id: subCategory.id,
                name: subCategory.name,
                categoryGroup: subCategory.categoryGroup,
                categoryType: newType
            )
        }
    }

    private func clearAddCategoryState() {
        newCategoryName = ""
        selectedGroup = nil
        editingSubCategory = nil
        isEditMode = false
        showingAddCategory = false
    }

    private func updateTotalBudgetAmount() {
        totalBudgetAmount = categoryAmounts.values.reduce(0, +)
    }

    private func saveCategoryChanges() {
        let updatedBudget = Budget(
            id: currentBudget.id,
            period: currentBudget.period,
            currency: currentBudget.currency,
            categories: subCategories,
            categoryAmounts: categoryAmounts
        )

        onUpdateBudget(updatedBudget)
        dismiss()
    }
}


#Preview {
    let budget = Budget.createSample()
    
    CategorySettingsView(currentBudget: budget, budgetManager: MockBudgetManager(budget: budget)) { updatedBudget in
        print("Updated budget with \(updatedBudget.categories.count) categories")
    }
}
