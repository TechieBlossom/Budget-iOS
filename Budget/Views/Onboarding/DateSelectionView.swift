import SwiftUI

struct DateSelectionView: View {
    @Bindable var onboardingState: OnboardingState
    @State private var selectedDay: Int = 1
    
    @Environment(\.appTheme) private var theme
    
    var body: some View {
        VStack(spacing: 32) {
            // Header
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    DSText("Select Date", font: .dsTitle)
                    DSText("Choose the day of the month to start your budget period", font: .dsBody, color: theme.colors.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Image(systemName: "calendar")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(theme.colors.primaryText)
            }
            .padding(.horizontal, 16)
            .padding(.top, 80) // Space for back button
            
            // Date Grid
            VStack(spacing: 16) {
                let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
                
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(1...28, id: \.self) { day in
                        Button(action: {
                            selectedDay = day
                            updateSelectedDate(day: day)
                        }) {
                            Text("\(day)")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(selectedDay == day ? theme.colors.card : theme.colors.primaryText)
                                .frame(width: 40, height: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedDay == day ? theme.colors.primaryText : theme.colors.card)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(theme.colors.primaryText, lineWidth: selectedDay == day ? 2 : 1)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
            }
            
            // Budget Month Preview
            DSCard {
                VStack(spacing: 12) {
                    HStack {
                        DSText("Budget Month Preview", font: .dsHeadline)
                        Spacer()
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
            .padding(.horizontal, 16)
            
            Spacer()
        }
        .background(theme.colors.background)
        .onAppear {
            let calendar = Calendar.current
            selectedDay = calendar.component(.day, from: onboardingState.selectedStartDate)
        }
    }
    
    private func updateSelectedDate(day: Int) {
        let calendar = Calendar.current
        let currentDate = Date()
        
        // Create a date with the selected day in the current month
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: currentDate)
        dateComponents.day = day
        
        if let newDate = calendar.date(from: dateComponents) {
            onboardingState.selectedStartDate = newDate
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

#Preview {
    let state = OnboardingState()
    state.currentStep = .dateSelection
    return DateSelectionView(onboardingState: state)
}
