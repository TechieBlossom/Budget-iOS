import SwiftUI

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

struct CategorySetupView: View {
    @Bindable var onboardingState: OnboardingState
    @State private var showingAddCategory = false
    @State private var newCategoryName = ""
    @State private var budgetAmount = ""
    @State private var selectedColor: CategoryColor?
    
    @Environment(\.appTheme) private var theme
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    DSText("Assign Budget", font: .dsTitle)
                    DSText("Assign budget amounts to your spending categories", font: .dsBody, color: theme.colors.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Image(systemName: "chart.pie")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(theme.colors.primaryText)
            }
            .padding(.horizontal, 16)
            .padding(.top, 80) // Space for back button
            .padding(.bottom, 32)
                
            // Total Budget Display with Add Category Button
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    DSText("Total Budget Amount", font: .dsHeadline)
                    HStack(alignment: .bottom, spacing: 4) {
                        DSText(onboardingState.formattedTotalAmount, font: .dsHeadline, color: theme.colors.primaryText)
                        DSText(onboardingState.selectedCurrencyCode, font: .dsSubtitle, color: theme.colors.primaryText)
                    }
                }
                
                Spacer()
                
                if onboardingState.categoryManager.canAddMoreCategories {
                    DSButton("ADD CATEGORY", style: .outline) {
                        showingAddCategory = true
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            
            // Categories List - Full Screen
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Custom Categories Section (shown first)
                    ForEach(onboardingState.categoryManager.customCategories) { category in
                        CategoryRowWithAmount(
                            category: category,
                            isEditable: true,
                            onboardingState: onboardingState,
                            onDelete: {
                                onboardingState.categoryManager.removeCategory(category)
                            }
                        )
                    }
                    
                    // Default Categories Section
                    ForEach(onboardingState.categoryManager.defaultCategories) { category in
                        CategoryRowWithAmount(
                            category: category, 
                            isEditable: false,
                            onboardingState: onboardingState,
                            onDelete: {
                                onboardingState.categoryManager.removeCategory(category)
                            }
                        )
                    }
                    
                    // Bottom spacing for navigation buttons
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 120)
                }
                .padding(.horizontal, 16)
            }
        }
        .background(theme.colors.background)
        .sheet(isPresented: $showingAddCategory) {
            AddCategorySheet(
                categoryName: $newCategoryName,
                selectedColor: $selectedColor,
                availableColors: onboardingState.categoryManager.availableColors,
                onSave: {
                    if let color = selectedColor, !newCategoryName.isEmpty {
                        onboardingState.categoryManager.addCategory(name: newCategoryName, color: color)
                        newCategoryName = ""
                        selectedColor = nil
                        showingAddCategory = false
                    }
                },
                onCancel: {
                    newCategoryName = ""
                    selectedColor = nil
                    showingAddCategory = false
                }
            )
        }
    }
}

struct CategoryRow: View {
    let category: Category
    let isEditable: Bool
    let onDelete: (() -> Void)?
    
    @Environment(\.appTheme) private var theme
    
    init(category: Category, isEditable: Bool, onDelete: (() -> Void)? = nil) {
        self.category = category
        self.isEditable = isEditable
        self.onDelete = onDelete
    }
    
    var body: some View {
        DSCard {
            HStack(spacing: 16) {
                // Category Color
                Circle()
                    .fill(category.color.color)
                    .frame(width: 20, height: 20)
                
                // Category Name
                DSText(category.name, font: .dsBody)
                
                Spacer()
                
                // Category Type Badge
                if category.isDefault {
                    DSText("Default", font: .dsCaption, color: theme.colors.secondaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(theme.colors.secondaryText.opacity(0.1))
                        .cornerRadius(8)
                }
                
                // Delete Button for Custom Categories
                if isEditable && onDelete != nil {
                    Button(action: onDelete!) {
                        Image(systemName: "minus.circle")
                            .font(.title3)
                            .foregroundColor(theme.colors.secondaryText)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

struct AddCategorySheet: View {
    @Binding var categoryName: String
    @Binding var selectedColor: CategoryColor?
    let availableColors: [CategoryColor]
    let onSave: () -> Void
    let onCancel: () -> Void
    
    @Environment(\.appTheme) private var theme
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Category Name Input
                VStack(alignment: .leading, spacing: 12) {
                    DSText("Category Name", font: .dsHeadline)
                    DSTextField("Enter category name", text: $categoryName)
                        .onChange(of: categoryName) { _, newValue in
                            if newValue.count > 15 {
                                categoryName = String(newValue.prefix(15))
                            }
                        }
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
                
                // Color Selection
                VStack(alignment: .leading, spacing: 12) {
                    DSText("Category Color", font: .dsHeadline)
                        .padding(.horizontal, 16)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 16) {
                        ForEach(availableColors, id: \.id) { color in
                            Button(action: {
                                selectedColor = color
                            }) {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                selectedColor == color ? theme.colors.primaryText : Color.clear,
                                                lineWidth: 3
                                            )
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                
                Spacer()
            }
            .background(theme.colors.background)
            .navigationTitle("Add Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                        .foregroundColor(theme.colors.primaryText)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save", action: onSave)
                        .foregroundColor(theme.colors.primaryText)
                        .disabled(categoryName.isEmpty || selectedColor == nil)
                }
            }
        }
    }
}

struct CategoryRowWithAmount: View {
    let category: Category
    let isEditable: Bool
    let onboardingState: OnboardingState
    let onDelete: (() -> Void)?
    @State private var amount: String = ""
    
    @Environment(\.appTheme) private var theme
    
    init(category: Category, isEditable: Bool, onboardingState: OnboardingState, onDelete: (() -> Void)? = nil) {
        self.category = category
        self.isEditable = isEditable
        self.onboardingState = onboardingState
        self.onDelete = onDelete
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Color Border
            Rectangle()
                .fill(category.color.color)
                .frame(width: 8)
                .cornerRadius(8, corners: [.topLeft, .bottomLeft])
            
            HStack(spacing: 16) {
                // Category Name
                VStack(alignment: .leading, spacing: 2) {
                    DSText(category.name, font: .dsHeadline)
                    if isEditable {
                        DSText("Custom", font: .dsCaption, color: theme.colors.secondaryText)
                    } else {
                        DSText("Default", font: .dsCaption, color: theme.colors.secondaryText)
                    }
                }
                
                Spacer()
                
                // Amount Input Field
                TextField("0.00", text: $amount)
                    .font(.system(size: 16))
                    .foregroundColor(theme.colors.primaryText)
                    .keyboardType(.decimalPad)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .frame(width: 100)
                    .background(theme.colors.card)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(theme.colors.secondaryText, lineWidth: 1)
                    )
                    .accentColor(theme.colors.primaryText)
                    .onChange(of: amount) { _, newValue in
                        let numericValue = Double(newValue) ?? 0.0
                        onboardingState.updateCategoryAmount(categoryId: category.id.uuidString, amount: numericValue)
                    }
                
                // Delete Button for all categories
                Button(action: { onDelete?() }) {
                    Image(systemName: "trash")
                        .font(.body)
                        .foregroundColor(theme.colors.secondaryText)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(theme.colors.card)
        .cornerRadius(8)
    }
}

struct CategoryRowFullScreen: View {
    let category: Category
    let isEditable: Bool
    let onDelete: (() -> Void)?
    
    @Environment(\.appTheme) private var theme
    
    init(category: Category, isEditable: Bool, onDelete: (() -> Void)? = nil) {
        self.category = category
        self.isEditable = isEditable
        self.onDelete = onDelete
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Color Indicator
            Circle()
                .fill(category.color.color)
                .frame(width: 24, height: 24)
            
            // Category Name
            VStack(alignment: .leading, spacing: 2) {
                DSText(category.name, font: .dsHeadline)
                if isEditable {
                    DSText("Custom", font: .dsCaption, color: theme.colors.secondaryText)
                } else {
                    DSText("Default", font: .dsCaption, color: theme.colors.secondaryText)
                }
            }
            
            Spacer()
            
            // Delete Button for editable categories
            if isEditable {
                Button(action: { onDelete?() }) {
                    Image(systemName: "trash")
                        .font(.body)
                        .foregroundColor(theme.colors.secondaryText)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(theme.colors.card)
    }
}

#Preview {
    let state = OnboardingState()
    state.currentStep = .categorySetup
    return CategorySetupView(onboardingState: state)
}
