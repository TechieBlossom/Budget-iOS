import Foundation

/// Encapsulates all editable category data with change detection
struct CategoryEditState {
    // Current values
    var name: String
    var group: CategoryGroup
    var type: CategoryType
    var amount: Double

    // Original values for change detection
    private let originalName: String
    private let originalGroup: CategoryGroup
    private let originalType: CategoryType
    private let originalAmount: Double

    /// Initialize for editing existing category
    init(
        subCategory: SubCategory,
        allocatedAmount: Double
    ) {
        self.name = subCategory.name
        self.group = subCategory.categoryGroup
        self.type = subCategory.categoryType
        self.amount = allocatedAmount

        self.originalName = subCategory.name
        self.originalGroup = subCategory.categoryGroup
        self.originalType = subCategory.categoryType
        self.originalAmount = allocatedAmount
    }

    /// Initialize for adding new category
    init(
        name: String = "",
        group: CategoryGroup? = nil,
        type: CategoryType = .expense,
        amount: Double = 0
    ) {
        self.name = name
        self.group = group ?? .essentials
        self.type = type
        self.amount = amount

        // For new categories, original values are empty/default
        self.originalName = ""
        self.originalGroup = .essentials
        self.originalType = .expense
        self.originalAmount = 0
    }

    /// Detects if any field has changed
    var hasChanges: Bool {
        return name != originalName ||
               group != originalGroup ||
               type != originalType ||
               amount != originalAmount
    }

    /// Validates that required fields are filled
    var isValid: Bool {
        return !name.isEmpty
    }
}
