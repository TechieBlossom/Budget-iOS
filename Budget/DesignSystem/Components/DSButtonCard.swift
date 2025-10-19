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
            VStack(spacing: DSSpacing.xs) {
                DSText(title, font: .dsHeadline, color: titleColor)
                    .fontWeight(.medium)

                DSText(subtitle, font: .dsSubtitle, color: subtitleColor)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, DSSpacing.xl)
            .padding(.vertical, DSSpacing.md)
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
            return theme.colors.primary
        case .outline:
            return theme.colors.surface
        }
    }

    private var titleColor: Color {
        switch style {
        case .primary:
            return .white
        case .outline:
            return theme.colors.primary
        }
    }

    private var subtitleColor: Color {
        switch style {
        case .primary:
            return .white.opacity(0.9)
        case .outline:
            return theme.colors.textSecondary
        }
    }

    private var borderColor: Color {
        return theme.colors.primary
    }
    
    private var borderWidth: CGFloat {
        return 2
    }
}

#Preview {
    VStack(spacing: DSSpacing.md) {
        DSButtonCard("GET STARTED", subtitle: "Begin with a fresh budget setup", style: .primary) {}
        DSButtonCard("IMPORT", subtitle: "Continue with existing budget data", style: .outline) {}
    }
    .padding(DSSpacing.md)
    .background(AppTheme.shared.colors.background)
}
