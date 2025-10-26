import Foundation

@Observable
class OnboardingState {
    enum Step: Int, CaseIterable {
        case welcome = 0
        case currency = 1
        case budgetTypeSelection = 2
        case dateSelection = 3
        case categorySetup = 4
        
        var title: String {
            switch self {
            case .welcome:
                return "Welcome"
            case .currency:
                return "Select Currency"
            case .budgetTypeSelection:
                return "Budget Type"
            case .dateSelection:
                return "Budget Period"
            case .categorySetup:
                return "Categories"
            }
        }
        
        var progress: Double {
            Double(rawValue + 1) / Double(Step.allCases.count)
        }
    }
    
    enum UserChoice {
        case start
        case exportExisting
    }
    
    // Current step
    var currentStep: Step = .welcome
    
    // Welcome step
    var userChoice: UserChoice?
    
    // Currency step
    var selectedCurrency: Currency?
    var currencySearchText = ""
    
    // Budget type step
    var selectedBudgetType: BudgetType = .monthly
    
    // Date selection step
    var selectedStartDate = Date()
    var selectedEndDate: Date?
    var budgetName = ""
    
    var budgetPeriod: BudgetPeriod {
        switch selectedBudgetType {
        case .custom:
            guard let endDate = selectedEndDate else {
                // Fallback to monthly if no end date
                return BudgetPeriod(type: .monthly, startDate: selectedStartDate, customName: budgetName.isEmpty ? nil : budgetName)
            }
            
            if budgetName.isEmpty {
                // Create a temporary budget period to get the auto-shifted dates, then generate name from final dates
                let tempPeriod = BudgetPeriod(type: .custom, startDate: selectedStartDate, endDate: endDate, customName: "temp")
                let finalName = BudgetPeriod.generateCustomName(for: tempPeriod.startDate, endDate: tempPeriod.endDate)
                return BudgetPeriod(type: .custom, startDate: selectedStartDate, endDate: endDate, customName: finalName)
            } else {
                return BudgetPeriod(type: .custom, startDate: selectedStartDate, endDate: endDate, customName: budgetName)
            }
        case .monthly:
            let name = budgetName.isEmpty ? nil : budgetName
            return BudgetPeriod(type: .monthly, startDate: selectedStartDate, customName: name)
        }
    }
    
    // Category step
    var categoryManager = CategoryManager()
    var categoryAmounts: [String: Double] = [:]
    
    // Navigation methods
    func goToNextStep() {
        let nextRawValue = currentStep.rawValue + 1
        if let nextStep = Step(rawValue: nextRawValue) {
            // Skip budgetTypeSelection step since it's now part of DateSelectionView
            if nextStep == .budgetTypeSelection {
                currentStep = .dateSelection
            } else {
                currentStep = nextStep
            }
        }
    }
    
    func goToPreviousStep() {
        let previousRawValue = currentStep.rawValue - 1
        if let previousStep = Step(rawValue: previousRawValue) {
            // Skip budgetTypeSelection step since it's now part of DateSelectionView
            if previousStep == .budgetTypeSelection {
                currentStep = .currency
            } else {
                currentStep = previousStep
            }
        }
    }
    
    func goToStep(_ step: Step) {
        currentStep = step
    }
    
    var canProceed: Bool {
        switch currentStep {
        case .welcome:
            return userChoice != nil
        case .currency:
            return selectedCurrency != nil
        case .budgetTypeSelection:
            return true // Budget type is always valid (defaults to monthly)
        case .dateSelection:
            if selectedBudgetType == .custom {
                return selectedEndDate != nil && selectedEndDate! > selectedStartDate
            }
            return true // Date is always valid for monthly
        case .categorySetup:
            return true // Can proceed with default categories
        }
    }
    
    var isFirstStep: Bool {
        currentStep == .welcome
    }
    
    var isLastStep: Bool {
        currentStep == .categorySetup
    }
    
    var totalBudgetAmount: Double {
        categoryAmounts.values.reduce(0, +)
    }
    
    var formattedTotalBudget: String {
        let code = selectedCurrency?.code ?? "USD"
        return String(format: "%.2f %@", totalBudgetAmount, code)
    }
    
    var formattedTotalAmount: String {
        return String(format: "%.2f", totalBudgetAmount)
    }
    
    var selectedCurrencyCode: String {
        return selectedCurrency?.code ?? "USD"
    }
    
    func updateCategoryAmount(categoryId: String, amount: Double) {
        categoryAmounts[categoryId] = amount
    }

    // Category Manager wrapper methods to ensure proper observation
    // These methods ensure the view updates when categoryManager changes
    func addSubCategory(name: String, group: CategoryGroup, categoryType: CategoryType? = nil, allocatedAmount: Double = 0) {
        categoryManager.addSubCategory(name: name, group: group, categoryType: categoryType)
        // Set the allocated amount for the new category
        if let newCategory = categoryManager.subCategories.last {
            categoryAmounts[newCategory.id.uuidString] = allocatedAmount
        }
    }

    func removeSubCategory(_ subCategory: SubCategory) {
        categoryManager.removeSubCategory(subCategory)
        // Remove from categoryAmounts if exists
        categoryAmounts.removeValue(forKey: subCategory.id.uuidString)
    }

    func updateSubCategory(_ subCategory: SubCategory, name: String, group: CategoryGroup? = nil, categoryType: CategoryType? = nil) {
        categoryManager.updateSubCategory(subCategory, name: name, group: group, categoryType: categoryType)
    }

    func toggleCategoryType(for subCategory: SubCategory) {
        if let index = categoryManager.subCategories.firstIndex(where: { $0.id == subCategory.id }) {
            let newType: CategoryType = subCategory.categoryType == .expense ? .savings : .expense
            categoryManager.subCategories[index] = SubCategory(
                id: subCategory.id,
                name: subCategory.name,
                categoryGroup: subCategory.categoryGroup,
                categoryType: newType
            )
        }
    }

    func createCompletedBudget() -> Budget {
        guard let currency = selectedCurrency else {
            // Fallback to USD if no currency selected
            let fallbackCurrency = Currency(code: "USD", name: "US Dollar", symbol: "$")
            return Budget(
                period: budgetPeriod,
                currency: fallbackCurrency,
                categories: categoryManager.subCategories,
                categoryAmounts: categoryAmounts
            )
        }

        return Budget(
            period: budgetPeriod,
            currency: currency,
            categories: categoryManager.subCategories,
            categoryAmounts: categoryAmounts
        )
    }
}

extension OnboardingState.UserChoice: CustomStringConvertible {
    var description: String {
        switch self {
        case .start:
            return "Start Fresh"
        case .exportExisting:
            return "Export Existing"
        }
    }
}