import SwiftUI

struct DSButton: View {
    enum Style {
        case primary
        case outline
    }

    enum Size {
        case regular
        case mini
    }

    let title: String
    let style: Style
    let size: Size
    let fullWidth: Bool
    let action: () -> Void

    @Environment(\.appTheme) private var theme

    init(_ title: String, style: Style = .primary, size: Size = .regular, fullWidth: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.style = style
        self.size = size
        self.fullWidth = fullWidth
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            HapticManager.shared.buttonTap()
            action()
        }) {
            DSText(title, font: textFont, color: textColor)
                .fontWeight(.medium)
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .background(backgroundColor)
                .cornerRadius(8)
                .cornerRadius(cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(borderColor, lineWidth: borderWidth)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var textFont: Font {
        switch size {
        case .regular:
            return .dsBody
        case .mini:
            return .dsCaption
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .regular:
            return DSSpacing.xl
        case .mini:
            return DSSpacing.sm
        }
    }

    private var verticalPadding: CGFloat {
        switch size {
        case .regular:
            return DSSpacing.sm
        case .mini:
            return 6
        }
    }

    private var cornerRadius: CGFloat {
        switch size {
        case .regular:
            return 8
        case .mini:
            return 6
        }
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary:
            return theme.colors.primary
        case .outline:
            return Color.clear
        }
    }

    private var textColor: Color {
        switch style {
        case .primary:
            return .white
        case .outline:
            return theme.colors.textPrimary
        }
    }

    private var borderColor: Color {
        switch style {
        case .primary:
            return Color.clear
        case .outline:
            return theme.colors.divider
        }
    }

    private var borderWidth: CGFloat {
        switch style {
        case .primary:
            return 0
        case .outline:
            return 1
        }
    }
}

#Preview {
    VStack(spacing: DSSpacing.md) {
        DSButton("Primary Button", style: .primary) {}
        DSButton("Outline Button", style: .outline) {}
    }
    .padding(DSSpacing.md)
    .background(AppTheme.shared.colors.background)
}
