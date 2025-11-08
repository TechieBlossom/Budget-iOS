import SwiftUI

struct DSToggle: View {
    let options: [String]
    @Binding var selectedIndex: Int
    
    @Environment(\.appTheme) private var theme
    
    init(_ options: [String], selectedIndex: Binding<Int>) {
        self.options = options
        self._selectedIndex = selectedIndex
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                Button(action: {
                    selectedIndex = index
                }) {
                    DSText(option, font: .dsBody, color: selectedIndex == index ? .white : theme.colors.textPrimary)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DSSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedIndex == index ? theme.colors.primary : Color.clear)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(theme.colors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.colors.primary, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .animation(.easeOut(duration: 0.2), value: selectedIndex)
    }
}

#Preview {
    @Previewable @State var selection = 0
    return VStack(spacing: DSSpacing.lg) {
        DSToggle(["Monthly", "Custom"], selectedIndex: $selection)
        DSToggle(["Option A", "Option B", "Option C"], selectedIndex: $selection)
    }
    .padding(DSSpacing.md)
    .background(AppTheme.shared.colors.background)
}