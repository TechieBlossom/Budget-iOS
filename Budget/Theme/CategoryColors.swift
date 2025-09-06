import SwiftUI

enum CategoryColor: String, CaseIterable, Identifiable {
    case color1 = "#FF6B6B"  // Housing
    case color2 = "#4ECDC4"  // Healthcare  
    case color3 = "#45B7D1"  // Transportation
    case color4 = "#96CEB4"  // Utility
    case color5 = "#FFEAA7"  // Groceries
    case color6 = "#DDA0DD"  // Food & Dining
    case color7 = "#98D8C8"  // Entertainment
    case color8 = "#F7DC6F"  // Medical
    case color9 = "#BB8FCE"  // Others
    case color10 = "#F8C291"
    case color11 = "#70A1FF"
    case color12 = "#7BED9F"
    case color13 = "#FF7675"
    case color14 = "#A29BFE"
    case color15 = "#FD79A8"
    
    var id: String { rawValue }
    
    var color: Color {
        Color(hex: rawValue)
    }
    
    static let defaultCategoryAssignments: [DefaultCategory: CategoryColor] = [
        .housing: .color1,
        .healthcare: .color2,
        .transportation: .color3,
        .utility: .color4,
        .groceries: .color5,
        .foodDining: .color6,
        .entertainment: .color7,
        .medical: .color8,
        .others: .color9
    ]
    
    static var availableForUserCategories: [CategoryColor] {
        [.color10, .color11, .color12, .color13, .color14, .color15]
    }
    
    static func unusedColors(excluding usedColors: [CategoryColor]) -> [CategoryColor] {
        availableForUserCategories.filter { !usedColors.contains($0) }
    }
}

enum DefaultCategory: String, CaseIterable {
    case housing = "Housing"
    case healthcare = "Healthcare"
    case transportation = "Transportation"
    case utility = "Utility"
    case groceries = "Groceries"
    case foodDining = "Food & Dining"
    case entertainment = "Entertainment"
    case medical = "Medical"
    case others = "Others"
    
    var displayName: String {
        rawValue
    }
    
    var assignedColor: CategoryColor {
        CategoryColor.defaultCategoryAssignments[self] ?? .color9
    }
}