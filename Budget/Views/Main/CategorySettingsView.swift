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
    @State private var totalBudgetAmount: Double
    @State private var showingDeleteConfirmation = false
    @State private var subCategoryToDelete: SubCategory?
    @State private var editingSubCategory: SubCategory?
    @State private var editingCategoryAmount: Double = 0
    @State private var refreshTrigger = 0

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
                $0.categoryType == subCategory.categoryType &&
                $0.categoryGroup == subCategory.categoryGroup
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
                    editingSubCategory = nil
                    editingCategoryAmount = 0
                    showingAddCategory = true
                },
                onEditCategory: { subCategory in
                    editingSubCategory = subCategory
                    editingCategoryAmount = categoryAmounts[subCategory.id.uuidString] ?? 0
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
            .id(refreshTrigger)
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
                        .foregroundColor(hasChanges ? theme.colors.primary : theme.colors.textSecondary)
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
                subCategory: editingSubCategory,
                allocatedAmount: editingCategoryAmount,
                currency: currentBudget.currency,
                budgetManager: budgetManager,
                onSuccess: {
                    // Reload budget data from Supabase after successful save
                    reloadBudgetData()
                    clearAddCategoryState()
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

    private func removeSubCategory(_ subCategory: SubCategory) {
        print("🗑️ CategorySettingsView: Deleting category \(subCategory.name)...")

        Task {
            guard let manager = budgetManager as? BudgetManager else {
                // Fallback for MockBudgetManager - just update locally
                await MainActor.run {
                    _ = budgetManager.deleteAllTransactions(for: subCategory)
                    subCategories.removeAll { $0.id == subCategory.id }
                    categoryAmounts.removeValue(forKey: subCategory.id.uuidString)
                    updateTotalBudgetAmount()
                }
                return
            }

            // Use the new async deleteCategory method
            let success = await manager.deleteCategory(subCategory.id)

            await MainActor.run {
                if success {
                    print("   ✅ Category deleted successfully")
                    // Reload the budget data from manager to reflect changes
                    reloadBudgetData()
                } else {
                    print("   ❌ Failed to delete category")
                    // Show error to user
                    if let error = manager.lastError {
                        print("   Error: \(error)")
                    }
                }
            }
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
        editingSubCategory = nil
        editingCategoryAmount = 0
        showingAddCategory = false
    }

    private func updateTotalBudgetAmount() {
        totalBudgetAmount = categoryAmounts.values.reduce(0, +)
    }

    private func reloadBudgetData() {
        print("🔄 Reloading budget data from budgetManager...")
        let freshBudget = budgetManager.budget
        print("   Fresh budget has \(freshBudget.categories.count) categories")
        print("   Fresh categoryAmounts: \(freshBudget.categoryAmounts)")
        subCategories = freshBudget.categories
        categoryAmounts = freshBudget.categoryAmounts
        updateTotalBudgetAmount()

        // Force view refresh by toggling the trigger
        refreshTrigger += 1

        print("   ✅ UI refreshed with latest data (trigger: \(refreshTrigger))")
        print("   Local categoryAmounts now: \(categoryAmounts)")
    }

    private func saveCategoryChanges() {
        print("💾 CategorySettingsView: Saving category changes...")
        print("   Budget ID: \(currentBudget.id)")
        print("   Number of categories: \(subCategories.count)")

        // Log what changed
        if subCategories.count != currentBudget.categories.count {
            print("   ⚠️ Category count changed: \(currentBudget.categories.count) → \(subCategories.count)")
        }

        for subCategory in subCategories {
            if let original = currentBudget.categories.first(where: { $0.id == subCategory.id }) {
                if original.name != subCategory.name {
                    print("   📝 Category name changed: '\(original.name)' → '\(subCategory.name)'")
                }
                if original.categoryGroup != subCategory.categoryGroup {
                    print("   🔄 Category group changed for '\(subCategory.name)': \(original.categoryGroup.displayName) → \(subCategory.categoryGroup.displayName)")
                }
                if original.categoryType != subCategory.categoryType {
                    print("   🔀 Category type changed for '\(subCategory.name)': \(original.categoryType.displayName) → \(subCategory.categoryType.displayName)")
                }
            }
        }

        let updatedBudget = Budget(
            id: currentBudget.id,
            period: currentBudget.period,
            currency: currentBudget.currency,
            categories: subCategories,
            categoryAmounts: categoryAmounts
        )

        print("   ➡️ Saving via async updateBudget...")
        Task {
            guard let manager = budgetManager as? BudgetManager else {
                // Fallback for MockBudgetManager in previews
                onUpdateBudget(updatedBudget)
                dismiss()
                return
            }

            let success = await manager.updateBudget(updatedBudget)
            await MainActor.run {
                if success {
                    print("   ✅ Category changes saved successfully")
                    dismiss()
                } else {
                    print("   ❌ Failed to save category changes")
                    if let error = manager.lastError {
                        print("   Error: \(error)")
                    }
                }
            }
        }
    }
}


#Preview {
    let budget = Budget.createSample()
    
    CategorySettingsView(currentBudget: budget, budgetManager: MockBudgetManager(budget: budget)) { updatedBudget in
        print("Updated budget with \(updatedBudget.categories.count) categories")
    }
}
