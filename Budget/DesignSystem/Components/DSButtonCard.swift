import SwiftUI

struct DSButtonCard: View {
    enum Style {
        case primary
        case outline
    }
    
    let title: String
    let subtitle: String
    let style: Style
    let action: () -> Void
    
    @Environment(\.appTheme) private var theme
    
    init(_ title: String, subtitle: String, style: Style = .primary, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.style = style
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                DSText(title, font: .dsHeadline, color: titleColor)
                    .fontWeight(.medium)
                
                DSText(subtitle, font: .dsSubtitle, color: subtitleColor)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary:
            return theme.colors.primaryText
        case .outline:
            return theme.colors.card
        }
    }
    
    private var titleColor: Color {
        switch style {
        case .primary:
            return theme.colors.card
        case .outline:
            return theme.colors.primaryText
        }
    }
    
    private var subtitleColor: Color {
        switch style {
        case .primary:
            return theme.colors.card.opacity(0.8)
        case .outline:
            return theme.colors.secondaryText
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
        DSButtonCard("GET STARTED", subtitle: "Begin with a fresh budget setup", style: .primary) {}
        DSButtonCard("IMPORT", subtitle: "Continue with existing budget data", style: .outline) {}
    }
    .padding()
    .background(AppTheme.shared.colors.background)
}
