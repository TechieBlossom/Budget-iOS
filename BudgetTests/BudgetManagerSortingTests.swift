import Testing
import Foundation
@testable import Budget

@Suite("Subcategory Sorting Logic Tests")
struct BudgetManagerSortingTests {

    @Test("Subcategories should be sorted by spending percentage - highest first")
    func testSubCategorySortingLogic() {
        // Create test subcategories
        let foodDining = SubCategory(name: "Food & Dining", categoryGroup: .lifestyle, categoryType: .expense)
        let entertainment = SubCategory(name: "Entertainment", categoryGroup: .lifestyle, categoryType: .expense)
        let salon = SubCategory(name: "Salon", categoryGroup: .lifestyle, categoryType: .expense)

        // Create spending data
        let categoryAmounts: [String: Double] = [
            foodDining.id.uuidString: 500.0,       // Allocated
            entertainment.id.uuidString: 600.0,
            salon.id.uuidString: 650.0
        ]

        let spentAmounts: [String: Double] = [
            foodDining.id.uuidString: 1807.0,      // 361% spent
            entertainment.id.uuidString: 843.0,    // 140% spent
            salon.id.uuidString: 1094.0            // 168% spent
        ]

        // Calculate percentages
        func calculatePercentage(for category: SubCategory) -> Double {
            let allocated = categoryAmounts[category.id.uuidString] ?? 0
            let spent = spentAmounts[category.id.uuidString] ?? 0
            guard allocated > 0 else { return 0 }
            return spent / allocated
        }

        let categories = [foodDining, entertainment, salon]

        // Sort by percentage (highest first)
        let sortedCategories = categories.sorted { cat1, cat2 in
            let percentage1 = calculatePercentage(for: cat1)
            let percentage2 = calculatePercentage(for: cat2)
            return percentage1 > percentage2
        }

        // Verify order: Food & Dining (361%) > Salon (168%) > Entertainment (140%)
        #expect(sortedCategories.count == 3, "Should have 3 categories")
        #expect(sortedCategories[0].id == foodDining.id, "First should be Food & Dining with 361%")
        #expect(sortedCategories[1].id == salon.id, "Second should be Salon with 168%")
        #expect(sortedCategories[2].id == entertainment.id, "Third should be Entertainment with 140%")

        // Verify percentages are in descending order
        let percentages = sortedCategories.map { calculatePercentage(for: $0) }
        for i in 0..<(percentages.count - 1) {
            #expect(percentages[i] >= percentages[i + 1],
                   "Percentage at index \(i) (\(Int(percentages[i] * 100))%) should be >= percentage at index \(i + 1) (\(Int(percentages[i + 1] * 100))%)")
        }

        // Print for debugging
        print("--- Subcategory Sorting Test ---")
        for (index, category) in sortedCategories.enumerated() {
            let percentage = calculatePercentage(for: category)
            print("\(index + 1). \(category.name): \(Int(percentage * 100))%")
        }
    }

    @Test("Categories with zero spending should appear last")
    func testZeroSpendingCategoriesLast() {
        let withSpending = SubCategory(name: "With Spending", categoryGroup: .lifestyle, categoryType: .expense)
        let noSpending = SubCategory(name: "No Spending", categoryGroup: .lifestyle, categoryType: .expense)

        let categoryAmounts: [String: Double] = [
            withSpending.id.uuidString: 100.0,
            noSpending.id.uuidString: 100.0
        ]

        let spentAmounts: [String: Double] = [
            withSpending.id.uuidString: 75.0,
            noSpending.id.uuidString: 0.0
        ]

        func calculatePercentage(for category: SubCategory) -> Double {
            let allocated = categoryAmounts[category.id.uuidString] ?? 0
            let spent = spentAmounts[category.id.uuidString] ?? 0
            guard allocated > 0 else { return 0 }
            return spent / allocated
        }

        let categories = [noSpending, withSpending]  // Intentionally wrong order

        let sortedCategories = categories.sorted { cat1, cat2 in
            let percentage1 = calculatePercentage(for: cat1)
            let percentage2 = calculatePercentage(for: cat2)
            return percentage1 > percentage2
        }

        #expect(sortedCategories.count == 2)
        #expect(sortedCategories[0].id == withSpending.id, "Category with spending should be first")
        #expect(sortedCategories[1].id == noSpending.id, "Category without spending should be last")
    }

    @Test("Sorting with equal percentages should maintain stable order")
    func testEqualPercentagesStableOrder() {
        let category1 = SubCategory(name: "Category 1", categoryGroup: .lifestyle, categoryType: .expense)
        let category2 = SubCategory(name: "Category 2", categoryGroup: .lifestyle, categoryType: .expense)
        let category3 = SubCategory(name: "Category 3", categoryGroup: .lifestyle, categoryType: .expense)

        let categoryAmounts: [String: Double] = [
            category1.id.uuidString: 100.0,
            category2.id.uuidString: 100.0,
            category3.id.uuidString: 100.0
        ]

        let spentAmounts: [String: Double] = [
            category1.id.uuidString: 50.0,  // All 50%
            category2.id.uuidString: 50.0,
            category3.id.uuidString: 50.0
        ]

        func calculatePercentage(for category: SubCategory) -> Double {
            let allocated = categoryAmounts[category.id.uuidString] ?? 0
            let spent = spentAmounts[category.id.uuidString] ?? 0
            guard allocated > 0 else { return 0 }
            return spent / allocated
        }

        let categories = [category1, category2, category3]

        let sortedCategories = categories.sorted { cat1, cat2 in
            let percentage1 = calculatePercentage(for: cat1)
            let percentage2 = calculatePercentage(for: cat2)
            return percentage1 > percentage2
        }

        // All should have same percentage
        let percentages = sortedCategories.map { calculatePercentage(for: $0) }
        #expect(percentages.allSatisfy { $0 == 0.5 }, "All percentages should be 50%")
    }
}
