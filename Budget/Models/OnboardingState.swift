import Foundation

@Observable
class OnboardingState {
    enum Step: Int, CaseIterable {
        case welcome = 0
        case currency = 1
        case dateSelection = 2
        case categorySetup = 3
        
        var title: String {
            switch self {
            case .welcome:
                return "Welcome"
            case .currency:
                return "Select Currency"
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
    
    // Date selection step
    var selectedStartDate = Date()
    var budgetPeriod: BudgetPeriod {
        BudgetPeriod(startDate: selectedStartDate)
    }
    
    // Category step
    var categoryManager = CategoryManager()
    var categoryAmounts: [String: Double] = [:]
    
    // Navigation methods
    func goToNextStep() {
        let nextRawValue = currentStep.rawValue + 1
        if let nextStep = Step(rawValue: nextRawValue) {
            currentStep = nextStep
        }
    }
    
    func goToPreviousStep() {
        let previousRawValue = currentStep.rawValue - 1
        if let previousStep = Step(rawValue: previousRawValue) {
            currentStep = previousStep
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
        case .dateSelection:
            return true // Date is always valid
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
    
    func completeOnboarding() {
        // This would typically save the onboarding data
        // For now, we'll just mark it as complete
        print("Onboarding completed with:")
        print("Choice: \(userChoice?.description ?? "none")")
        print("Currency: \(selectedCurrency?.displayName ?? "none")")
        print("Budget Period: \(budgetPeriod.name)")
        print("Categories: \(categoryManager.categories.count)")
        print("Total Budget: \(formattedTotalBudget)")
    }
    
    func createCompletedBudget() -> Budget {
        guard let currency = selectedCurrency else {
            // Fallback to USD if no currency selected
            let fallbackCurrency = Currency(code: "USD", name: "US Dollar", symbol: "$")
            return Budget(
                period: budgetPeriod,
                currency: fallbackCurrency,
                categories: categoryManager.categories,
                categoryAmounts: categoryAmounts
            )
        }
        
        return Budget(
            period: budgetPeriod,
            currency: currency,
            categories: categoryManager.categories,
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