import SwiftUI

struct DSButton: View {
    enum Style {
        case primary
        case outline
    }
    
    let title: String
    let style: Style
    let action: () -> Void
    
    @Environment(\.appTheme) private var theme
    
    init(_ title: String, style: Style = .primary, action: @escaping () -> Void) {
        self.title = title
        self.style = style
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            DSText(title, font: .dsBody, color: textColor)
                .fontWeight(.medium)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: borderWidth)
                )
                .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary:
            return theme.colors.primaryText
        case .outline:
            return Color.clear
        }
    }
    
    private var textColor: Color {
        switch style {
        case .primary:
            return theme.colors.card
        case .outline:
            return theme.colors.primaryText
        }
    }
    
    private var borderColor: Color {
        return theme.colors.primaryText
    }
    
    private var borderWidth: CGFloat {
        return 2
    }
}

#Preview {
    VStack(spacing: 16) {
        DSButton("Primary Button", style: .primary) {}
        DSButton("Outline Button", style: .outline) {}
    }
    .padding()
    .background(AppTheme.shared.colors.background)
}
