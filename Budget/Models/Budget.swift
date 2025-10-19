import Foundation

struct Budget: Identifiable {
    let id: UUID
    let period: BudgetPeriod
    let currency: Currency
    let categories: [SubCategory]
    let categoryAmounts: [String: Double]

    init(period: BudgetPeriod, currency: Currency, categories: [SubCategory], categoryAmounts: [String: Double]) {
        self.id = UUID()
        self.period = period
        self.currency = currency
        self.categories = categories
        self.categoryAmounts = categoryAmounts
    }

    init(id: UUID, period: BudgetPeriod, currency: Currency, categories: [SubCategory], categoryAmounts: [String: Double]) {
        self.id = id
        self.period = period
        self.currency = currency
        self.categories = categories
        self.categoryAmounts = categoryAmounts
    }

    var totalAmount: Double {
        categoryAmounts.values.reduce(0, +)
    }

    var totalAmountExpenses: Double {
        let expenseCategories = categories.filter { $0.categoryType == .expense }
        return expenseCategories.reduce(0.0) { total, category in
            total + (categoryAmounts[category.id.uuidString] ?? 0.0)
        }
    }

    var totalAmountSavings: Double {
        let savingsCategories = categories.filter { $0.categoryType == .savings }
        return savingsCategories.reduce(0.0) { total, category in
            total + (categoryAmounts[category.id.uuidString] ?? 0.0)
        }
    }

    var formattedTotalAmount: String {
        return String(format: "%.2f", totalAmount)
    }

    func totalAmount(excludingSavings: Bool) -> Double {
        if excludingSavings {
            return totalAmountExpenses
        }
        return totalAmount
    }

    var budgetName: String {
        return period.name
    }

    var categoriesWithBudget: [SubCategory] {
        return categories.filter { category in
            let amount = categoryAmounts[category.id.uuidString] ?? 0
            return amount > 0
        }
    }

    // MARK: - Category Group Methods

    var categoryGroups: [CategoryGroup] {
        let groups = Set(categories.map { $0.categoryGroup })
        return CategoryGroup.allCases.filter { groups.contains($0) }
    }

    func totalAmount(for group: CategoryGroup, excludingSavings: Bool = false) -> Double {
        var subCategoriesInGroup = categories.filter { $0.categoryGroup == group }
        if excludingSavings {
            subCategoriesInGroup = subCategoriesInGroup.filter { $0.categoryType == .expense }
        }
        return subCategoriesInGroup.reduce(0.0) { total, subCategory in
            total + (categoryAmounts[subCategory.id.uuidString] ?? 0.0)
        }
    }

    func subCategoriesWithBudget(for group: CategoryGroup, excludingSavings: Bool = false) -> [SubCategory] {
        return categories.filter { subCategory in
            subCategory.categoryGroup == group &&
            (categoryAmounts[subCategory.id.uuidString] ?? 0) > 0 &&
            (!excludingSavings || subCategory.categoryType == .expense)
        }
    }

    static func createSample() -> Budget {
        let startDate = Calendar.current.date(byAdding: .day, value: -15, to: Date()) ?? Date()
        let period = BudgetPeriod(startDate: startDate)
        let currency = Currency(code: "USD", name: "US Dollar", symbol: "$")
        let categories = SubCategory.createDefault()

        var categoryAmounts: [String: Double] = [:]
        for (index, category) in categories.enumerated() {
            categoryAmounts[category.id.uuidString] = Double((index + 1) * 100) // Sample amounts
        }

        return Budget(
            period: period,
            currency: currency,
            categories: categories,
            categoryAmounts: categoryAmounts
        )
    }
}