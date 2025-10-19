import SwiftUI

struct DSTextField: View {
    let placeholder: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    let autocapitalization: TextInputAutocapitalization

    @Environment(\.appTheme) private var theme

    init(_ placeholder: String, text: Binding<String>, keyboardType: UIKeyboardType = .default, autocapitalization: TextInputAutocapitalization = .never) {
        self.placeholder = placeholder
        self._text = text
        self.keyboardType = keyboardType
        self.autocapitalization = autocapitalization
    }

    var body: some View {
        TextField(placeholder, text: $text, prompt: Text(placeholder).foregroundColor(theme.colors.textTertiary))
            .font(.dsHeadline)
            .foregroundColor(theme.colors.textPrimary)
            .padding(.horizontal, DSSpacing.md)
            .padding(.vertical, DSSpacing.sm)
            .background(theme.colors.surface)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.colors.divider, lineWidth: 1)
            )
            .accentColor(theme.colors.primary)
            .keyboardType(keyboardType)
            .textInputAutocapitalization(autocapitalization)
            .autocorrectionDisabled()
    }
}

#Preview {
    @Previewable @State var text = ""

    return VStack(spacing: DSSpacing.md) {
        DSTextField("Enter text", text: $text)
        DSTextField("Search currency", text: $text)
    }
    .padding(DSSpacing.md)
    .background(AppTheme.shared.colors.background)
}