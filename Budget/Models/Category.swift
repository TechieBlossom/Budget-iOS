import Foundation

struct SubCategory: Identifiable, Hashable, Codable {
    let id: UUID
    let name: String
    let categoryGroup: CategoryGroup
    let categoryType: CategoryType

    init(name: String, categoryGroup: CategoryGroup, categoryType: CategoryType? = nil) {
        self.id = UUID()
        self.name = name
        self.categoryGroup = categoryGroup
        // Default based on category group: financialGoals -> savings, others -> expense
        self.categoryType = categoryType ?? (categoryGroup == .financialGoals ? .savings : .expense)
    }

    init(id: UUID, name: String, categoryGroup: CategoryGroup, categoryType: CategoryType? = nil) {
        self.id = id
        self.name = name
        self.categoryGroup = categoryGroup
        // Default based on category group: financialGoals -> savings, others -> expense
        self.categoryType = categoryType ?? (categoryGroup == .financialGoals ? .savings : .expense)
    }

    static func createDefault() -> [SubCategory] {
        var subCategories: [SubCategory] = []

        for group in CategoryGroup.allCases {
            let defaultNames = CategoryGroup.defaultSubCategories(for: group)
            for name in defaultNames {
                // Financial Goals categories default to savings, others to expense
                let type: CategoryType = group == .financialGoals ? .savings : .expense
                subCategories.append(SubCategory(
                    name: name,
                    categoryGroup: group,
                    categoryType: type
                ))
            }
        }

        return subCategories
    }
}

@Observable
class CategoryManager {
    var subCategories: [SubCategory] = SubCategory.createDefault()

    func subCategories(for group: CategoryGroup) -> [SubCategory] {
        subCategories.filter { $0.categoryGroup == group }
    }

    func allGroupsWithSubCategories() -> [(CategoryGroup, [SubCategory])] {
        CategoryGroup.allCases.map { group in
            (group, subCategories(for: group))
        }.filter { !$0.1.isEmpty }
    }

    func addSubCategory(name: String, group: CategoryGroup, categoryType: CategoryType? = nil) {
        guard !subCategories.contains(where: { $0.name.lowercased() == name.lowercased() }) else { return }

        let newSubCategory = SubCategory(name: name, categoryGroup: group, categoryType: categoryType)
        subCategories.append(newSubCategory)
    }

    func removeSubCategory(_ subCategory: SubCategory) {
        subCategories.removeAll { $0.id == subCategory.id }
    }

    func updateSubCategory(_ subCategory: SubCategory, name: String, group: CategoryGroup? = nil, categoryType: CategoryType? = nil) {
        if let index = subCategories.firstIndex(where: { $0.id == subCategory.id }) {
            subCategories[index] = SubCategory(
                id: subCategory.id,
                name: name,
                categoryGroup: group ?? subCategory.categoryGroup,
                categoryType: categoryType ?? subCategory.categoryType
            )
        }
    }
}
