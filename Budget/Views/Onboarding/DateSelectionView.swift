import SwiftUI

struct DateSelectionView: View {
    @Bindable var onboardingState: OnboardingState
    @State private var selectedDay: Int = 1
    @State private var selectedEndDay: Int = 28
    
    @Environment(\.appTheme) private var theme
    
    var body: some View {
        VStack(spacing: 0) {
            // Fixed Header
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    DSText("Set Budget Dates", font: .dsTitle)
                    DSText("Set start and end dates for your budget period", font: .dsBody, color: theme.colors.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(theme.colors.primaryText)
            }
            .padding(.horizontal, 16)
            .padding(.top, 80)
            .padding(.bottom, 16)
            
            // Scrollable Content
            ScrollView {
                VStack(spacing: 0) {
            
            // Budget Preview (always visible, fixed position)
            budgetPreviewCard
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                    
                    // Budget Name Field (always visible, editable)
                    VStack(alignment: .leading, spacing: 8) {
                        DSText("Budget Name", font: .dsHeadline, color: theme.colors.primaryText)
                        DSTextField("Enter budget name", text: $onboardingState.budgetName)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    
                    // Custom Budget Checklist Tile (always below name field)
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            onboardingState.selectedBudgetType = onboardingState.selectedBudgetType == .custom ? .monthly : .custom
                        }
                        updateBudgetName()
                    }) {
                        DSCard {
                            HStack(spacing: 12) {
                                Image(systemName: onboardingState.selectedBudgetType == .custom ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(onboardingState.selectedBudgetType == .custom ? theme.colors.primaryText : theme.colors.secondaryText)
                                
                                DSText("I want to customise budget end date", font: .dsBody, color: theme.colors.primaryText)
                                
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            
            // Start Date Selection (only visible when not custom)
            if onboardingState.selectedBudgetType != .custom {
                VStack(alignment: .leading, spacing: 8) {
                    DSText("Start Date", font: .dsHeadline, color: theme.colors.primaryText)
                    calendarGrid(selectedDay: $selectedDay, isEndDate: false)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .transition(.opacity)
            }
            
            // End Date Selection (expandable - only for Custom)
            if onboardingState.selectedBudgetType == .custom {
                VStack(alignment: .leading, spacing: 8) {
                    DSText("End Date", font: .dsHeadline, color: theme.colors.primaryText)
                    calendarGrid(selectedDay: $selectedEndDay, isEndDate: true)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .transition(.opacity)
            }
            
            // Bottom padding for scroll content
            Spacer()
                .frame(height: 80)
                }
            }
        }
        .background(theme.colors.background)
        .animation(.easeInOut(duration: 0.3), value: onboardingState.selectedBudgetType)
        .onAppear {
            initializeState()
        }
    }
    
    // MARK: - Helper Views
    
    private func calendarGrid(selectedDay: Binding<Int>, isEndDate: Bool) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
        
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(1...28, id: \.self) { day in
                Button(action: {
                    selectedDay.wrappedValue = day
                    if isEndDate {
                        updateEndDate(day: day)
                    } else {
                        updateStartDate(day: day)
                    }
                }) {
                    Text("\(day)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(selectedDay.wrappedValue == day ? theme.colors.card : theme.colors.primaryText)
                        .frame(width: 40, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedDay.wrappedValue == day ? theme.colors.primaryText : theme.colors.card)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(theme.colors.primaryText, lineWidth: selectedDay.wrappedValue == day ? 2 : 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private var budgetPreviewCard: some View {
        DSCard {
            VStack(spacing: 12) {
                HStack {
                    DSText("Budget Preview", font: .dsHeadline)
                    Spacer()
                }
                
                // Auto-shift notification
                if onboardingState.budgetPeriod.wasAutoShifted {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(theme.colors.primaryText)
                            .font(.system(size: 14))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            DSText("Adjusted to previous month for better usability", 
                                   font: .dsCaption, color: theme.colors.secondaryText)
                            DSText("You can add transactions immediately!", 
                                   font: .dsCaption, color: theme.colors.secondaryText)
                        }
                        
                        Spacer()
                    }
                    .padding(.top, 4)
                }
                
                HStack {
                    DSText("Budget Name:", font: .dsBody)
                    Spacer()
                    DSText(onboardingState.budgetPeriod.name, font: .dsBody, color: theme.colors.primaryText)
                }
                
                HStack {
                    DSText("Period:", font: .dsBody)
                    Spacer()
                    DSText("\(formatDate(onboardingState.budgetPeriod.startDate)) - \(formatDate(onboardingState.budgetPeriod.endDate))", 
                           font: .dsBody, color: theme.colors.primaryText)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func initializeState() {
        let calendar = Calendar.current
        selectedDay = calendar.component(.day, from: onboardingState.selectedStartDate)
        selectedEndDay = min(28, selectedDay + 7) // Default to week later, max 28
        
        // Initialize budget name if empty
        updateBudgetName()
    }
    
    private func updateStartDate(day: Int) {
        let calendar = Calendar.current
        let currentDate = Date()
        
        // Create a date with the selected day in the current month
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: currentDate)
        dateComponents.day = day
        
        if let newDate = calendar.date(from: dateComponents) {
            onboardingState.selectedStartDate = newDate
            updateBudgetName()
        }
    }
    
    private func updateEndDate(day: Int) {
        let calendar = Calendar.current
        let currentDate = Date()
        
        // Create a date with the selected day in the current month
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: currentDate)
        dateComponents.day = day
        
        if let newDate = calendar.date(from: dateComponents) {
            // Check if this creates a reverse budget (end date before start date)
            if newDate <= onboardingState.selectedStartDate {
                // Move end date to next month to prevent reverse budget
                if let nextMonthEndDate = calendar.date(byAdding: .month, value: 1, to: newDate) {
                    onboardingState.selectedEndDate = nextMonthEndDate
                } else {
                    onboardingState.selectedEndDate = newDate
                }
            } else {
                onboardingState.selectedEndDate = newDate
            }
            updateBudgetName()
        }
    }
    
    private func updateBudgetName() {
        // Only auto-update if user hasn't customized the name
        if onboardingState.budgetName.isEmpty || shouldAutoUpdateName() {
            switch onboardingState.selectedBudgetType {
            case .monthly:
                // Use the actual budgetPeriod which includes auto-shifting logic
                let budgetPeriod = onboardingState.budgetPeriod
                onboardingState.budgetName = budgetPeriod.name
            case .custom:
                if let endDate = onboardingState.selectedEndDate {
                    // Use the actual budgetPeriod dates which include auto-shifting
                    let budgetPeriod = onboardingState.budgetPeriod
                    onboardingState.budgetName = BudgetPeriod.generateCustomName(for: budgetPeriod.startDate, endDate: budgetPeriod.endDate)
                }
            }
        }
    }
    
    private func shouldAutoUpdateName() -> Bool {
        // Check if name looks like an auto-generated one
        return onboardingState.budgetName.contains("Budget") || 
               onboardingState.budgetName.contains(",") ||
               onboardingState.budgetName.contains("-")
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

#Preview {
    @Previewable let state = OnboardingState()
    state.currentStep = .dateSelection
    state.selectedBudgetType = .monthly
    return DateSelectionView(onboardingState: state)
}
