import SwiftUI

struct DSAddCategorySheet: View {
    let subCategory: SubCategory?
    let allocatedAmount: Double
    let currency: Currency
    let budgetManager: (any BudgetManagerProtocol)?
    let onSuccess: () -> Void
    let onSuccessWithValues: ((SubCategory, Double) -> Void)?
    let onCancel: () -> Void

    @State private var editState: CategoryEditState
    @State private var showingGroupSelection = false
    @State private var amountText: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    init(
        subCategory: SubCategory?,
        allocatedAmount: Double,
        currency: Currency,
        budgetManager: (any BudgetManagerProtocol)?,
        preSelectedGroup: CategoryGroup? = nil,
        onSuccess: @escaping () -> Void,
        onSuccessWithValues: ((SubCategory, Double) -> Void)? = nil,
        onCancel: @escaping () -> Void
    ) {
        self.subCategory = subCategory
        self.allocatedAmount = allocatedAmount
        self.currency = currency
        self.budgetManager = budgetManager
        self.onSuccess = onSuccess
        self.onSuccessWithValues = onSuccessWithValues
        self.onCancel = onCancel

        // Initialize edit state
        if let subCategory = subCategory {
            // Edit mode
            self._editState = State(initialValue: CategoryEditState(
                subCategory: subCategory,
                allocatedAmount: allocatedAmount
            ))
        } else {
            // Add mode with optional pre-selected group
            var initialState = CategoryEditState()
            if let preSelectedGroup = preSelectedGroup {
                initialState.group = preSelectedGroup
                // Auto-update type based on group
                if preSelectedGroup == .financialGoals {
                    initialState.type = .savings
                }
            }
            self._editState = State(initialValue: initialState)
        }

        // Initialize amount text
        self._amountText = State(initialValue: allocatedAmount > 0 ? String(format: "%.2f", allocatedAmount) : "")
    }

    private var isEditMode: Bool {
        subCategory != nil
    }

    private var hasChanges: Bool {
        guard isEditMode else {
            // In add mode, just check if form is valid
            return editState.isValid
        }
        return editState.hasChanges && editState.isValid
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: DSSpacing.xl) {
                        // Category Name Input
                        VStack(alignment: .leading, spacing: DSSpacing.sm) {
                            DSText("Category Name", font: .dsHeadline, color: theme.colors.textPrimary)
                            DSTextField("e.g., Travel, Hobbies, Pets", text: $editState.name, autocapitalization: .words)
                                .disabled(isSaving)
                                .onChange(of: editState.name) { _, newValue in
                                    if newValue.count > 30 {
                                        editState.name = String(newValue.prefix(30))
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
                                if !isSaving {
                                    showingGroupSelection = true
                                }
                            }) {
                                HStack(spacing: DSSpacing.sm) {
                                    Circle()
                                        .fill(editState.group.color)
                                        .frame(width: 12, height: 12)

                                    VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                                        DSText(editState.group.displayName, font: .dsHeadline, color: theme.colors.textPrimary)
                                        DSText(editState.group.description, font: .dsCaption, color: theme.colors.textSecondary)
                                            .lineLimit(1)
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
                            .disabled(isSaving)
                        }

                        // Category Type Toggle
                        VStack(alignment: .leading, spacing: DSSpacing.sm) {
                            DSText("Category Type", font: .dsHeadline, color: theme.colors.textPrimary)
                                .padding(.horizontal, DSSpacing.md)

                            HStack {
                                DSText("Savings", font: .dsBody, color: theme.colors.textPrimary)
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { editState.type == .savings },
                                    set: { isSavings in
                                        editState.type = isSavings ? .savings : .expense
                                    }
                                ))
                                .labelsHidden()
                                .tint(theme.colors.primary)
                                .disabled(isSaving)
                            }
                            .padding(DSSpacing.md)
                            .background(theme.colors.surface)
                            .cornerRadius(12)
                            .padding(.horizontal, DSSpacing.md)
                        }

                        // Allocated Amount Input
                        VStack(alignment: .leading, spacing: DSSpacing.sm) {
                            DSText("Allocated Amount", font: .dsHeadline, color: theme.colors.textPrimary)
                            HStack(spacing: DSSpacing.xs) {
                                DSText(currency.symbol, font: .dsBody, color: theme.colors.textSecondary)
                                DSTextField("0.00", text: $amountText, keyboardType: .decimalPad)
                                    .disabled(isSaving)
                                    .onChange(of: amountText) { _, newValue in
                                        if let amount = Double(newValue) {
                                            editState.amount = amount
                                        } else if newValue.isEmpty {
                                            editState.amount = 0
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, DSSpacing.md)

                        // Error Message
                        if let errorMessage = errorMessage {
                            DSText(errorMessage, font: .dsCaption, color: .red)
                                .padding(.horizontal, DSSpacing.md)
                        }

                        // Extra padding for keyboard
                        Spacer()
                            .frame(height: 100)
                    }
                }
                .background(theme.colors.background)
                .scrollDismissesKeyboard(.interactively)

                // Loading Overlay
                if isSaving {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    VStack(spacing: DSSpacing.md) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(theme.colors.primary)
                        DSText("Saving...", font: .dsBody, color: theme.colors.textPrimary)
                    }
                    .padding(DSSpacing.xl)
                    .background(theme.colors.surface)
                    .cornerRadius(12)
                }
            }
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
                            if !isSaving {
                                onCancel()
                                dismiss()
                            }
                        }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Image(systemName: "checkmark")
                        .font(.dsHeadline)
                        .foregroundColor(hasChanges ? theme.colors.primary : theme.colors.textSecondary)
                        .onTapGesture {
                            if hasChanges && !isSaving {
                                saveCategory()
                            }
                        }
                }
            }
            .sheet(isPresented: $showingGroupSelection) {
                DSCategoryGroupSelectionSheet(
                    selectedGroup: Binding(
                        get: { editState.group },
                        set: { newGroup in
                            if let newGroup = newGroup {
                                editState.group = newGroup
                                // Auto-update type based on group
                                if newGroup == .financialGoals {
                                    editState.type = .savings
                                }
                            }
                        }
                    ),
                    onSelect: { group in
                        editState.group = group
                        if group == .financialGoals {
                            editState.type = .savings
                        }
                    }
                )
            }
        }
    }

    private func saveCategory() {
        // If no budget manager (onboarding flow), call success with values
        guard let budgetManager = budgetManager else {
            if let subCategory = subCategory {
                // Edit mode - return updated category
                let updatedCategory = SubCategory(
                    id: subCategory.id,
                    name: editState.name,
                    categoryGroup: editState.group,
                    categoryType: editState.type
                )
                onSuccessWithValues?(updatedCategory, editState.amount)
            } else {
                // Add mode - return new category
                let newCategory = SubCategory(
                    name: editState.name,
                    categoryGroup: editState.group,
                    categoryType: editState.type
                )
                onSuccessWithValues?(newCategory, editState.amount)
            }
            onSuccess()
            dismiss()
            return
        }

        isSaving = true
        errorMessage = nil

        Task {
            do {
                if let subCategory = subCategory {
                    // Edit existing category
                    let updatedCategory = SubCategory(
                        id: subCategory.id,
                        name: editState.name,
                        categoryGroup: editState.group,
                        categoryType: editState.type
                    )

                    let currentBudget = budgetManager.budget
                    var mutableCategories = currentBudget.categories
                    var mutableAmounts = currentBudget.categoryAmounts

                    if let index = mutableCategories.firstIndex(where: { $0.id == subCategory.id }) {
                        print("   📝 Updating mutableAmounts[\(subCategory.id.uuidString)] from \(mutableAmounts[subCategory.id.uuidString] ?? -1) to \(editState.amount)")
                        mutableCategories[index] = updatedCategory
                        mutableAmounts[subCategory.id.uuidString] = editState.amount
                        print("   ✅ mutableAmounts[\(subCategory.id.uuidString)] is now \(mutableAmounts[subCategory.id.uuidString] ?? -1)")
                    }

                    let updatedBudget = Budget(
                        id: currentBudget.id,
                        period: currentBudget.period,
                        currency: currentBudget.currency,
                        categories: mutableCategories,
                        categoryAmounts: mutableAmounts
                    )

                    print("📝 DSAddCategorySheet: Calling updateBudget (async)...")
                    print("   Updated category '\(updatedCategory.name)' with amount: \(editState.amount)")
                    print("   updatedBudget.categoryAmounts for this category: \(updatedBudget.categoryAmounts[subCategory.id.uuidString] ?? -1)")

                    // Use async version directly if available
                    let success: Bool
                    if let manager = budgetManager as? BudgetManager {
                        success = await manager.updateBudget(updatedBudget)
                    } else {
                        success = budgetManager.updateBudget(updatedBudget)
                    }

                    print("   Update result: \(success)")

                    if !success {
                        print("   ❌ Update failed")
                        isSaving = false
                        if let manager = budgetManager as? BudgetManager {
                            errorMessage = manager.lastError ?? "Failed to update category"
                            print("   Error: \(manager.lastError ?? "unknown")")
                        } else {
                            errorMessage = "Failed to update category"
                        }
                        return
                    }

                    print("   ✅ Update succeeded")

                    // Force a refresh to ensure UI has latest data
                    if let manager = budgetManager as? BudgetManager {
                        print("   🔄 Forcing refresh from Supabase to sync UI...")
                        await manager.refreshFromSupabase()
                        print("   ✅ Refresh complete")
                    }

                    print("   ✅ Dismissing sheet")
                    isSaving = false
                    onSuccess()
                    dismiss()
                } else {
                    // Add new category
                    let newCategory = SubCategory(
                        name: editState.name,
                        categoryGroup: editState.group,
                        categoryType: editState.type
                    )

                    let currentBudget = budgetManager.budget
                    var mutableCategories = currentBudget.categories
                    var mutableAmounts = currentBudget.categoryAmounts

                    mutableCategories.append(newCategory)
                    mutableAmounts[newCategory.id.uuidString] = editState.amount

                    let updatedBudget = Budget(
                        id: currentBudget.id,
                        period: currentBudget.period,
                        currency: currentBudget.currency,
                        categories: mutableCategories,
                        categoryAmounts: mutableAmounts
                    )

                    print("➕ DSAddCategorySheet: Calling updateBudget to add category (async)...")

                    // Use async version directly if available
                    let success: Bool
                    if let manager = budgetManager as? BudgetManager {
                        success = await manager.updateBudget(updatedBudget)
                    } else {
                        success = budgetManager.updateBudget(updatedBudget)
                    }

                    print("   Update result: \(success)")

                    if !success {
                        print("   ❌ Update failed")
                        isSaving = false
                        if let manager = budgetManager as? BudgetManager {
                            errorMessage = manager.lastError ?? "Failed to add category"
                            print("   Error: \(manager.lastError ?? "unknown")")
                        } else {
                            errorMessage = "Failed to add category"
                        }
                        return
                    }

                    print("   ✅ Update succeeded")

                    // Force a refresh to ensure UI has latest data
                    if let manager = budgetManager as? BudgetManager {
                        print("   🔄 Forcing refresh from Supabase to sync UI...")
                        await manager.refreshFromSupabase()
                        print("   ✅ Refresh complete")
                    }

                    print("   ✅ Dismissing sheet")
                    isSaving = false
                    onSuccess()
                    dismiss()
                }
            } catch {
                isSaving = false
                errorMessage = "Failed to save: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    DSAddCategorySheet(
        subCategory: nil,
        allocatedAmount: 0,
        currency: Currency(code: "USD", name: "US Dollar", symbol: "$"),
        budgetManager: MockBudgetManager(budget: Budget.createSample()),
        onSuccess: {
            print("Saved successfully")
        },
        onCancel: {
            print("Cancelled")
        }
    )
}
