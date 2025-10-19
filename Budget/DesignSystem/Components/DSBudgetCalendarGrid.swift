import SwiftUI

struct DSBudgetCalendarGrid: View {
    @Binding var selectedDay: Int
    let onDaySelected: (Int) -> Void

    @Environment(\.appTheme) private var theme

    private let columns = Array(repeating: GridItem(.flexible(), spacing: DSSpacing.xs), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: DSSpacing.xs) {
            ForEach(1...28, id: \.self) { day in
                Button(action: {
                    selectedDay = day
                    onDaySelected(day)
                }) {
                    Text("\(day)")
                        .font(.dsHeadline)
                        .foregroundColor(selectedDay == day ? theme.colors.surface : theme.colors.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedDay == day ? theme.colors.textPrimary : theme.colors.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(theme.colors.textPrimary, lineWidth: selectedDay == day ? 2 : 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

#Preview {
    @Previewable @State var selectedDay: Int = 15

    DSBudgetCalendarGrid(selectedDay: $selectedDay) { day in
        print("Selected day: \(day)")
    }
    .padding(DSSpacing.md)
}
