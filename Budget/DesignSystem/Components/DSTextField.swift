import SwiftUI

struct DSTextField: View {
    let placeholder: String
    @Binding var text: String
    
    @Environment(\.appTheme) private var theme
    
    init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        self._text = text
    }
    
    var body: some View {
        TextField(placeholder, text: $text)
            .font(.system(size: 16))
            .foregroundColor(theme.colors.primaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(theme.colors.card)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.colors.secondaryText, lineWidth: 1)
            )
            .accentColor(theme.colors.primaryText)
    }
}

#Preview {
    @Previewable @State var text = ""
    
    return VStack(spacing: 16) {
        DSTextField("Enter text", text: $text)
        DSTextField("Search currency", text: $text)
    }
    .padding()
    .background(AppTheme.shared.colors.background)
}