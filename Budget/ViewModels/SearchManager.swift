import Foundation
import SwiftUI

// MARK: - Search Criteria Models

struct SearchCriteria {
    var query: String = ""
    var selectedCategories: Set<UUID> = []  // Sub-category IDs
    var selectedCategoryGroups: Set<CategoryGroup> = []  // Category groups
    var dateRange: DateRange?
    var amountRange: ClosedRange<Double>?

    var hasActiveFilters: Bool {
        return !query.isEmpty ||
               !selectedCategories.isEmpty ||
               !selectedCategoryGroups.isEmpty ||
               dateRange != nil ||
               amountRange != nil
    }
}

struct DateRange {
    let startDate: Date
    let endDate: Date
    let displayName: String

    static let today = DateRange(
        startDate: Calendar.current.startOfDay(for: Date()),
        endDate: Calendar.current.endOfDay(for: Date()) ?? Date(),
        displayName: "Today"
    )

    static let thisWeek = DateRange(
        startDate: Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date(),
        endDate: Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.end ?? Date(),
        displayName: "This Week"
    )

    static let thisMonth = DateRange(
        startDate: Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date(),
        endDate: Calendar.current.dateInterval(of: .month, for: Date())?.end ?? Date(),
        displayName: "This Month"
    )

    static let last30Days = DateRange(
        startDate: Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date(),
        endDate: Date(),
        displayName: "Last 30 Days"
    )
}

// MARK: - Search Manager

class SearchManager: ObservableObject {
    @Published var searchCriteria = SearchCriteria()

    // MARK: - Filtering Methods

    func filterTransactions(_ transactions: [Transaction], categories: [SubCategory]) -> [Transaction] {
        var filteredTransactions = transactions

        // Filter by search query (transaction notes and sub-category names)
        if !searchCriteria.query.isEmpty {
            let query = searchCriteria.query.lowercased()
            filteredTransactions = filteredTransactions.filter { transaction in
                // Search in transaction notes
                let notesMatch = transaction.notes.lowercased().contains(query)

                // Search in sub-category name
                let subCategory = categories.first { $0.id == transaction.categoryId }
                let subCategoryMatch = subCategory?.name.lowercased().contains(query) ?? false

                // Search in category group name
                let groupMatch = subCategory?.categoryGroup.displayName.lowercased().contains(query) ?? false

                return notesMatch || subCategoryMatch || groupMatch
            }
        }

        // Filter by selected category groups
        if !searchCriteria.selectedCategoryGroups.isEmpty {
            filteredTransactions = filteredTransactions.filter { transaction in
                let subCategory = categories.first { $0.id == transaction.categoryId }
                guard let subCategory = subCategory else { return false }
                return searchCriteria.selectedCategoryGroups.contains(subCategory.categoryGroup)
            }
        }

        // Filter by selected sub-categories
        if !searchCriteria.selectedCategories.isEmpty {
            filteredTransactions = filteredTransactions.filter { transaction in
                searchCriteria.selectedCategories.contains(transaction.categoryId)
            }
        }

        // Filter by date range
        if let dateRange = searchCriteria.dateRange {
            filteredTransactions = filteredTransactions.filter { transaction in
                transaction.date >= dateRange.startDate && transaction.date <= dateRange.endDate
            }
        }

        // Filter by amount range
        if let amountRange = searchCriteria.amountRange {
            filteredTransactions = filteredTransactions.filter { transaction in
                amountRange.contains(transaction.amount)
            }
        }

        return filteredTransactions
    }

    // MARK: - Search Query Management

    func updateSearchQuery(_ query: String) {
        searchCriteria.query = query
    }

    func clearSearch() {
        searchCriteria = SearchCriteria()
    }

    // MARK: - Category Filtering

    func toggleCategoryFilter(_ categoryId: UUID) {
        if searchCriteria.selectedCategories.contains(categoryId) {
            searchCriteria.selectedCategories.remove(categoryId)
        } else {
            searchCriteria.selectedCategories.insert(categoryId)
        }
    }

    func setCategoryFilter(_ categoryIds: Set<UUID>) {
        searchCriteria.selectedCategories = categoryIds
    }

    // MARK: - Category Group Filtering

    func toggleCategoryGroupFilter(_ group: CategoryGroup) {
        if searchCriteria.selectedCategoryGroups.contains(group) {
            searchCriteria.selectedCategoryGroups.remove(group)
        } else {
            searchCriteria.selectedCategoryGroups.insert(group)
        }
    }

    func setCategoryGroupFilter(_ groups: Set<CategoryGroup>) {
        searchCriteria.selectedCategoryGroups = groups
    }

    // MARK: - Date Range Filtering

    func setDateRange(_ dateRange: DateRange?) {
        searchCriteria.dateRange = dateRange
    }

    func setCustomDateRange(start: Date, end: Date) {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        let displayName = "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        searchCriteria.dateRange = DateRange(
            startDate: start,
            endDate: end,
            displayName: displayName
        )
    }

    // MARK: - Amount Range Filtering

    func setAmountRange(_ range: ClosedRange<Double>?) {
        searchCriteria.amountRange = range
    }

    // MARK: - Quick Filters

    func applyQuickFilter(_ filter: QuickFilter) {
        switch filter {
        case .today:
            setDateRange(.today)
        case .thisWeek:
            setDateRange(.thisWeek)
        case .thisMonth:
            setDateRange(.thisMonth)
        case .last30Days:
            setDateRange(.last30Days)
        }
    }

    // MARK: - Filter Pills Data

    func getActiveFilterPills(categories: [SubCategory]) -> [FilterPillData] {
        var pills: [FilterPillData] = []

        // Date range filter
        if let dateRange = searchCriteria.dateRange {
            pills.append(FilterPillData(
                id: "dateRange",
                title: dateRange.displayName,
                icon: "calendar"
            ))
        }

        // Category group filters
        for group in searchCriteria.selectedCategoryGroups {
            pills.append(FilterPillData(
                id: "group_\(group.rawValue)",
                title: group.displayName,
                color: group.color
            ))
        }

        // Sub-category filters
        for categoryId in searchCriteria.selectedCategories {
            if let category = categories.first(where: { $0.id == categoryId }) {
                pills.append(FilterPillData(
                    id: "category_\(categoryId.uuidString)",
                    title: category.name,
                    color: category.categoryGroup.color
                ))
            }
        }

        // Amount range filter
        if let amountRange = searchCriteria.amountRange {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0

            let minStr = formatter.string(from: NSNumber(value: amountRange.lowerBound)) ?? "\(Int(amountRange.lowerBound))"
            let maxStr = formatter.string(from: NSNumber(value: amountRange.upperBound)) ?? "\(Int(amountRange.upperBound))"

            pills.append(FilterPillData(
                id: "amountRange",
                title: "$\(minStr)-\(maxStr)",
                icon: "dollarsign.circle"
            ))
        }

        return pills
    }

    func removeFilterPill(_ pillId: String, categories: [SubCategory]) {
        if pillId == "dateRange" {
            searchCriteria.dateRange = nil
        } else if pillId == "amountRange" {
            searchCriteria.amountRange = nil
        } else if pillId.hasPrefix("group_") {
            let groupRawValue = pillId.replacingOccurrences(of: "group_", with: "")
            if let group = CategoryGroup.allCases.first(where: { $0.rawValue == groupRawValue }) {
                searchCriteria.selectedCategoryGroups.remove(group)
            }
        } else if pillId.hasPrefix("category_") {
            let uuidString = pillId.replacingOccurrences(of: "category_", with: "")
            if let uuid = UUID(uuidString: uuidString) {
                searchCriteria.selectedCategories.remove(uuid)
            }
        }
    }

    // MARK: - Filter Summary

    func calculateFilteredTotal(_ transactions: [Transaction]) -> Double {
        return transactions.reduce(0) { $0 + $1.amount }
    }
}

// MARK: - Quick Filter Enum

enum QuickFilter: String, CaseIterable {
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case last30Days = "Last 30 Days"

    var displayName: String {
        return self.rawValue
    }
}

// MARK: - Calendar Extension

extension Calendar {
    func endOfDay(for date: Date) -> Date? {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return self.date(byAdding: components, to: startOfDay(for: date))
    }
}
