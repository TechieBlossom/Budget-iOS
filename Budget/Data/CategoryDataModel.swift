//
//  CategoryDataModel.swift
//  Budget
//
//  Created for Supabase integration
//

import Foundation
import SwiftData

@Model
final class CategoryDataModel {
    @Attribute(.unique) var categoryId: UUID
    var budgetId: UUID
    var name: String
    var categoryGroup: String
    var categoryType: String
    var allocatedAmount: Double
    var createdAt: Date
    var updatedAt: Date

    var budget: BudgetDataModel?

    init(categoryId: UUID, budgetId: UUID, name: String, categoryGroup: String, categoryType: String, allocatedAmount: Double = 0) {
        self.categoryId = categoryId
        self.budgetId = budgetId
        self.name = name
        self.categoryGroup = categoryGroup
        self.categoryType = categoryType
        self.allocatedAmount = allocatedAmount
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Conversions

extension CategoryDataModel {
    /// Convert to domain model SubCategory
    func toSubCategory() -> SubCategory {
        // Try to parse categoryGroup, handling both database format (e.g., "essentials")
        // and display format (e.g., "Essentials")
        let group: CategoryGroup
        if let parsedGroup = CategoryGroup(rawValue: categoryGroup) {
            // Display format (e.g., "Essentials")
            group = parsedGroup
        } else {
            // Database format - convert to display format first
            let displayFormat = convertToDisplayFormat(categoryGroup)
            group = CategoryGroup(rawValue: displayFormat) ?? .miscellaneous
        }

        let type = CategoryType(rawValue: categoryType) ?? .expense
        return SubCategory(
            id: categoryId,
            name: name,
            categoryGroup: group,
            categoryType: type
        )
    }

    /// Convert database format to display format
    private func convertToDisplayFormat(_ dbFormat: String) -> String {
        switch dbFormat {
        case "essentials": return "Essentials"
        case "lifestyle": return "Lifestyle"
        case "occasional": return "Occasional"
        case "financialGoals": return "Financial Goals"
        case "debtObligations": return "Debt & Obligations"
        case "businessExpenses": return "Business Expenses"
        case "familyDependents": return "Family & Dependents"
        case "homeProperty": return "Home & Property"
        case "miscellaneous": return "Miscellaneous"
        default: return dbFormat.capitalized
        }
    }

    /// Create CategoryDataModel from SubCategory
    static func from(_ subCategory: SubCategory, budgetId: UUID, allocatedAmount: Double = 0) -> CategoryDataModel {
        return CategoryDataModel(
            categoryId: subCategory.id,
            budgetId: budgetId,
            name: subCategory.name,
            categoryGroup: subCategory.categoryGroup.rawValue,
            categoryType: subCategory.categoryType.rawValue,
            allocatedAmount: allocatedAmount
        )
    }
}
