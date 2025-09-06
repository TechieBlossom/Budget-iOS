import SwiftUI

struct CategorySetupView: View {
    @Bindable var onboardingState: OnboardingState
    @State private var showingAddCategory = false
    @State private var newCategoryName = ""
    @State private var selectedColor: CategoryColor?
    
    @Environment(\.appTheme) private var theme
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                DSText("Setup Categories", font: .dsTitle)
                    .multilineTextAlignment(.center)
                
                DSText("Organize your expenses with categories", font: .dsBody, color: theme.colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 16)
            
            // Categories List
            ScrollView {
                LazyVStack(spacing: 12) {
                    // Default Categories Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            DSText("Default Categories", font: .dsHeadline)
                            Spacer()
                            DSText("\(onboardingState.categoryManager.defaultCategories.count)", font: .dsBody, color: theme.colors.secondaryText)
                        }
                        .padding(.horizontal, 24)
                        
                        ForEach(onboardingState.categoryManager.defaultCategories) { category in
                            CategoryRow(category: category, isEditable: false)
                        }
                    }
                    
                    // Custom Categories Section
                    if !onboardingState.categoryManager.customCategories.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                DSText("Custom Categories", font: .dsHeadline)
                                Spacer()
                                DSText("\(onboardingState.categoryManager.customCategories.count)/6", font: .dsBody, color: theme.colors.secondaryText)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                            
                            ForEach(onboardingState.categoryManager.customCategories) { category in
                                CategoryRow(
                                    category: category,
                                    isEditable: true,
                                    onDelete: {
                                        onboardingState.categoryManager.removeCategory(category)
                                    }
                                )
                            }
                        }
                    }
                    
                    // Add Category Button
                    if onboardingState.categoryManager.canAddMoreCategories {
                        DSCard {
                            DSButton("Add Custom Category", style: .primary) {
                                showingAddCategory = true
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                    }
                }
            }
            
            Spacer()
            
            // Navigation Buttons
            HStack(spacing: 16) {
                DSButton("Back", style: .outline) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        onboardingState.goToPreviousStep()
                    }
                }
                
                DSButton("Complete Setup", style: .primary) {
                    onboardingState.completeOnboarding()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
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
                    Text("Default")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(theme.colors.secondaryText.opacity(0.1))
                        .foregroundColor(theme.colors.secondaryText)
                        .cornerRadius(8)
                }
                
                // Delete Button for Custom Categories
                if isEditable && onDelete != nil {
                    Button(action: onDelete!) {
                        Image(systemName: "minus.circle")
                            .font(.title3)
                            .foregroundColor(theme.colors.secondaryText)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
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
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                // Color Selection
                VStack(alignment: .leading, spacing: 12) {
                    DSText("Category Color", font: .dsHeadline)
                        .padding(.horizontal, 24)
                    
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
                    .padding(.horizontal, 24)
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

#Preview {
    let state = OnboardingState()
    state.currentStep = .categorySetup
    return CategorySetupView(onboardingState: state)
}