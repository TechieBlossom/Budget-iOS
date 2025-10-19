import SwiftUI

struct DSCard<Content: View>: View {
    let padding: CGFloat
    let content: Content

    @Environment(\.appTheme) private var theme

    init(padding: CGFloat = DSSpacing.md, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.padding = padding
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(theme.colors.surface)
            .cornerRadius(12)
            .shadow(color: theme.colors.textSecondary.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    VStack(spacing: DSSpacing.md) {
        DSCard {
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                DSText("Card Title", font: .dsHeadline)
                DSText("This is some card content with secondary text.", font: .dsBody, color: AppTheme.shared.colors.textSecondary)
            }
        }

        DSCard {
            HStack {
                DSText("Simple Card", font: .dsBody)
                Spacer()
                DSText("Value", font: .dsBody, color: AppTheme.shared.colors.textSecondary)
            }
        }
    }
    .padding(DSSpacing.md)
    .background(AppTheme.shared.colors.background)
}
