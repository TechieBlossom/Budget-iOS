import Foundation

struct Category: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let color: CategoryColor
    let isDefault: Bool
    
    init(name: String, color: CategoryColor, isDefault: Bool = false) {
        self.name = name
        self.color = color
        self.isDefault = isDefault
    }
    
    static func createDefault() -> [Category] {
        DefaultCategory.allCases.map { defaultCategory in
            Category(
                name: defaultCategory.displayName,
                color: defaultCategory.assignedColor,
                isDefault: true
            )
        }
    }
    
    static func createCustom(name: String, color: CategoryColor) -> Category {
        Category(name: name, color: color, isDefault: false)
    }
}

@Observable
class CategoryManager {
    var categories: [Category] = Category.createDefault()
    
    var customCategories: [Category] {
        categories.filter { !$0.isDefault }
    }
    
    var defaultCategories: [Category] {
        categories.filter { $0.isDefault }
    }
    
    var usedColors: [CategoryColor] {
        categories.map { $0.color }
    }
    
    var availableColors: [CategoryColor] {
        CategoryColor.unusedColors(excluding: usedColors)
    }
    
    var canAddMoreCategories: Bool {
        customCategories.count < 6
    }
    
    func addCategory(name: String, color: CategoryColor) {
        guard canAddMoreCategories else { return }
        guard !availableColors.contains(color) else { return }
        
        let newCategory = Category.createCustom(name: name, color: color)
        categories.append(newCategory)
    }
    
    func removeCategory(_ category: Category) {
        guard !category.isDefault else { return }
        categories.removeAll { $0.id == category.id }
    }
    
    func updateCategory(_ category: Category, name: String) {
        guard !category.isDefault else { return }
        
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            categories[index] = Category(
                name: name,
                color: category.color,
                isDefault: false
            )
        }
    }
}