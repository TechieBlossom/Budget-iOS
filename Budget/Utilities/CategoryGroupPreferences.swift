//
//  CategoryGroupPreferences.swift
//  Budget
//
//  Manages user preferences for selected category groups in Budget tab
//

import Foundation

@MainActor
class CategoryGroupPreferences: ObservableObject {
    private let userDefaultsKey = "selectedCategoryGroups"

    @Published var selectedGroups: Set<CategoryGroup> {
        didSet {
            saveToUserDefaults()
        }
    }

    init() {
        // Load saved preferences or default to all groups
        if let savedRawValues = UserDefaults.standard.array(forKey: userDefaultsKey) as? [String] {
            let groups = savedRawValues.compactMap { CategoryGroup(rawValue: $0) }
            self.selectedGroups = groups.isEmpty ? Set(CategoryGroup.allCases) : Set(groups)
        } else {
            // Default: all groups selected
            self.selectedGroups = Set(CategoryGroup.allCases)
        }
    }

    private func saveToUserDefaults() {
        let rawValues = selectedGroups.map { $0.rawValue }
        UserDefaults.standard.set(rawValues, forKey: userDefaultsKey)
    }

    func toggleGroup(_ group: CategoryGroup) {
        // Ensure at least one group remains selected
        if selectedGroups.contains(group) && selectedGroups.count > 1 {
            selectedGroups.remove(group)
        } else if !selectedGroups.contains(group) {
            selectedGroups.insert(group)
        }
    }

    var isAllGroupsSelected: Bool {
        selectedGroups.count == CategoryGroup.allCases.count
    }

    var unselectedCount: Int {
        CategoryGroup.allCases.count - selectedGroups.count
    }
}
